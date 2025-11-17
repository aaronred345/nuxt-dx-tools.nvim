import { Logger } from './logger';
export interface PathAlias {
    [alias: string]: string;
}
export interface TsConfig {
    compilerOptions?: {
        paths?: {
            [pattern: string]: string[];
        };
        baseUrl?: string;
    };
    references?: Array<{
        path: string;
    }>;
}
export declare class TsConfigParser {
    private cache;
    private logger;
    private rootPath;
    constructor(rootPath: string, logger: Logger);
    /**
     * Remove JSON comments and trailing commas to make it valid JSON
     */
    private cleanJson;
    /**
     * Parse a single tsconfig.json file and extract path mappings
     */
    private parseTsConfigFile;
    /**
     * Extract paths from parsed tsconfig object
     */
    private extractPathsFromTsConfig;
    /**
     * Fallback regex-based parser for when JSON parsing fails
     */
    private parseTsConfigRegex;
    /**
     * Extract references from tsconfig
     */
    private extractReferences;
    /**
     * Load all path mappings from tsconfig and referenced configs
     */
    private loadAllPathMappings;
    /**
     * Get all path aliases (with caching)
     */
    getAliases(): PathAlias;
    /**
     * Resolve an aliased path to an absolute filesystem path
     */
    resolveAliasPath(importPath: string): string | null;
    /**
     * Find a file by resolving its aliased import path
     */
    findFileFromImport(importPath: string): string | null;
    /**
     * Clear the cache
     */
    clearCache(): void;
}
//# sourceMappingURL=tsconfig-parser.d.ts.map