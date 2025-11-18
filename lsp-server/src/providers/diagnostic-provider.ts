import { Connection, Diagnostic, DiagnosticSeverity, Range } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
import * as fs from 'fs';
import * as path from 'path';

interface ImportStatement {
  line: number;
  importPath: string;
  importedSymbols: string[];
  range: Range;
}

export class DiagnosticProvider {
  constructor(
    private projectManager: NuxtProjectManager,
    private logger: Logger,
    private connection: Connection
  ) {}

  /**
   * Provide diagnostics for Nuxt-specific issues
   */
  async provideDiagnostics(document: TextDocument): Promise<void> {
    const diagnostics: Diagnostic[] = [];
    const text = document.getText();
    const lines = text.split(/\r?\n/);

    // 1. Validate path alias imports
    await this.validatePathAliasImports(document, lines, diagnostics);

    // 2. Check for missing .nuxt directory
    this.checkNuxtDirectory(diagnostics);

    // Send diagnostics to the client
    this.connection.sendDiagnostics({
      uri: document.uri,
      diagnostics,
    });
  }

  /**
   * Validate imports with Nuxt path aliases (~~/, ~/, @/)
   */
  private async validatePathAliasImports(
    document: TextDocument,
    lines: string[],
    diagnostics: Diagnostic[]
  ): Promise<void> {
    const imports = this.parseImports(document, lines);

    for (const importStatement of imports) {
      // Only validate Nuxt path aliases
      if (!this.isNuxtPathAlias(importStatement.importPath)) {
        continue;
      }

      this.logger.debug(`[Diagnostics] Validating import: ${importStatement.importPath}`);

      // Resolve the import path
      const tsConfigParser = this.projectManager.getTsConfigParser();
      const resolvedPath = tsConfigParser.resolveAliasPath(importStatement.importPath);

      if (!resolvedPath) {
        this.logger.debug(`[Diagnostics] Could not resolve path: ${importStatement.importPath}`);
        continue;
      }

      // Try to find the actual file with various extensions
      const extensions = ['.ts', '.js', '.mjs', '.tsx', '.jsx', '.vue', '.d.ts'];
      let filePath: string | null = null;

      // If the import path already has an extension, try it directly
      if (path.extname(importStatement.importPath)) {
        if (fs.existsSync(resolvedPath)) {
          filePath = resolvedPath;
        }
      } else {
        // Try adding extensions
        for (const ext of extensions) {
          const testPath = `${resolvedPath}${ext}`;
          if (fs.existsSync(testPath)) {
            filePath = testPath;
            break;
          }
        }

        // Try index files
        if (!filePath) {
          for (const ext of extensions) {
            const testPath = path.join(resolvedPath, `index${ext}`);
            if (fs.existsSync(testPath)) {
              filePath = testPath;
              break;
            }
          }
        }
      }

      if (!filePath) {
        // File not found - add diagnostic
        diagnostics.push({
          severity: DiagnosticSeverity.Error,
          range: importStatement.range,
          message: `Cannot find module '${importStatement.importPath}'`,
          source: 'nuxt-dx-tools',
        });
        this.logger.debug(`[Diagnostics] File not found: ${resolvedPath}`);
        continue;
      }

      // Validate exported symbols
      if (importStatement.importedSymbols.length > 0) {
        await this.validateExports(filePath, importStatement, diagnostics);
      }
    }
  }

  /**
   * Validate that imported symbols are actually exported from the file
   */
  private async validateExports(
    filePath: string,
    importStatement: ImportStatement,
    diagnostics: Diagnostic[]
  ): Promise<void> {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');

      for (const symbol of importStatement.importedSymbols) {
        // Check for various export patterns
        const exportPatterns = [
          new RegExp(`export\\s+(?:interface|type|class|function|const|let|var)\\s+${symbol}\\b`),
          new RegExp(`export\\s+\\{[^}]*\\b${symbol}\\b[^}]*\\}`),
          new RegExp(`export\\s+default\\s+${symbol}\\b`),
          // Also check for type exports
          new RegExp(`export\\s+type\\s+\\{[^}]*\\b${symbol}\\b[^}]*\\}`),
        ];

        const isExported = exportPatterns.some(pattern => pattern.test(content));

        if (!isExported) {
          this.logger.debug(`[Diagnostics] Symbol '${symbol}' not found in exports of ${filePath}`);
          // Don't add diagnostic - this might be a false positive if the symbol is re-exported
          // or if our regex doesn't catch complex export patterns
          // Instead, we just validate that the file exists (done above)
        } else {
          this.logger.debug(`[Diagnostics] ✓ Symbol '${symbol}' found in ${filePath}`);
        }
      }
    } catch (error) {
      this.logger.error(`[Diagnostics] Error reading file ${filePath}: ${error}`);
    }
  }

  /**
   * Check if the .nuxt directory exists
   */
  private checkNuxtDirectory(diagnostics: Diagnostic[]): void {
    const nuxtDir = path.join(this.projectManager.getRootPath(), '.nuxt');

    if (!fs.existsSync(nuxtDir)) {
      this.logger.warn('[Diagnostics] .nuxt directory not found - Nuxt may not be running');
      // Note: We don't add a diagnostic for this because it would show in every file
      // and the user might not have started the dev server yet
    }
  }

  /**
   * Parse import statements from the document
   */
  private parseImports(document: TextDocument, lines: string[]): ImportStatement[] {
    const imports: ImportStatement[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Match: import { Symbol1, Symbol2 } from 'path'
      const namedImportMatch = line.match(/import\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"]/);
      if (namedImportMatch) {
        const symbols = namedImportMatch[1]
          .split(',')
          .map(s => s.trim().split(/\s+as\s+/)[0].trim())
          .filter(s => s.length > 0);

        const importPath = namedImportMatch[2];
        const startChar = line.indexOf(importPath);

        imports.push({
          line: i,
          importPath,
          importedSymbols: symbols,
          range: {
            start: { line: i, character: startChar },
            end: { line: i, character: startChar + importPath.length },
          },
        });
        continue;
      }

      // Match: import type { Symbol1, Symbol2 } from 'path'
      const typeImportMatch = line.match(/import\s+type\s+\{([^}]+)\}\s+from\s+['"]([^'"]+)['"]/);
      if (typeImportMatch) {
        const symbols = typeImportMatch[1]
          .split(',')
          .map(s => s.trim().split(/\s+as\s+/)[0].trim())
          .filter(s => s.length > 0);

        const importPath = typeImportMatch[2];
        const startChar = line.indexOf(importPath);

        imports.push({
          line: i,
          importPath,
          importedSymbols: symbols,
          range: {
            start: { line: i, character: startChar },
            end: { line: i, character: startChar + importPath.length },
          },
        });
        continue;
      }

      // Match: import DefaultExport from 'path'
      const defaultImportMatch = line.match(/import\s+(\w+)\s+from\s+['"]([^'"]+)['"]/);
      if (defaultImportMatch) {
        const importPath = defaultImportMatch[2];
        const startChar = line.indexOf(importPath);

        imports.push({
          line: i,
          importPath,
          importedSymbols: [], // Don't validate default imports
          range: {
            start: { line: i, character: startChar },
            end: { line: i, character: startChar + importPath.length },
          },
        });
        continue;
      }

      // Match: import 'path' (side-effect import)
      const sideEffectMatch = line.match(/import\s+['"]([^'"]+)['"]/);
      if (sideEffectMatch) {
        const importPath = sideEffectMatch[1];
        const startChar = line.indexOf(importPath);

        imports.push({
          line: i,
          importPath,
          importedSymbols: [],
          range: {
            start: { line: i, character: startChar },
            end: { line: i, character: startChar + importPath.length },
          },
        });
      }
    }

    return imports;
  }

  /**
   * Check if an import path uses Nuxt path aliases
   */
  private isNuxtPathAlias(importPath: string): boolean {
    return importPath.startsWith('~/') ||
           importPath.startsWith('~~/') ||
           importPath.startsWith('@/') ||
           importPath.startsWith('#');
  }
}
