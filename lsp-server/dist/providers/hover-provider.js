"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.HoverProvider = void 0;
const node_1 = require("vscode-languageserver/node");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class HoverProvider {
    projectManager;
    logger;
    constructor(projectManager, logger) {
        this.projectManager = projectManager;
        this.logger = logger;
    }
    /**
     * Provide hover information for Nuxt-specific symbols
     *
     * Note: No early exit pattern check - each handler determines if it can provide info.
     * This prevents false positives where we match a pattern but can't actually provide hover info.
     */
    async provideHover(document, position) {
        const text = document.getText();
        const offset = document.offsetAt(position);
        const line = this.getLine(text, offset);
        const word = this.getWordAtPosition(text, offset);
        // 1. Check for virtual module imports (very specific, unlikely to false positive)
        if (line.includes('#imports') || line.includes('#app') || line.includes('#build') || line.includes('#components')) {
            const virtualModuleHover = this.handleVirtualModules(line);
            if (virtualModuleHover) {
                this.logger.debug(`[Hover] Provided virtual module info for: ${word}`);
                return virtualModuleHover;
            }
        }
        // 2. Check for API routes (specific patterns)
        if (line.includes('$fetch') || line.includes('useFetch') || line.includes('useAsyncData')) {
            const apiRouteHover = await this.handleApiRoutes(line);
            if (apiRouteHover) {
                this.logger.debug(`[Hover] Provided API route info`);
                return apiRouteHover;
            }
        }
        // 3. Check for page routes (specific patterns)
        if (line.includes('navigateTo') || line.includes('router.push') || /to=['"]/.test(line)) {
            const pageRouteHover = await this.handlePageRoutes(line);
            if (pageRouteHover) {
                this.logger.debug(`[Hover] Provided page route info`);
                return pageRouteHover;
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
        // This is the key change - we only check the type parser if we have actual symbol info
        const typeParser = this.projectManager.getTypeParser();
        const symbolInfo = typeParser.getSymbolInfo(word);
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
     * Handle virtual module hover
     */
    handleVirtualModules(line) {
        const virtualModules = {
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
                const content = {
                    kind: node_1.MarkupKind.Markdown,
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
    async handleApiRoutes(line) {
        const apiPatterns = [
            /\$fetch\(['"]([^'"]+)['"]/,
            /useFetch\(['"]([^'"]+)['"]/,
            /useAsyncData\([^,]*,\s*\(\)\s*=>\s*\$fetch\(['"]([^'"]+)['"]/,
        ];
        for (const pattern of apiPatterns) {
            const match = line.match(pattern);
            if (match) {
                const apiPath = match[1];
                if (!apiPath.startsWith('/api/')) {
                    continue;
                }
                const apiFile = await this.resolveApiRoute(apiPath);
                if (!apiFile) {
                    continue;
                }
                // Read the first few lines of the API handler
                const handlerCode = this.readFirstLines(apiFile, 10);
                const content = {
                    kind: node_1.MarkupKind.Markdown,
                    value: [
                        '```typescript',
                        `// API Route: ${apiPath}`,
                        '```',
                        '',
                        '**Handler:**',
                        '```typescript',
                        handlerCode,
                        '```',
                        '',
                        `**File:** \`${path.basename(apiFile)}\``,
                        '',
                        '*Press `gd` to open the handler file*',
                    ].join('\n'),
                };
                return { contents: content };
            }
        }
        return null;
    }
    /**
     * Handle page route hover
     */
    async handlePageRoutes(line) {
        const routePatterns = [
            /navigateTo\(['"]([^'"]+)['"]/,
            /router\.push\(['"]([^'"]+)['"]/,
            /to=['"]([^'"]+)['"]/,
        ];
        for (const pattern of routePatterns) {
            const match = line.match(pattern);
            if (match) {
                const routePath = match[1];
                const pageFile = await this.resolvePageRoute(routePath);
                if (!pageFile) {
                    continue;
                }
                const content = {
                    kind: node_1.MarkupKind.Markdown,
                    value: [
                        '```typescript',
                        `// Page Route: ${routePath}`,
                        '```',
                        '',
                        `**Page:** \`${path.basename(pageFile)}\``,
                        '',
                        '*Press `gd` to open the page file*',
                    ].join('\n'),
                };
                return { contents: content };
            }
        }
        return null;
    }
    /**
     * Handle data fetching hover
     */
    handleDataFetching(line) {
        // Check for useFetch or useAsyncData
        if (!line.includes('useFetch') && !line.includes('useAsyncData')) {
            return null;
        }
        const tips = [];
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
        }
        else if (line.includes('useAsyncData')) {
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
            const content = {
                kind: node_1.MarkupKind.Markdown,
                value: tips.join('\n'),
            };
            return { contents: content };
        }
        return null;
    }
    /**
     * Handle auto-imported symbols (composables, components)
     */
    handleAutoImportedSymbols(word) {
        const typeParser = this.projectManager.getTypeParser();
        const symbolInfo = typeParser.getSymbolInfo(word);
        if (!symbolInfo) {
            return null;
        }
        const lines = [];
        if (symbolInfo.type === 'composable' || symbolInfo.type === 'symbol') {
            lines.push('```typescript');
            lines.push('// Nuxt Auto-import');
            if (symbolInfo.importPath) {
                lines.push(`import { ${word} } from '${symbolInfo.importPath}'`);
            }
            else {
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
                }
                else if (symbolInfo.importPath.startsWith('..')) {
                    lines.push('');
                    lines.push('*Project composable or utility*');
                }
                else if (symbolInfo.importPath.includes('node_modules')) {
                    const moduleMatch = symbolInfo.importPath.match(/node_modules\/([^/]+)/);
                    if (moduleMatch) {
                        lines.push('');
                        lines.push(`*From module: ${moduleMatch[1]}*`);
                    }
                }
            }
        }
        else if (symbolInfo.type === 'component') {
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
            const content = {
                kind: node_1.MarkupKind.Markdown,
                value: lines.join('\n'),
            };
            return { contents: content };
        }
        return null;
    }
    /**
     * Resolve API route path to file (same logic as definition provider)
     */
    async resolveApiRoute(apiPath) {
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
    async resolvePageRoute(routePath) {
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
    readFirstLines(filePath, maxLines) {
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
    getLine(text, offset) {
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
    getWordAtPosition(text, offset) {
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
}
exports.HoverProvider = HoverProvider;
//# sourceMappingURL=hover-provider.js.map