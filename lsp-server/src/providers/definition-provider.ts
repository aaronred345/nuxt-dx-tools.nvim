import { Location, Position, Range } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { URI } from 'vscode-uri';
import * as fs from 'fs';
import * as path from 'path';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';

export class DefinitionProvider {
  constructor(
    private projectManager: NuxtProjectManager,
    private logger: Logger
  ) {}

  /**
   * Provide goto definition for Nuxt-specific symbols
   *
   * Note: No early exit pattern check - each handler determines if it can provide a definition.
   * This prevents false positives where we match a pattern but can't actually provide a definition.
   */
  async provideDefinition(
    document: TextDocument,
    position: Position
  ): Promise<Location | Location[] | null> {
    const text = document.getText();
    const offset = document.offsetAt(position);
    const line = this.getLine(text, offset);
    const word = this.getWordAtPosition(text, offset);
    const stringAtCursor = this.getStringAtPosition(text, offset);

    this.logger.info(`[Definition] ==================== NEW REQUEST ====================`);
    this.logger.info(`[Definition] File: ${document.uri}`);
    this.logger.info(`[Definition] Position: line ${position.line}, char ${position.character}`);
    this.logger.info(`[Definition] Word under cursor: "${word}"`);
    this.logger.info(`[Definition] String at cursor: "${stringAtCursor}"`);
    this.logger.info(`[Definition] Full line: "${line.trim()}"`);
    this.logger.info(`[Definition] =======================================================`);

    // 1. PRIORITY: Check for CSS/style imports first (respond before vtsls/tsserver)
    // This prevents other LSP servers from responding with client.d.ts for CSS imports
    if (line.includes('import') && (line.includes('from') || line.includes("'"))) {
      // Quick check for CSS extensions to avoid unnecessary processing
      if (line.includes('.css') || line.includes('.pcss') || line.includes('.scss') ||
          line.includes('.sass') || line.includes('.less') || line.includes('.styl')) {
        this.logger.info(`[Definition] PRIORITY: Checking CSS/style import...`);
        const importDef = await this.handleImportStatement(line, word, stringAtCursor);
        if (importDef) {
          this.logger.info(`[Definition] ✓ Provided CSS import definition (PRIORITY)`);
          return importDef;
        }
        this.logger.info(`[Definition] ✗ No CSS import definition found`);
      }
    }

    // 2. Check for virtual module imports (very specific)
    if (line.includes('#imports') || line.includes('#app') || line.includes('#build') || line.includes('#components')) {
      this.logger.info(`[Definition] Checking virtual modules...`);
      const virtualModuleDef = this.handleVirtualModules(line);
      if (virtualModuleDef) {
        this.logger.info(`[Definition] ✓ Provided virtual module definition`);
        return virtualModuleDef;
      }
      this.logger.info(`[Definition] ✗ No virtual module definition found`);
    }

    // 3. Check for other import statements with path aliases
    if (line.includes('import') && (line.includes('from') || line.includes("'"))) {
      this.logger.info(`[Definition] Checking import statement...`);
      const importDef = await this.handleImportStatement(line, word, stringAtCursor);
      if (importDef) {
        this.logger.info(`[Definition] ✓ Provided import definition`);
        return importDef;
      }
      this.logger.info(`[Definition] ✗ No import definition found`);
    }

    // 4. Check for definePageMeta context (layout, middleware)
    if (line.includes('layout:') || line.includes('middleware:')) {
      this.logger.info(`[Definition] Checking definePageMeta...`);
      const pageMetaDef = await this.handleDefinePageMeta(word, line, stringAtCursor);
      if (pageMetaDef) {
        this.logger.info(`[Definition] ✓ Provided definePageMeta definition for: ${word}`);
        return pageMetaDef;
      }
      this.logger.info(`[Definition] ✗ No definePageMeta definition found`);
    }

    // 5. Check for page routes (specific patterns)
    if (line.includes('navigateTo') || line.includes('router.push') || /to\s*=\s*['"]/.test(line) || /href\s*=\s*['"]/.test(line)) {
      this.logger.info(`[Definition] Checking page routes...`);
      const routeDef = await this.handlePageRoutes(line, stringAtCursor);
      if (routeDef) {
        this.logger.info(`[Definition] ✓ Provided page route definition`);
        return routeDef;
      }
      this.logger.info(`[Definition] ✗ No page route definition found`);
    }

    // 6. Check for API routes (specific patterns)
    if (line.includes('$fetch') || line.includes('useFetch') || line.includes('useAsyncData')) {
      this.logger.info(`[Definition] Checking API routes...`);
      const apiRouteDef = await this.handleApiRoutes(line, stringAtCursor);
      if (apiRouteDef) {
        this.logger.info(`[Definition] ✓ Provided API route definition`);
        return apiRouteDef;
      }
      this.logger.info(`[Definition] ✗ No API route definition found`);
    }

    // 6. Check for auto-imported symbols (components and composables)
    // Only check if we actually have info for this symbol
    this.logger.info(`[Definition] Checking auto-imported symbols for: ${word}...`);
    const typeParser = this.projectManager.getTypeParser();
    const symbolInfo = typeParser.getSymbolInfo(word);

    if (symbolInfo) {
      const importPath = 'importPath' in symbolInfo ? symbolInfo.importPath : undefined;
      this.logger.info(`[Definition] Found symbol info: type=${symbolInfo.type}, path=${symbolInfo.path}, importPath=${importPath}`);

      // We have symbol info (either path for components or importPath for composables)
      if (symbolInfo.path || importPath) {
        const componentDef = await this.handleComponents(word);
        if (componentDef) {
          this.logger.info(`[Definition] ✓ Provided definition for: ${word}`);
          return componentDef;
        }
        this.logger.info(`[Definition] ✗ handleComponents returned null for: ${word}`);
      } else {
        this.logger.info(`[Definition] ✗ Symbol has no path or importPath: ${word}`);
      }
    } else {
      this.logger.info(`[Definition] ✗ No symbol info found for: ${word}`);
    }

    // 7. Check for custom plugin definitions (e.g., $dialog)
    if (word.startsWith('$')) {
      this.logger.info(`[Definition] Checking custom plugins for: ${word}...`);
      const pluginDef = await this.handleCustomPlugins(word);
      if (pluginDef) {
        this.logger.info(`[Definition] ✓ Provided plugin definition for: ${word}`);
        return pluginDef;
      }
      this.logger.info(`[Definition] ✗ No plugin definition found for: ${word}`);
    }

    // Return null to let other LSP servers handle it
    this.logger.info(`[Definition] ✗ No Nuxt-specific definition found, returning null`);
    return null;
  }

  /**
   * Handle import statements with path aliases
   * import MyComponent from '~/components/MyComponent.vue'
   * import { helper } from '@/utils/helpers'
   * import './styles.css'
   */
  private async handleImportStatement(line: string, word: string, stringAtCursor: string): Promise<Location | null> {
    // If cursor is on a string, use that as the import path
    let importPath = stringAtCursor;

    // Otherwise, extract from the line
    if (!importPath) {
      const importMatch = line.match(/from\s+['"]([^'"]+)['"]|import\s+['"]([^'"]+)['"]/);
      if (!importMatch) {
        return null;
      }
      importPath = importMatch[1] || importMatch[2];
    }

    this.logger.info(`[Definition] Found import path: ${importPath}`);

    // Check if the import already has an extension (has a dot after the last slash)
    const hasExtension = /\.[^/\\]+$/.test(importPath);

    // Extract the extension from the import path
    const importExtension = hasExtension ? path.extname(importPath) : null;
    this.logger.info(`[Definition] Import extension: ${importExtension || 'none'}`);

    const rootPath = this.projectManager.getRootPath();
    const tsConfigParser = this.projectManager.getTsConfigParser();

    // If the import already has an extension, try it directly first (highest priority)
    if (hasExtension) {
      this.logger.info(`[Definition] Import has extension: ${importExtension}, trying resolution...`);

      // Try with alias resolution first
      const resolvedPath = tsConfigParser.resolveAliasPath(importPath);
      this.logger.info(`[Definition] Alias resolved to: ${resolvedPath || 'null'}`);

      if (resolvedPath) {
        if (fs.existsSync(resolvedPath)) {
          // Only accept if the extension matches (avoid .d.ts files for .css imports)
          const resolvedExt = path.extname(resolvedPath);
          this.logger.info(`[Definition] File exists at ${resolvedPath}, extension: ${resolvedExt}`);

          if (resolvedExt === importExtension) {
            this.logger.info(`[Definition] ✓ Extension matches, returning: ${resolvedPath}`);
            return Location.create(URI.file(resolvedPath).toString(), Range.create(0, 0, 0, 0));
          } else {
            this.logger.info(`[Definition] ✗ Extension mismatch (expected ${importExtension}, got ${resolvedExt})`);
          }
        } else {
          this.logger.info(`[Definition] File does not exist at resolved path: ${resolvedPath}`);
        }
      }

      // Try direct relative path (from project root)
      const directPath = path.join(rootPath, importPath);
      this.logger.info(`[Definition] Trying direct path: ${directPath}`);
      if (fs.existsSync(directPath)) {
        this.logger.info(`[Definition] ✓ Found file with existing extension: ${directPath}`);
        return Location.create(URI.file(directPath).toString(), Range.create(0, 0, 0, 0));
      } else {
        this.logger.info(`[Definition] ✗ File does not exist at direct path`);
      }

      // For aliased paths, try stripping the alias and treating as relative from root
      // e.g., ~/assets/main.css -> assets/main.css
      if (importPath.startsWith('~')) {
        const withoutTilde = importPath.replace(/^~+\//, '');
        const tildeStrippedPath = path.join(rootPath, withoutTilde);
        this.logger.info(`[Definition] Trying without tilde: ${tildeStrippedPath}`);
        if (fs.existsSync(tildeStrippedPath)) {
          this.logger.info(`[Definition] ✓ Found file without tilde: ${tildeStrippedPath}`);
          return Location.create(URI.file(tildeStrippedPath).toString(), Range.create(0, 0, 0, 0));
        }
      }

      // Try @/ prefix
      if (importPath.startsWith('@')) {
        const withoutAt = importPath.replace(/^@\//, '');
        const atStrippedPath = path.join(rootPath, withoutAt);
        this.logger.info(`[Definition] Trying without @: ${atStrippedPath}`);
        if (fs.existsSync(atStrippedPath)) {
          this.logger.info(`[Definition] ✓ Found file without @: ${atStrippedPath}`);
          return Location.create(URI.file(atStrippedPath).toString(), Range.create(0, 0, 0, 0));
        }
      }
    }

    // For imports without extensions, try alias resolution
    const resolvedPath = tsConfigParser.resolveAliasPath(importPath);
    this.logger.info(`[Definition] Resolved import path: ${resolvedPath || 'null'}, hasExtension: ${hasExtension}`);

    if (resolvedPath && fs.existsSync(resolvedPath)) {
      // Skip .d.ts files unless that's what we're looking for
      if (!resolvedPath.endsWith('.d.ts')) {
        return Location.create(URI.file(resolvedPath).toString(), Range.create(0, 0, 0, 0));
      }
    }

    // Try to resolve as a relative path with various extensions
    // Include all common file types: JS/TS, Vue, CSS, etc.
    const extensions = [
      '.vue', '.ts', '.js', '.tsx', '.jsx', '.mjs',
      '.css', '.pcss', '.scss', '.sass', '.less', '.styl'
    ];

    for (const ext of extensions) {
      const fullPath = path.join(rootPath, importPath + ext);
      if (fs.existsSync(fullPath)) {
        this.logger.info(`[Definition] Found file with extension: ${fullPath}`);
        return Location.create(URI.file(fullPath).toString(), Range.create(0, 0, 0, 0));
      }
    }

    // Try without extension as a fallback
    if (!hasExtension) {
      const directPath = path.join(rootPath, importPath);
      if (fs.existsSync(directPath)) {
        this.logger.info(`[Definition] Found file directly: ${directPath}`);
        return Location.create(URI.file(directPath).toString(), Range.create(0, 0, 0, 0));
      }
    }

    this.logger.info(`[Definition] Import path not found: ${importPath}`);
    return null;
  }

  /**
   * Handle virtual module imports (#imports, #app, #build, etc.)
   */
  private handleVirtualModules(line: string): Location | null {
    const virtualModuleMatch = line.match(/from\s+['"]#(imports|app|build|components|internal\/nitro)['"]/);
    if (!virtualModuleMatch) {
      return null;
    }

    const moduleName = virtualModuleMatch[1];
    const rootPath = this.projectManager.getRootPath();

    // Map virtual modules to their .d.ts files
    const moduleMap: Record<string, string> = {
      imports: '.nuxt/imports.d.ts',
      app: '.nuxt/imports.d.ts',
      build: '.nuxt/types/nuxt.d.ts',
      components: '.nuxt/components.d.ts',
      'internal/nitro': '.nuxt/types/nitro.d.ts',
    };

    const filePath = path.join(rootPath, moduleMap[moduleName] || '.nuxt/imports.d.ts');

    if (fs.existsSync(filePath)) {
      return Location.create(URI.file(filePath).toString(), Range.create(0, 0, 0, 0));
    }

    return null;
  }

  /**
   * Handle definePageMeta context (layout, middleware)
   */
  private async handleDefinePageMeta(word: string, line: string, stringAtCursor: string): Promise<Location | null> {
    // Check if we're in a definePageMeta context
    if (!line.includes('layout') && !line.includes('middleware')) {
      return null;
    }

    // If cursor is on a string, try to resolve it
    if (stringAtCursor) {
      // Try as layout first
      if (line.includes('layout')) {
        const layoutFile = this.projectManager.findFile('layouts', `${stringAtCursor}.vue`);
        if (layoutFile) {
          return Location.create(URI.file(layoutFile).toString(), Range.create(0, 0, 0, 0));
        }
      }

      // Try as middleware
      if (line.includes('middleware')) {
        const middlewareFile =
          this.projectManager.findFile('middleware', `${stringAtCursor}.ts`) ||
          this.projectManager.findFile('middleware', `${stringAtCursor}.js`) ||
          this.projectManager.findFile('server', 'middleware', `${stringAtCursor}.ts`) ||
          this.projectManager.findFile('server', 'middleware', `${stringAtCursor}.js`);

        if (middlewareFile) {
          return Location.create(URI.file(middlewareFile).toString(), Range.create(0, 0, 0, 0));
        }
      }
    }

    // Extract layout name: layout: 'default' or layout: "custom"
    const layoutMatch = line.match(/layout:\s*['"]([^'"]+)['"]/);
    if (layoutMatch) {
      const layoutName = layoutMatch[1];
      const layoutFile = this.projectManager.findFile('layouts', `${layoutName}.vue`);

      if (layoutFile) {
        return Location.create(URI.file(layoutFile).toString(), Range.create(0, 0, 0, 0));
      }
    }

    // Extract middleware name: middleware: 'auth' or middleware: ['auth', 'admin']
    const middlewareMatches = line.matchAll(/['"]([a-zA-Z0-9_-]+)['"]/g);
    for (const match of middlewareMatches) {
      const middlewareName = match[1];

      // Skip 'layout', 'middleware', etc. keywords
      if (['layout', 'middleware', 'auth', 'guest'].includes(middlewareName)) {
        continue;
      }

      const middlewareFile =
        this.projectManager.findFile('middleware', `${middlewareName}.ts`) ||
        this.projectManager.findFile('middleware', `${middlewareName}.js`) ||
        this.projectManager.findFile('server', 'middleware', `${middlewareName}.ts`) ||
        this.projectManager.findFile('server', 'middleware', `${middlewareName}.js`);

      if (middlewareFile) {
        return Location.create(URI.file(middlewareFile).toString(), Range.create(0, 0, 0, 0));
      }
    }

    return null;
  }

  /**
   * Handle page routes (navigateTo, NuxtLink, router.push)
   */
  private async handlePageRoutes(line: string, stringAtCursor: string): Promise<Location | null> {
    // If cursor is on a string and it looks like a route path, try to resolve it
    if (stringAtCursor && stringAtCursor.startsWith('/')) {
      const pageFile = await this.resolvePageRoute(stringAtCursor);
      if (pageFile) {
        return Location.create(URI.file(pageFile).toString(), Range.create(0, 0, 0, 0));
      }
    }

    // Match navigateTo('/path'), router.push('/path'), <NuxtLink to="/path">, <NuxtLink href="/path">
    const routePatterns = [
      /navigateTo\(['"]([^'"]+)['"]/,
      /router\.push\(['"]([^'"]+)['"]/,
      /to\s*=\s*['"]([^'"]+)['"]/,  // Allow spaces around =
      /href\s*=\s*['"]([^'"]+)['"]/,  // Allow spaces around =
    ];

    for (const pattern of routePatterns) {
      const match = line.match(pattern);
      if (match) {
        const routePath = match[1];
        const pageFile = await this.resolvePageRoute(routePath);

        if (pageFile) {
          return Location.create(URI.file(pageFile).toString(), Range.create(0, 0, 0, 0));
        }
      }
    }

    return null;
  }

  /**
   * Resolve a route path to a page file
   * /about -> pages/about.vue
   * /users/:id -> pages/users/[id].vue
   */
  private async resolvePageRoute(routePath: string): Promise<string | null> {
    // Remove leading slash
    let pagePath = routePath.replace(/^\//, '');

    // Handle index route
    if (pagePath === '' || pagePath === '/') {
      pagePath = 'index';
    }

    // Convert dynamic segments: /users/:id -> /users/[id]
    pagePath = pagePath.replace(/:(\w+)/g, '[$1]');

    // Try to find the page file
    const extensions = ['.vue', '.tsx', '.jsx'];
    for (const ext of extensions) {
      const pageFile = this.projectManager.findFile('pages', `${pagePath}${ext}`);
      if (pageFile) {
        return pageFile;
      }
    }

    return null;
  }

  /**
   * Handle API routes ($fetch, useFetch, useAsyncData)
   */
  private async handleApiRoutes(line: string, stringAtCursor: string): Promise<Location | null> {
    // If cursor is on a string and it looks like an API path, try to resolve it
    if (stringAtCursor && stringAtCursor.startsWith('/api/')) {
      const apiFile = await this.resolveApiRoute(stringAtCursor);
      if (apiFile) {
        return Location.create(URI.file(apiFile).toString(), Range.create(0, 0, 0, 0));
      }
    }

    // Match $fetch('/api/...'), useFetch('/api/...'), etc.
    const apiPatterns = [
      /\$fetch\(['"]([^'"]+)['"]/,
      /useFetch\(['"]([^'"]+)['"]/,
      /useAsyncData\([^,]*,\s*\(\)\s*=>\s*\$fetch\(['"]([^'"]+)['"]/,
    ];

    for (const pattern of apiPatterns) {
      const match = line.match(pattern);
      if (match) {
        const apiPath = match[1];

        // Only handle /api/ routes
        if (!apiPath.startsWith('/api/')) {
          continue;
        }

        const apiFile = await this.resolveApiRoute(apiPath);
        if (apiFile) {
          return Location.create(URI.file(apiFile).toString(), Range.create(0, 0, 0, 0));
        }
      }
    }

    return null;
  }

  /**
   * Resolve an API route path to a handler file
   * /api/users -> server/api/users.ts or server/api/users/index.ts
   */
  private async resolveApiRoute(apiPath: string): Promise<string | null> {
    // Remove /api/ prefix
    let routePath = apiPath.replace(/^\/api\//, '');

    // Remove query parameters
    routePath = routePath.split('?')[0];

    // Try to find the API handler file
    const extensions = ['.ts', '.js', '.mjs', '.get.ts', '.post.ts', '.put.ts', '.delete.ts'];

    for (const ext of extensions) {
      const apiFile = this.projectManager.findFile('server', 'api', `${routePath}${ext}`);
      if (apiFile) {
        return apiFile;
      }
    }

    // Try index files
    for (const ext of extensions) {
      const apiFile = this.projectManager.findFile('server', 'api', routePath, `index${ext}`);
      if (apiFile) {
        return apiFile;
      }
    }

    return null;
  }

  /**
   * Handle components and composables
   */
  private async handleComponents(word: string): Promise<Location | null> {
    const typeParser = this.projectManager.getTypeParser();
    const symbolInfo = typeParser.getSymbolInfo(word);

    if (!symbolInfo) {
      this.logger.info(`[Definition:handleComponents] No symbol info for: ${word}`);
      return null;
    }

    const importPath = 'importPath' in symbolInfo ? symbolInfo.importPath : undefined;
    this.logger.info(`[Definition:handleComponents] Symbol info: type=${symbolInfo.type}, path=${symbolInfo.path}, importPath=${importPath}`);

    // For components, use the path directly
    if (symbolInfo.type === 'component' && symbolInfo.path) {
      this.logger.info(`[Definition:handleComponents] Checking component path: ${symbolInfo.path}`);
      if (fs.existsSync(symbolInfo.path)) {
        this.logger.info(`[Definition:handleComponents] ✓ Component file exists: ${symbolInfo.path}`);
        return Location.create(URI.file(symbolInfo.path).toString(), Range.create(0, 0, 0, 0));
      } else {
        this.logger.info(`[Definition:handleComponents] ✗ Component file does not exist: ${symbolInfo.path}`);
      }
    }

    // For composables and other symbols, resolve the import path
    if ((symbolInfo.type === 'composable' || symbolInfo.type === 'symbol') && importPath) {
      this.logger.info(`[Definition:handleComponents] Resolving import path: ${importPath}`);
      const tsConfigParser = this.projectManager.getTsConfigParser();
      const resolvedFile = tsConfigParser.findFileFromImport(importPath);

      if (resolvedFile) {
        this.logger.info(`[Definition:handleComponents] Resolved to: ${resolvedFile}`);
        if (fs.existsSync(resolvedFile)) {
          this.logger.info(`[Definition:handleComponents] ✓ Resolved file exists: ${resolvedFile}`);
          return Location.create(URI.file(resolvedFile).toString(), Range.create(0, 0, 0, 0));
        } else {
          this.logger.info(`[Definition:handleComponents] ✗ Resolved file does not exist: ${resolvedFile}`);
        }
      }

      // Try direct resolution
      const rootPath = this.projectManager.getRootPath();
      const directPath = path.join(rootPath, importPath);
      this.logger.info(`[Definition:handleComponents] Trying direct path: ${directPath}`);

      if (fs.existsSync(directPath)) {
        this.logger.info(`[Definition:handleComponents] ✓ Direct path exists: ${directPath}`);
        return Location.create(URI.file(directPath).toString(), Range.create(0, 0, 0, 0));
      } else {
        this.logger.info(`[Definition:handleComponents] ✗ Direct path does not exist: ${directPath}`);
      }
    }

    this.logger.info(`[Definition:handleComponents] ✗ Could not resolve definition for: ${word}`);
    return null;
  }

  /**
   * Handle custom plugin definitions (e.g., $dialog, $myPlugin)
   */
  private async handleCustomPlugins(word: string): Promise<Location | null> {
    const pluginName = word.substring(1); // Remove '$' prefix

    // Search in plugins directory and types directory
    const searchDirs = ['plugins', 'types'];
    const extensions = ['.ts', '.js', '.d.ts'];

    for (const dir of searchDirs) {
      for (const ext of extensions) {
        const pluginFile = this.projectManager.findFile(dir, `${pluginName}${ext}`);
        if (pluginFile) {
          return Location.create(URI.file(pluginFile).toString(), Range.create(0, 0, 0, 0));
        }
      }
    }

    // Search for any file that might define this plugin
    const files = await this.projectManager.findFiles(`**/${pluginName}*`);
    if (files.length > 0) {
      return Location.create(URI.file(files[0]).toString(), Range.create(0, 0, 0, 0));
    }

    return null;
  }

  /**
   * Get the line at the given offset
   */
  private getLine(text: string, offset: number): string {
    const lines = text.split(/\r?\n/);
    let currentOffset = 0;

    for (const line of lines) {
      const lineLength = line.length + 1; // +1 for newline
      if (offset < currentOffset + lineLength) {
        return line;
      }
      currentOffset += lineLength;
    }

    return '';
  }

  /**
   * Get the word at the given position
   */
  private getWordAtPosition(text: string, offset: number): string {
    const wordPattern = /[$\w]+/g;
    const line = this.getLine(text, offset);
    const lineOffset = offset - (text.lastIndexOf('\n', offset - 1) + 1);

    let match;
    while ((match = wordPattern.exec(line)) !== null) {
      if (match.index <= lineOffset && lineOffset <= match.index + match[0].length) {
        return match[0];
      }
    }

    return '';
  }

  /**
   * Get the string literal at the given position
   * Handles both single and double quoted strings
   */
  private getStringAtPosition(text: string, offset: number): string {
    const line = this.getLine(text, offset);
    const lineOffset = offset - (text.lastIndexOf('\n', offset - 1) + 1);

    // Match single quoted strings
    const singleQuotePattern = /'([^']*)'/g;
    let match;
    while ((match = singleQuotePattern.exec(line)) !== null) {
      const stringStart = match.index + 1;
      const stringEnd = match.index + match[0].length - 1;
      if (stringStart <= lineOffset && lineOffset <= stringEnd) {
        return match[1];
      }
    }

    // Match double quoted strings
    const doubleQuotePattern = /"([^"]*)"/g;
    while ((match = doubleQuotePattern.exec(line)) !== null) {
      const stringStart = match.index + 1;
      const stringEnd = match.index + match[0].length - 1;
      if (stringStart <= lineOffset && lineOffset <= stringEnd) {
        return match[1];
      }
    }

    // Match template literal strings
    const templatePattern = /`([^`]*)`/g;
    while ((match = templatePattern.exec(line)) !== null) {
      const stringStart = match.index + 1;
      const stringEnd = match.index + match[0].length - 1;
      if (stringStart <= lineOffset && lineOffset <= stringEnd) {
        return match[1];
      }
    }

    return '';
  }
}
