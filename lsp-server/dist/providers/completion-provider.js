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
exports.CompletionProvider = void 0;
const node_1 = require("vscode-languageserver/node");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class CompletionProvider {
    projectManager;
    logger;
    constructor(projectManager, logger) {
        this.projectManager = projectManager;
        this.logger = logger;
    }
    /**
     * Check if this looks like a Nuxt-specific completion context
     */
    isLikelyNuxtContext(line) {
        return (
        // Import statements with Nuxt patterns
        /from\s+['"]#(imports|app|build|components)/.test(line) ||
            /from\s+['"][~@]\//.test(line) ||
            // definePageMeta
            line.includes('definePageMeta') ||
            // Vue template component tags
            /<[A-Z][a-zA-Z0-9]*/.test(line) ||
            // Virtual module imports
            line.includes('#imports') ||
            line.includes('#app') ||
            line.includes('#build') ||
            line.includes('#components'));
    }
    /**
     * Provide completions for Nuxt-specific contexts
     */
    async provideCompletion(document, position) {
        const text = document.getText();
        const offset = document.offsetAt(position);
        const line = this.getLine(text, offset);
        // FAST EARLY EXIT: Only provide completions for Nuxt-specific contexts
        if (!this.isLikelyNuxtContext(line)) {
            return null;
        }
        this.logger.debug(`[Completion] Nuxt context detected: line="${line}"`);
        // 1. Check if we're in an import statement
        if (this.isInImportStatement(line)) {
            return this.provideImportCompletions(line);
        }
        // 2. Check if we're in definePageMeta
        if (this.isInDefinePageMeta(text, offset)) {
            return this.providePageMetaCompletions(line);
        }
        // 3. Check if we're typing a component
        const componentCompletions = await this.provideComponentCompletions(line);
        if (componentCompletions) {
            return componentCompletions;
        }
        // Return null to let other completion providers handle it
        return null;
    }
    /**
     * Check if cursor is in a Nuxt-specific import statement
     */
    isInImportStatement(line) {
        // Only trigger for Nuxt-specific imports (virtual modules and path aliases)
        return (/from\s+['"]#(imports|app|build|components)/.test(line) ||
            /from\s+['"][~@]\//.test(line) ||
            /import\s+['"]#(imports|app|build|components)/.test(line) ||
            /import\s+['"][~@]\//.test(line));
    }
    /**
     * Provide completions for import paths
     */
    provideImportCompletions(line) {
        const completions = [];
        // Get path aliases from tsconfig
        const tsConfigParser = this.projectManager.getTsConfigParser();
        const aliases = tsConfigParser.getAliases();
        // Add alias completions
        for (const [alias, target] of Object.entries(aliases)) {
            completions.push({
                label: alias,
                kind: node_1.CompletionItemKind.Folder,
                detail: `→ ${target}`,
                documentation: {
                    kind: 'markdown',
                    value: `**Path Alias**\n\nResolves to: \`${target}\``,
                },
                sortText: `0_${alias}`, // Sort aliases first
            });
        }
        // Add virtual module completions
        const virtualModules = [
            {
                label: '#imports',
                detail: 'Nuxt auto-imports',
                documentation: 'All auto-imported composables, utilities, and Vue APIs',
            },
            {
                label: '#app',
                detail: 'Nuxt app utilities',
                documentation: 'Core Nuxt application utilities and types',
            },
            {
                label: '#build',
                detail: 'Nuxt build config',
                documentation: 'Build-time configuration and metadata',
            },
            {
                label: '#components',
                detail: 'Component types',
                documentation: 'Type definitions for all auto-imported components',
            },
        ];
        for (const module of virtualModules) {
            completions.push({
                label: module.label,
                kind: node_1.CompletionItemKind.Module,
                detail: module.detail,
                documentation: {
                    kind: 'markdown',
                    value: module.documentation,
                },
                sortText: `1_${module.label}`,
            });
        }
        // If currently typing a path, provide directory/file completions
        const pathMatch = line.match(/from\s+['"]([^'"]*)/);
        if (pathMatch) {
            const currentPath = pathMatch[1];
            const dirCompletions = this.getDirectoryCompletions(currentPath);
            completions.push(...dirCompletions);
        }
        return completions;
    }
    /**
     * Get directory/file completions for a given path
     */
    getDirectoryCompletions(currentPath) {
        const completions = [];
        const rootPath = this.projectManager.getRootPath();
        // Resolve the current path
        const tsConfigParser = this.projectManager.getTsConfigParser();
        let resolvedPath = tsConfigParser.resolveAliasPath(currentPath);
        if (!resolvedPath) {
            // Try relative path
            resolvedPath = path.join(rootPath, currentPath);
        }
        // Get the directory to list
        const dirPath = fs.existsSync(resolvedPath) && fs.statSync(resolvedPath).isDirectory()
            ? resolvedPath
            : path.dirname(resolvedPath);
        if (!fs.existsSync(dirPath)) {
            return completions;
        }
        try {
            const entries = fs.readdirSync(dirPath, { withFileTypes: true });
            for (const entry of entries) {
                // Skip hidden files and node_modules
                if (entry.name.startsWith('.') || entry.name === 'node_modules') {
                    continue;
                }
                const fullPath = path.join(dirPath, entry.name);
                if (entry.isDirectory()) {
                    completions.push({
                        label: entry.name + '/',
                        kind: node_1.CompletionItemKind.Folder,
                        sortText: `2_${entry.name}`,
                    });
                }
                else {
                    // Only show importable files
                    const ext = path.extname(entry.name);
                    if (['.ts', '.js', '.vue', '.mjs', '.tsx', '.jsx'].includes(ext)) {
                        completions.push({
                            label: entry.name,
                            kind: node_1.CompletionItemKind.File,
                            sortText: `3_${entry.name}`,
                        });
                    }
                }
            }
        }
        catch (error) {
            this.logger.error(`Error reading directory ${dirPath}: ${error}`);
        }
        return completions;
    }
    /**
     * Check if cursor is in definePageMeta
     */
    isInDefinePageMeta(text, offset) {
        // Find definePageMeta blocks before the cursor
        const beforeCursor = text.substring(0, offset);
        const definePageMetaMatch = beforeCursor.lastIndexOf('definePageMeta');
        if (definePageMetaMatch === -1) {
            return false;
        }
        // Check if we're still inside the definePageMeta block
        const afterMatch = text.substring(definePageMetaMatch);
        const openBraces = (afterMatch.match(/\{/g) || []).length;
        const closeBraces = (afterMatch.match(/\}/g) || []).length;
        return openBraces > closeBraces;
    }
    /**
     * Provide completions for definePageMeta
     */
    providePageMetaCompletions(line) {
        const completions = [];
        // Check if we're completing a layout value
        if (line.includes('layout') && line.match(/layout:\s*['"][^'"]*$/)) {
            completions.push(...this.getLayoutCompletions());
        }
        // Check if we're completing a middleware value
        if (line.includes('middleware') && line.match(/middleware:\s*['"][^'"]*$/)) {
            completions.push(...this.getMiddlewareCompletions());
        }
        // If no specific context, provide property completions
        if (completions.length === 0 && !line.match(/:\s*['"][^'"]*$/)) {
            completions.push({
                label: 'layout',
                kind: node_1.CompletionItemKind.Property,
                insertText: 'layout: \'$1\'',
                insertTextFormat: node_1.InsertTextFormat.Snippet,
                documentation: 'Set the layout for this page',
            }, {
                label: 'middleware',
                kind: node_1.CompletionItemKind.Property,
                insertText: 'middleware: \'$1\'',
                insertTextFormat: node_1.InsertTextFormat.Snippet,
                documentation: 'Add middleware to this page',
            }, {
                label: 'alias',
                kind: node_1.CompletionItemKind.Property,
                insertText: 'alias: \'$1\'',
                insertTextFormat: node_1.InsertTextFormat.Snippet,
                documentation: 'Set route alias',
            }, {
                label: 'keepalive',
                kind: node_1.CompletionItemKind.Property,
                insertText: 'keepalive: $1',
                insertTextFormat: node_1.InsertTextFormat.Snippet,
                documentation: 'Enable keepalive for this page',
            });
        }
        return completions;
    }
    /**
     * Get layout completions
     */
    getLayoutCompletions() {
        const completions = [];
        const layoutsPath = this.projectManager.findFile('layouts');
        if (!layoutsPath || !fs.existsSync(layoutsPath)) {
            return completions;
        }
        try {
            const layouts = fs.readdirSync(layoutsPath);
            for (const layout of layouts) {
                if (layout.endsWith('.vue')) {
                    const layoutName = layout.replace('.vue', '');
                    completions.push({
                        label: layoutName,
                        kind: node_1.CompletionItemKind.Value,
                        detail: `Layout: ${layoutName}`,
                    });
                }
            }
        }
        catch (error) {
            this.logger.error(`Error reading layouts directory: ${error}`);
        }
        return completions;
    }
    /**
     * Get middleware completions
     */
    getMiddlewareCompletions() {
        const completions = [];
        const middlewarePath = this.projectManager.findFile('middleware');
        if (!middlewarePath || !fs.existsSync(middlewarePath)) {
            return completions;
        }
        try {
            const middlewares = fs.readdirSync(middlewarePath);
            for (const middleware of middlewares) {
                if (middleware.endsWith('.ts') || middleware.endsWith('.js')) {
                    const middlewareName = middleware.replace(/\.(ts|js)$/, '');
                    completions.push({
                        label: middlewareName,
                        kind: node_1.CompletionItemKind.Value,
                        detail: `Middleware: ${middlewareName}`,
                    });
                }
            }
        }
        catch (error) {
            this.logger.error(`Error reading middleware directory: ${error}`);
        }
        return completions;
    }
    /**
     * Provide component completions
     */
    async provideComponentCompletions(line) {
        // Only trigger if we're in a Vue template component tag (PascalCase after <)
        // This is more specific than just checking for '<'
        if (!/<[A-Z][a-zA-Z0-9]*/.test(line)) {
            return null;
        }
        const typeParser = this.projectManager.getTypeParser();
        const components = typeParser.getComponents();
        const completions = [];
        for (const [name, component] of components) {
            completions.push({
                label: name,
                kind: node_1.CompletionItemKind.Class,
                detail: `Component from ${path.basename(component.path)}`,
                documentation: {
                    kind: 'markdown',
                    value: `**Auto-imported Component**\n\nSource: \`${component.path}\``,
                },
            });
        }
        return completions.length > 0 ? completions : null;
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
}
exports.CompletionProvider = CompletionProvider;
//# sourceMappingURL=completion-provider.js.map