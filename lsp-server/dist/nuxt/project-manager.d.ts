import { Logger } from '../utils/logger';
import { TsConfigParser } from '../utils/tsconfig-parser';
import { TypeParser } from '../utils/type-parser';
export interface NuxtStructure {
    hasAppDir: boolean;
    hasNuxtDir: boolean;
    isNuxt4: boolean;
    rootPath: string;
    appPath: string;
}
export declare class NuxtProjectManager {
    private rootPath;
    private logger;
    private tsConfigParser;
    private typeParser;
    private structure;
    constructor(rootUri: string, logger: Logger);
    /**
     * Initialize the project manager
     */
    initialize(): Promise<void>;
    /**
     * Detect Nuxt project structure (Nuxt 3 vs Nuxt 4)
     */
    private detectNuxtStructure;
    /**
     * Get the Nuxt project structure
     */
    getStructure(): NuxtStructure;
    /**
     * Get the tsconfig parser
     */
    getTsConfigParser(): TsConfigParser;
    /**
     * Get the type parser
     */
    getTypeParser(): TypeParser;
    /**
     * Get the root path
     */
    getRootPath(): string;
    /**
     * Get the app path (with trailing slash)
     */
    getAppPath(): string;
    /**
     * Resolve a path relative to the app directory
     * @param relativePath Path relative to app/ or root
     * @returns Absolute path
     */
    resolveAppPath(...segments: string[]): string;
    /**
     * Check if a file exists in either app/ or root (for Nuxt 3/4 compatibility)
     */
    findFile(...segments: string[]): string | null;
    /**
     * Find files matching a pattern
     * @param pattern Glob pattern relative to app/ or root
     * @returns Array of absolute file paths
     */
    findFiles(pattern: string): Promise<string[]>;
    /**
     * Invalidate all caches (useful for file changes)
     */
    invalidateCaches(): void;
}
//# sourceMappingURL=project-manager.d.ts.map