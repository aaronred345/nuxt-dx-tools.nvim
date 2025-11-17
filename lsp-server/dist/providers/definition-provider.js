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
exports.DefinitionProvider = void 0;
const node_1 = require("vscode-languageserver/node");
const vscode_uri_1 = require("vscode-uri");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class DefinitionProvider {
    projectManager;
    logger;
    constructor(projectManager, logger) {
        this.projectManager = projectManager;
        this.logger = logger;
    }
    /**
     * Provide goto definition for Nuxt-specific symbols
     *
     * Note: No early exit pattern check - each handler determines if it can provide a definition.
     * This prevents false positives where we match a pattern but can't actually provide a definition.
     */
    async provideDefinition(document, position) {
        const text = document.getText();
        const offset = document.offsetAt(position);
        const line = this.getLine(text, offset);
        const word = this.getWordAtPosition(text, offset);
        this.logger.info(`[Definition] Request for word="${word}" in line="${line.trim()}"`);
        // 1. Check for virtual module imports (very specific)
        if (line.includes('#imports') || line.includes('#app') || line.includes('#build') || line.includes('#components')) {
            this.logger.info(`[Definition] Checking virtual modules...`);
            const virtualModuleDef = this.handleVirtualModules(line);
            if (virtualModuleDef) {
                this.logger.info(`[Definition] ✓ Provided virtual module definition`);
                return virtualModuleDef;
            }
            this.logger.info(`[Definition] ✗ No virtual module definition found`);
        }
        // 2. Check for import statements with path aliases
        if (line.includes('import') && (line.includes('from') || line.includes("'"))) {
            this.logger.info(`[Definition] Checking import statement...`);
            const importDef = await this.handleImportStatement(line, word);
            if (importDef) {
                this.logger.info(`[Definition] ✓ Provided import definition`);
                return importDef;
            }
            this.logger.info(`[Definition] ✗ No import definition found`);
        }
        // 3. Check for definePageMeta context (layout, middleware)
        if (line.includes('layout:') || line.includes('middleware:')) {
            this.logger.info(`[Definition] Checking definePageMeta...`);
            const pageMetaDef = await this.handleDefinePageMeta(word, line);
            if (pageMetaDef) {
                this.logger.info(`[Definition] ✓ Provided definePageMeta definition for: ${word}`);
                return pageMetaDef;
            }
            this.logger.info(`[Definition] ✗ No definePageMeta definition found`);
        }
        // 4. Check for page routes (specific patterns)
        if (line.includes('navigateTo') || line.includes('router.push') || /to=['"]/.test(line)) {
            this.logger.info(`[Definition] Checking page routes...`);
            const routeDef = await this.handlePageRoutes(line);
            if (routeDef) {
                this.logger.info(`[Definition] ✓ Provided page route definition`);
                return routeDef;
            }
            this.logger.info(`[Definition] ✗ No page route definition found`);
        }
        // 5. Check for API routes (specific patterns)
        if (line.includes('$fetch') || line.includes('useFetch') || line.includes('useAsyncData')) {
            this.logger.info(`[Definition] Checking API routes...`);
            const apiRouteDef = await this.handleApiRoutes(line);
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
            }
            else {
                this.logger.info(`[Definition] ✗ Symbol has no path or importPath: ${word}`);
            }
        }
        else {
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
    async handleImportStatement(line, word) {
        // Match: import ... from 'path' or import 'path'
        const importMatch = line.match(/from\s+['"]([^'"]+)['"]|import\s+['"]([^'"]+)['"]/);
        if (!importMatch) {
            return null;
        }
        const importPath = importMatch[1] || importMatch[2];
        this.logger.info(`[Definition] Found import path: ${importPath}`);
        // Check if the import already has an extension (has a dot after the last slash)
        const hasExtension = /\.[^/\\]+$/.test(importPath);
        // Resolve the import path using tsconfig aliases
        const tsConfigParser = this.projectManager.getTsConfigParser();
        const resolvedPath = tsConfigParser.resolveAliasPath(importPath);
        this.logger.info(`[Definition] Resolved import path: ${resolvedPath || 'null'}, hasExtension: ${hasExtension}`);
        if (resolvedPath && fs.existsSync(resolvedPath)) {
            return node_1.Location.create(vscode_uri_1.URI.file(resolvedPath).toString(), node_1.Range.create(0, 0, 0, 0));
        }
        const rootPath = this.projectManager.getRootPath();
        // If the import already has an extension, try it directly first
        if (hasExtension) {
            const directPath = path.join(rootPath, importPath);
            if (fs.existsSync(directPath)) {
                this.logger.info(`[Definition] Found file with existing extension: ${directPath}`);
                return node_1.Location.create(vscode_uri_1.URI.file(directPath).toString(), node_1.Range.create(0, 0, 0, 0));
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
                return node_1.Location.create(vscode_uri_1.URI.file(fullPath).toString(), node_1.Range.create(0, 0, 0, 0));
            }
        }
        // Try without extension as a fallback
        if (!hasExtension) {
            const directPath = path.join(rootPath, importPath);
            if (fs.existsSync(directPath)) {
                this.logger.info(`[Definition] Found file directly: ${directPath}`);
                return node_1.Location.create(vscode_uri_1.URI.file(directPath).toString(), node_1.Range.create(0, 0, 0, 0));
            }
        }
        this.logger.info(`[Definition] Import path not found: ${importPath}`);
        return null;
    }
    /**
     * Handle virtual module imports (#imports, #app, #build, etc.)
     */
    handleVirtualModules(line) {
        const virtualModuleMatch = line.match(/from\s+['"]#(imports|app|build|components|internal\/nitro)['"]/);
        if (!virtualModuleMatch) {
            return null;
        }
        const moduleName = virtualModuleMatch[1];
        const rootPath = this.projectManager.getRootPath();
        // Map virtual modules to their .d.ts files
        const moduleMap = {
            imports: '.nuxt/imports.d.ts',
            app: '.nuxt/imports.d.ts',
            build: '.nuxt/types/nuxt.d.ts',
            components: '.nuxt/components.d.ts',
            'internal/nitro': '.nuxt/types/nitro.d.ts',
        };
        const filePath = path.join(rootPath, moduleMap[moduleName] || '.nuxt/imports.d.ts');
        if (fs.existsSync(filePath)) {
            return node_1.Location.create(vscode_uri_1.URI.file(filePath).toString(), node_1.Range.create(0, 0, 0, 0));
        }
        return null;
    }
    /**
     * Handle definePageMeta context (layout, middleware)
     */
    async handleDefinePageMeta(word, line) {
        // Check if we're in a definePageMeta context
        if (!line.includes('layout') && !line.includes('middleware')) {
            return null;
        }
        // Extract layout name: layout: 'default' or layout: "custom"
        const layoutMatch = line.match(/layout:\s*['"]([^'"]+)['"]/);
        if (layoutMatch) {
            const layoutName = layoutMatch[1];
            const layoutFile = this.projectManager.findFile('layouts', `${layoutName}.vue`);
            if (layoutFile) {
                return node_1.Location.create(vscode_uri_1.URI.file(layoutFile).toString(), node_1.Range.create(0, 0, 0, 0));
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
            const middlewareFile = this.projectManager.findFile('middleware', `${middlewareName}.ts`) ||
                this.projectManager.findFile('middleware', `${middlewareName}.js`) ||
                this.projectManager.findFile('server', 'middleware', `${middlewareName}.ts`) ||
                this.projectManager.findFile('server', 'middleware', `${middlewareName}.js`);
            if (middlewareFile) {
                return node_1.Location.create(vscode_uri_1.URI.file(middlewareFile).toString(), node_1.Range.create(0, 0, 0, 0));
            }
        }
        return null;
    }
    /**
     * Handle page routes (navigateTo, NuxtLink, router.push)
     */
    async handlePageRoutes(line) {
        // Match navigateTo('/path'), router.push('/path'), <NuxtLink to="/path">
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
                if (pageFile) {
                    return node_1.Location.create(vscode_uri_1.URI.file(pageFile).toString(), node_1.Range.create(0, 0, 0, 0));
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
    async resolvePageRoute(routePath) {
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
    async handleApiRoutes(line) {
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
                    return node_1.Location.create(vscode_uri_1.URI.file(apiFile).toString(), node_1.Range.create(0, 0, 0, 0));
                }
            }
        }
        return null;
    }
    /**
     * Resolve an API route path to a handler file
     * /api/users -> server/api/users.ts or server/api/users/index.ts
     */
    async resolveApiRoute(apiPath) {
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
    async handleComponents(word) {
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
                return node_1.Location.create(vscode_uri_1.URI.file(symbolInfo.path).toString(), node_1.Range.create(0, 0, 0, 0));
            }
            else {
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
                    return node_1.Location.create(vscode_uri_1.URI.file(resolvedFile).toString(), node_1.Range.create(0, 0, 0, 0));
                }
                else {
                    this.logger.info(`[Definition:handleComponents] ✗ Resolved file does not exist: ${resolvedFile}`);
                }
            }
            // Try direct resolution
            const rootPath = this.projectManager.getRootPath();
            const directPath = path.join(rootPath, importPath);
            this.logger.info(`[Definition:handleComponents] Trying direct path: ${directPath}`);
            if (fs.existsSync(directPath)) {
                this.logger.info(`[Definition:handleComponents] ✓ Direct path exists: ${directPath}`);
                return node_1.Location.create(vscode_uri_1.URI.file(directPath).toString(), node_1.Range.create(0, 0, 0, 0));
            }
            else {
                this.logger.info(`[Definition:handleComponents] ✗ Direct path does not exist: ${directPath}`);
            }
        }
        this.logger.info(`[Definition:handleComponents] ✗ Could not resolve definition for: ${word}`);
        return null;
    }
    /**
     * Handle custom plugin definitions (e.g., $dialog, $myPlugin)
     */
    async handleCustomPlugins(word) {
        const pluginName = word.substring(1); // Remove '$' prefix
        // Search in plugins directory and types directory
        const searchDirs = ['plugins', 'types'];
        const extensions = ['.ts', '.js', '.d.ts'];
        for (const dir of searchDirs) {
            for (const ext of extensions) {
                const pluginFile = this.projectManager.findFile(dir, `${pluginName}${ext}`);
                if (pluginFile) {
                    return node_1.Location.create(vscode_uri_1.URI.file(pluginFile).toString(), node_1.Range.create(0, 0, 0, 0));
                }
            }
        }
        // Search for any file that might define this plugin
        const files = await this.projectManager.findFiles(`**/${pluginName}*`);
        if (files.length > 0) {
            return node_1.Location.create(vscode_uri_1.URI.file(files[0]).toString(), node_1.Range.create(0, 0, 0, 0));
        }
        return null;
    }
    /**
     * Get the line at the given offset
     */
    getLine(text, offset) {
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
exports.DefinitionProvider = DefinitionProvider;
//# sourceMappingURL=definition-provider.js.map