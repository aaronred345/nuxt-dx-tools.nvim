import * as fs from 'fs';
import * as path from 'path';
import { Cache } from './cache';
import { Logger } from './logger';

export interface SymbolInfo {
  name: string;
  type: 'composable' | 'component' | 'symbol';
  importPath?: string;
  path?: string;
  rawLine?: string;
}

export interface ComponentInfo {
  name: string;
  type: 'component';
  path: string;
  rawLine?: string;
}

export interface ModuleInfo {
  name: string;
  type: 'nuxt-module';
}

export class TypeParser {
  private importCache: Cache<Map<string, SymbolInfo>>;
  private componentCache: Cache<Map<string, ComponentInfo>>;
  private moduleCache: Cache<Map<string, ModuleInfo>>;
  private logger: Logger;
  private rootPath: string;

  constructor(rootPath: string, logger: Logger) {
    this.rootPath = rootPath;
    this.logger = logger;
    this.importCache = new Cache<Map<string, SymbolInfo>>();
    this.componentCache = new Cache<Map<string, ComponentInfo>>();
    this.moduleCache = new Cache<Map<string, ModuleInfo>>();
  }

  /**
   * Parse .nuxt/imports.d.ts for all auto-imported symbols
   */
  private parseImports(): Map<string, SymbolInfo> {
    const importsFile = path.join(this.rootPath, '.nuxt', 'imports.d.ts');
    this.logger.debug(`Parsing imports from: ${importsFile}`);

    if (!fs.existsSync(importsFile)) {
      this.logger.debug('Could not find imports file');
      return new Map();
    }

    const content = fs.readFileSync(importsFile, 'utf-8');
    const imports = new Map<string, SymbolInfo>();
    const lines = content.split(/\r?\n/);

    for (const line of lines) {
      // Match: export { symbol1, symbol2, ... } from 'path';
      const exportListMatch = line.match(/export\s+\{\s*([^}]+)\s*\}\s+from\s+['"]([^'"]+)['"]/);
      if (exportListMatch) {
        const exportList = exportListMatch[1];
        const importPath = exportListMatch[2];

        // Split the export list by commas
        const symbols = exportList.split(',').map((s) => s.trim());
        for (const symbol of symbols) {
          if (symbol && !imports.has(symbol)) {
            imports.set(symbol, {
              name: symbol,
              type: 'composable',
              importPath: importPath,
              rawLine: line,
            });
            this.logger.debug(`Found export: ${symbol} from ${importPath}`);
          }
        }
      }

      // Also match older format: export const useFoo: typeof import('...').useFoo
      const oldFormatMatch = line.match(/export\s+const\s+(\w+)\s*:\s*typeof\s+import\(['"]([^'"]+)['"]\)/);
      if (oldFormatMatch) {
        const name = oldFormatMatch[1];
        const importPath = oldFormatMatch[2];

        if (!imports.has(name)) {
          imports.set(name, {
            name,
            type: 'composable',
            importPath,
            rawLine: line,
          });
          this.logger.debug(`Found typed export: ${name} from ${importPath}`);
        }
      }
    }

    this.logger.debug(`Parsed ${lines.length} lines, found ${imports.size} imports`);
    return imports;
  }

  /**
   * Parse .nuxt/components.d.ts for all components
   */
  private parseComponents(): Map<string, ComponentInfo> {
    const componentsFile = path.join(this.rootPath, '.nuxt', 'components.d.ts');
    this.logger.debug(`Parsing components from: ${componentsFile}`);

    if (!fs.existsSync(componentsFile)) {
      this.logger.debug('Could not find components file');
      return new Map();
    }

    const content = fs.readFileSync(componentsFile, 'utf-8');
    const components = new Map<string, ComponentInfo>();
    const lines = content.split(/\r?\n/);

    for (const line of lines) {
      // Match: 'ComponentName': typeof import('path').default or ['default']
      // Handles both .default and ['default'] formats
      let match = line.match(/'([\w]+)'\s*:\s*typeof\s+import\(['"]([^'"]+)['"]\)\[?['"]?default['"]?\]?/);
      if (match) {
        const name = match[1];
        const importPath = match[2];
        const absolutePath = this.resolveComponentPath(importPath);

        components.set(name, {
          name,
          type: 'component',
          path: absolutePath,
          rawLine: line,
        });
        this.logger.debug(`Found component (quoted): ${name} at ${absolutePath}`);
        continue;
      }

      // Match: ComponentName: typeof import('path').default or ['default']
      // Handles both .default and ['default'] formats
      match = line.match(/(\w+)\s*:\s*typeof\s+import\(['"]([^'"]+)['"]\)\[?['"]?default['"]?\]?/);
      if (match) {
        const name = match[1];
        const importPath = match[2];

        // Skip private symbols (starting with _)
        if (!name.startsWith('_') && !components.has(name)) {
          const absolutePath = this.resolveComponentPath(importPath);

          components.set(name, {
            name,
            type: 'component',
            path: absolutePath,
            rawLine: line,
          });
          this.logger.debug(`Found component (unquoted): ${name} at ${absolutePath}`);
        }
      }
    }

    this.logger.debug(`Parsed ${lines.length} lines, found ${components.size} components`);
    return components;
  }

  /**
   * Resolve component path from .nuxt relative path to absolute path
   */
  private resolveComponentPath(importPath: string): string {
    if (importPath.startsWith('..')) {
      // Path is relative to .nuxt directory, resolve it
      const nuxtDir = path.join(this.rootPath, '.nuxt');
      return path.resolve(nuxtDir, importPath);
    } else if (!importPath.startsWith('/')) {
      // Relative path without ../, assume it's from root
      return path.join(this.rootPath, importPath);
    }
    return importPath;
  }

  /**
   * Parse package.json for Nuxt modules
   */
  private parsePackageModules(): Map<string, ModuleInfo> {
    const packageFile = path.join(this.rootPath, 'package.json');

    if (!fs.existsSync(packageFile)) {
      return new Map();
    }

    const content = fs.readFileSync(packageFile, 'utf-8');
    const modules = new Map<string, ModuleInfo>();

    // Find all @nuxt/* and nuxt-* dependencies
    const nuxtModulePatterns = [
      /"(@nuxt\/[^"]+)"/g,
      /"(nuxt-[^"]+)"/g,
      /"(@nuxtjs\/[^"]+)"/g,
    ];

    for (const pattern of nuxtModulePatterns) {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        const name = match[1];
        modules.set(name, { name, type: 'nuxt-module' });
      }
    }

    return modules;
  }

  /**
   * Get cached or fresh imports
   */
  getImports(): Map<string, SymbolInfo> {
    const cached = this.importCache.get('imports');
    if (cached) {
      return cached;
    }

    const imports = this.parseImports();
    this.importCache.set('imports', imports, 5000); // 5 second TTL
    return imports;
  }

  /**
   * Get cached or fresh components
   */
  getComponents(): Map<string, ComponentInfo> {
    const cached = this.componentCache.get('components');
    if (cached) {
      return cached;
    }

    const components = this.parseComponents();
    this.componentCache.set('components', components, 5000); // 5 second TTL
    return components;
  }

  /**
   * Get cached or fresh modules
   */
  getModules(): Map<string, ModuleInfo> {
    const cached = this.moduleCache.get('modules');
    if (cached) {
      return cached;
    }

    const modules = this.parsePackageModules();
    this.moduleCache.set('modules', modules, 5000); // 5 second TTL
    return modules;
  }

  /**
   * Get symbol information
   */
  getSymbolInfo(symbol: string): SymbolInfo | ComponentInfo | null {
    // Check imports
    const imports = this.getImports();
    if (imports.has(symbol)) {
      return imports.get(symbol)!;
    }

    // Check components
    const components = this.getComponents();
    if (components.has(symbol)) {
      return components.get(symbol)!;
    }

    return null;
  }

  /**
   * Get all symbols (imports + components)
   */
  getAllSymbols(): Map<string, SymbolInfo | ComponentInfo> {
    const all = new Map<string, SymbolInfo | ComponentInfo>();

    const imports = this.getImports();
    for (const [name, info] of imports) {
      all.set(name, info);
    }

    const components = this.getComponents();
    for (const [name, info] of components) {
      all.set(name, info);
    }

    return all;
  }

  /**
   * Clear all caches
   */
  clearCache(): void {
    this.importCache.clear();
    this.componentCache.clear();
    this.moduleCache.clear();
  }
}
