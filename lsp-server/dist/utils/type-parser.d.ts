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
export declare class TypeParser {
    private importCache;
    private componentCache;
    private moduleCache;
    private logger;
    private rootPath;
    constructor(rootPath: string, logger: Logger);
    /**
     * Parse .nuxt/imports.d.ts for all auto-imported symbols
     */
    private parseImports;
    /**
     * Parse .nuxt/components.d.ts for all components
     */
    private parseComponents;
    /**
     * Resolve component path from .nuxt relative path to absolute path
     */
    private resolveComponentPath;
    /**
     * Parse package.json for Nuxt modules
     */
    private parsePackageModules;
    /**
     * Get cached or fresh imports
     */
    getImports(): Map<string, SymbolInfo>;
    /**
     * Get cached or fresh components
     */
    getComponents(): Map<string, ComponentInfo>;
    /**
     * Get cached or fresh modules
     */
    getModules(): Map<string, ModuleInfo>;
    /**
     * Get symbol information
     */
    getSymbolInfo(symbol: string): SymbolInfo | ComponentInfo | null;
    /**
     * Get all symbols (imports + components)
     */
    getAllSymbols(): Map<string, SymbolInfo | ComponentInfo>;
    /**
     * Clear all caches
     */
    clearCache(): void;
}
//# sourceMappingURL=type-parser.d.ts.map