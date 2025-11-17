import { Hover, MarkupContent, MarkupKind, Position } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import * as fs from 'fs';
import * as path from 'path';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';

export class HoverProvider {
  constructor(
    private projectManager: NuxtProjectManager,
    private logger: Logger
  ) {}

  /**
   * Provide hover information for Nuxt-specific symbols
   *
   * Note: No early exit pattern check - each handler determines if it can provide info.
   * This prevents false positives where we match a pattern but can't actually provide hover info.
   */
  async provideHover(document: TextDocument, position: Position): Promise<Hover | null> {
    const text = document.getText();
    const offset = document.offsetAt(position);
    const line = this.getLine(text, offset);
    const word = this.getWordAtPosition(text, offset);
    const stringAtCursor = this.getStringAtPosition(text, offset);

    // PRIORITY 1: Check for page routes FIRST (before checking word)
    // This handles NuxtLink with to="/path" - show page preview instead of component info
    if (line.includes('navigateTo') || line.includes('router.push') || /to\s*=\s*['"]/.test(line) || /href\s*=\s*['"]/.test(line)) {
      const pageRouteHover = await this.handlePageRoutes(line, stringAtCursor);
      if (pageRouteHover) {
        this.logger.debug(`[Hover] Provided page route info`);
        return pageRouteHover;
      }
    }

    // PRIORITY 2: Check for import statements (show file preview)
    // Handle both string cursor position AND hovering over import statement
    if (line.includes('import') && (line.includes('from') || line.includes("'"))) {
      const importHover = await this.handleImportStatement(line, stringAtCursor);
      if (importHover) {
        this.logger.debug(`[Hover] Provided import file preview`);
        return importHover;
      }
    }

    // PRIORITY 3: Check for API routes
    if (line.includes('$fetch') || line.includes('useFetch') || line.includes('useAsyncData')) {
      const apiRouteHover = await this.handleApiRoutes(line, stringAtCursor);
      if (apiRouteHover) {
        this.logger.debug(`[Hover] Provided API route info`);
        return apiRouteHover;
      }
    }

    // 4. Check for virtual module imports (very specific, unlikely to false positive)
    if (line.includes('#imports') || line.includes('#app') || line.includes('#build') || line.includes('#components')) {
      const virtualModuleHover = this.handleVirtualModules(line);
      if (virtualModuleHover) {
        this.logger.debug(`[Hover] Provided virtual module info for: ${word}`);
        return virtualModuleHover;
      }
    }

    // 4. Check for data fetching calls (specific patterns)
    if (line.includes('useFetch') || line.includes('useAsyncData')) {
      const dataFetchingHover = this.handleDataFetching(line);
      if (dataFetchingHover) {
        this.logger.debug(`[Hover] Provided data fetching info for: ${word}`);
        return dataFetchingHover;
      }
    }

    // 5. Check for auto-imported symbols (only if we actually have info for it)
    // Skip if we're hovering over NuxtLink - let the page route handler deal with it
    const typeParser = this.projectManager.getTypeParser();
    const symbolInfo = typeParser.getSymbolInfo(word);

    // Don't show hover for NuxtLink component - the page route hover is more useful
    if (word === 'NuxtLink' || word === 'NuxtPage') {
      this.logger.debug(`[Hover] Skipping built-in Nuxt component: ${word}`);
      return null;
    }

    if (symbolInfo) {
      // We have actual info for this symbol, so provide hover
      const symbolHover = this.handleAutoImportedSymbols(word);
      if (symbolHover) {
        this.logger.debug(`[Hover] Provided symbol info for: ${word}`);
        return symbolHover;
      }
    }

    // Return null to let other LSP servers handle it (no log to avoid noise)
    return null;
  }

  /**
   * Handle import statement hover (show file preview)
   */
  private async handleImportStatement(line: string, stringAtCursor: string): Promise<Hover | null> {
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

    if (!importPath) {
      return null;
    }

    this.logger.debug(`[Hover] Checking import path: ${importPath}`);

    const rootPath = this.projectManager.getRootPath();
    const tsConfigParser = this.projectManager.getTsConfigParser();

    // Check if the import already has an extension
    const hasExtension = /\.[^/\\]+$/.test(importPath);
    const importExtension = hasExtension ? path.extname(importPath) : null;

    let resolvedPath: string | null = null;

    // Try with alias resolution first
    if (hasExtension) {
      const aliasResolved = tsConfigParser.resolveAliasPath(importPath);
      if (aliasResolved && fs.existsSync(aliasResolved)) {
        const resolvedExt = path.extname(aliasResolved);
        if (resolvedExt === importExtension) {
          resolvedPath = aliasResolved;
        }
      }

      // Try direct path
      if (!resolvedPath) {
        const directPath = path.join(rootPath, importPath);
        if (fs.existsSync(directPath)) {
          resolvedPath = directPath;
        }
      }

      // Try without tilde
      if (!resolvedPath && importPath.startsWith('~')) {
        const withoutTilde = importPath.replace(/^~+\//, '');
        const tildeStrippedPath = path.join(rootPath, withoutTilde);
        if (fs.existsSync(tildeStrippedPath)) {
          resolvedPath = tildeStrippedPath;
        }
      }

      // Try without @
      if (!resolvedPath && importPath.startsWith('@')) {
        const withoutAt = importPath.replace(/^@\//, '');
        const atStrippedPath = path.join(rootPath, withoutAt);
        if (fs.existsSync(atStrippedPath)) {
          resolvedPath = atStrippedPath;
        }
      }
    } else {
      // Try alias resolution
      const aliasResolved = tsConfigParser.resolveAliasPath(importPath);
      if (aliasResolved && fs.existsSync(aliasResolved) && !aliasResolved.endsWith('.d.ts')) {
        resolvedPath = aliasResolved;
      }

      // Try with various extensions
      if (!resolvedPath) {
        const extensions = ['.vue', '.ts', '.js', '.tsx', '.jsx', '.mjs', '.css', '.pcss', '.scss'];
        for (const ext of extensions) {
          const fullPath = path.join(rootPath, importPath + ext);
          if (fs.existsSync(fullPath)) {
            resolvedPath = fullPath;
            break;
          }
        }
      }
    }

    if (!resolvedPath) {
      return null;
    }

    // Read file preview
    const filePreview = this.readFirstLines(resolvedPath, 20);
    const fileName = path.basename(resolvedPath);
    const fileExt = path.extname(resolvedPath).slice(1);

    const content: MarkupContent = {
      kind: MarkupKind.Markdown,
      value: [
        '```typescript',
        `// Import: ${importPath}`,
        '```',
        '',
        `**File:** \`${fileName}\``,
        '',
        '**Preview:**',
        '```' + fileExt,
        filePreview,
        '```',
        '',
        '*Press `gd` to open the file*',
      ].join('\n'),
    };

    return { contents: content };
  }

  /**
   * Handle virtual module hover
   */
  private handleVirtualModules(line: string): Hover | null {
    const virtualModules: Record<string, { description: string; exports: string[] }> = {
      '#imports': {
        description: 'Nuxt auto-imports - all composables, utilities, and Vue APIs',
        exports: [
          'ref, computed, reactive, watch',
          'useRouter, useRoute, navigateTo',
          'useState, useFetch, useAsyncData',
          'definePageMeta, defineNuxtComponent',
          'All custom composables from ~/composables/',
        ],
      },
      '#app': {
        description: 'Nuxt core application utilities',
        exports: [
          'NuxtApp, useNuxtApp',
          'defineNuxtPlugin',
          'useRuntimeConfig',
          'abortNavigation, callOnce',
        ],
      },
      '#build': {
        description: 'Nuxt build-time configuration and metadata',
        exports: ['nuxtConfig', 'buildInfo'],
      },
      '#components': {
        description: 'All auto-imported components',
        exports: ['Component type definitions'],
      },
    };

    for (const [moduleName, info] of Object.entries(virtualModules)) {
      if (line.includes(moduleName)) {
        const content: MarkupContent = {
          kind: MarkupKind.Markdown,
          value: [
            '```typescript',
            `// ${info.description}`,
            `import { ... } from '${moduleName}'`,
            '```',
            '',
            '**Common exports:**',
            ...info.exports.map((exp) => `- ${exp}`),
            '',
            '*Press `gd` to view all exports in the type definition file*',
          ].join('\n'),
        };

        return { contents: content };
      }
    }

    return null;
  }

  /**
   * Handle API route hover
   */
  private async handleApiRoutes(line: string, stringAtCursor: string): Promise<Hover | null> {
    // If cursor is on a string and it looks like an API path, use that
    let apiPath = stringAtCursor && stringAtCursor.startsWith('/api/') ? stringAtCursor : null;

    // Otherwise, extract from the line
    if (!apiPath) {
      const apiPatterns = [
        /\$fetch\(['"]([^'"]+)['"]/,
        /useFetch\(['"]([^'"]+)['"]/,
        /useAsyncData\([^,]*,\s*\(\)\s*=>\s*\$fetch\(['"]([^'"]+)['"]/,
      ];

      for (const pattern of apiPatterns) {
        const match = line.match(pattern);
        if (match) {
          apiPath = match[1];
          break;
        }
      }
    }

    if (!apiPath || !apiPath.startsWith('/api/')) {
      return null;
    }

    const apiFile = await this.resolveApiRoute(apiPath);
    if (!apiFile) {
      return null;
    }

    // Read more lines of the API handler for better preview
    const handlerCode = this.readFirstLines(apiFile, 20);
    const fileExt = path.extname(apiFile).slice(1) || 'typescript';

    const content: MarkupContent = {
      kind: MarkupKind.Markdown,
      value: [
        '```typescript',
        `// API Route: ${apiPath}`,
        '```',
        '',
        `**File:** \`${path.basename(apiFile)}\``,
        '',
        '**Preview:**',
        '```' + fileExt,
        handlerCode,
        '```',
        '',
        '*Press `gd` to open the handler file*',
      ].join('\n'),
    };

    return { contents: content };
  }

  /**
   * Handle page route hover
   */
  private async handlePageRoutes(line: string, stringAtCursor: string): Promise<Hover | null> {
    // If cursor is on a string and it looks like a route path, use that
    let routePath = stringAtCursor && stringAtCursor.startsWith('/') ? stringAtCursor : null;

    // Otherwise, extract from the line
    if (!routePath) {
      const routePatterns = [
        /navigateTo\(['"]([^'"]+)['"]/,
        /router\.push\(['"]([^'"]+)['"]/,
        /to\s*=\s*['"]([^'"]+)['"]/,  // Fixed: allow spaces around =
        /href\s*=\s*['"]([^'"]+)['"]/,  // Fixed: allow spaces around =
      ];

      for (const pattern of routePatterns) {
        const match = line.match(pattern);
        if (match) {
          routePath = match[1];
          break;
        }
      }
    }

    if (!routePath) {
      return null;
    }

    // Only handle actual page routes (starting with /)
    if (!routePath.startsWith('/')) {
      return null;
    }

    const pageFile = await this.resolvePageRoute(routePath);
    if (!pageFile) {
      return null;
    }

    // Read first 20 lines of the page for preview
    const pagePreview = this.readFirstLines(pageFile, 20);
    const fileExt = path.extname(pageFile).slice(1) || 'vue';

    const content: MarkupContent = {
      kind: MarkupKind.Markdown,
      value: [
        '```typescript',
        `// Page Route: ${routePath}`,
        '```',
        '',
        `**Page:** \`${path.basename(pageFile)}\``,
        '',
        '**Preview:**',
        '```' + fileExt,
        pagePreview,
        '```',
        '',
        '*Press `gd` to open the page file*',
      ].join('\n'),
    };

    return { contents: content };
  }

  /**
   * Handle data fetching hover
   */
  private handleDataFetching(line: string): Hover | null {
    // Check for useFetch or useAsyncData
    if (!line.includes('useFetch') && !line.includes('useAsyncData')) {
      return null;
    }

    const tips: string[] = [];

    if (line.includes('useFetch')) {
      tips.push('**`useFetch`** - Composable for data fetching with SSR support');
      tips.push('');
      tips.push('**Key features:**');
      tips.push('- Automatically cached by URL');
      tips.push('- Runs on both server and client');
      tips.push('- Provides loading, error, and refresh states');
      tips.push('');
      tips.push('**Common options:**');
      tips.push('- `key`: Custom cache key');
      tips.push('- `server`: Set to `false` to skip SSR');
      tips.push('- `lazy`: Use `useLazyFetch` for non-blocking fetches');
    } else if (line.includes('useAsyncData')) {
      tips.push('**`useAsyncData`** - Composable for async data with SSR support');
      tips.push('');
      tips.push('**Key features:**');
      tips.push('- Manual cache key required');
      tips.push('- Full control over data fetching');
      tips.push('- Runs on both server and client');
      tips.push('');
      tips.push('**Tip:** Use `useFetch` for simple API calls');
    }

    if (tips.length > 0) {
      const content: MarkupContent = {
        kind: MarkupKind.Markdown,
        value: tips.join('\n'),
      };

      return { contents: content };
    }

    return null;
  }

  /**
   * Handle auto-imported symbols (composables, components)
   */
  private handleAutoImportedSymbols(word: string): Hover | null {
    const typeParser = this.projectManager.getTypeParser();
    const symbolInfo = typeParser.getSymbolInfo(word);

    if (!symbolInfo) {
      return null;
    }

    const lines: string[] = [];

    if (symbolInfo.type === 'composable' || symbolInfo.type === 'symbol') {
      lines.push('```typescript');
      lines.push('// Nuxt Auto-import');

      if (symbolInfo.importPath) {
        lines.push(`import { ${word} } from '${symbolInfo.importPath}'`);
      } else {
        lines.push(`export { ${word} }`);
      }

      lines.push('```');

      if (symbolInfo.importPath) {
        lines.push('');
        lines.push(`**Source:** \`${symbolInfo.importPath}\``);

        // Add helpful context based on import path
        if (symbolInfo.importPath.includes('#app')) {
          lines.push('');
          lines.push('*Built-in Nuxt composable*');
        } else if (symbolInfo.importPath.startsWith('..')) {
          lines.push('');
          lines.push('*Project composable or utility*');
        } else if (symbolInfo.importPath.includes('node_modules')) {
          const moduleMatch = symbolInfo.importPath.match(/node_modules\/([^/]+)/);
          if (moduleMatch) {
            lines.push('');
            lines.push(`*From module: ${moduleMatch[1]}*`);
          }
        }
      }
    } else if (symbolInfo.type === 'component') {
      lines.push('```vue');
      lines.push('<!-- Nuxt Auto-imported Component -->');
      lines.push(`<${word} />`);
      lines.push('```');

      if (symbolInfo.path) {
        lines.push('');
        lines.push(`**Source:** \`${symbolInfo.path}\``);
        lines.push('');
        lines.push('*Press `gd` to open the component file*');
      }
    }

    if (lines.length > 0) {
      const content: MarkupContent = {
        kind: MarkupKind.Markdown,
        value: lines.join('\n'),
      };

      return { contents: content };
    }

    return null;
  }

  /**
   * Resolve API route path to file (same logic as definition provider)
   */
  private async resolveApiRoute(apiPath: string): Promise<string | null> {
    let routePath = apiPath.replace(/^\/api\//, '');
    routePath = routePath.split('?')[0];

    const extensions = ['.ts', '.js', '.mjs', '.get.ts', '.post.ts', '.put.ts', '.delete.ts'];

    for (const ext of extensions) {
      const apiFile = this.projectManager.findFile('server', 'api', `${routePath}${ext}`);
      if (apiFile) {
        return apiFile;
      }
    }

    for (const ext of extensions) {
      const apiFile = this.projectManager.findFile('server', 'api', routePath, `index${ext}`);
      if (apiFile) {
        return apiFile;
      }
    }

    return null;
  }

  /**
   * Resolve page route path to file (same logic as definition provider)
   */
  private async resolvePageRoute(routePath: string): Promise<string | null> {
    let pagePath = routePath.replace(/^\//, '');

    if (pagePath === '' || pagePath === '/') {
      pagePath = 'index';
    }

    pagePath = pagePath.replace(/:(\w+)/g, '[$1]');

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
   * Read the first N lines of a file
   */
  private readFirstLines(filePath: string, maxLines: number): string {
    if (!fs.existsSync(filePath)) {
      return '';
    }

    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split(/\r?\n/).slice(0, maxLines);

    return lines.join('\n');
  }

  /**
   * Get the line at the given offset
   */
  private getLine(text: string, offset: number): string {
    const lines = text.split(/\r?\n/);
    let currentOffset = 0;

    for (const line of lines) {
      const lineLength = line.length + 1;
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
      const stringStart = match.index + 1; // Position after opening quote
      const stringEnd = match.index + match[0].length - 1; // Position of closing quote
      // Cursor must be between quotes (inclusive of content, exclusive of quotes)
      if (stringStart <= lineOffset && lineOffset < stringEnd) {
        return match[1];
      }
    }

    // Match double quoted strings
    const doubleQuotePattern = /"([^"]*)"/g;
    while ((match = doubleQuotePattern.exec(line)) !== null) {
      const stringStart = match.index + 1;
      const stringEnd = match.index + match[0].length - 1;
      if (stringStart <= lineOffset && lineOffset < stringEnd) {
        return match[1];
      }
    }

    // Match template literal strings
    const templatePattern = /`([^`]*)`/g;
    while ((match = templatePattern.exec(line)) !== null) {
      const stringStart = match.index + 1;
      const stringEnd = match.index + match[0].length - 1;
      if (stringStart <= lineOffset && lineOffset < stringEnd) {
        return match[1];
      }
    }

    return '';
  }
}
