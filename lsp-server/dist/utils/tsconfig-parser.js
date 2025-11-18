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
exports.TsConfigParser = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const cache_1 = require("./cache");
class TsConfigParser {
    cache;
    logger;
    rootPath;
    constructor(rootPath, logger) {
        this.rootPath = rootPath;
        this.logger = logger;
        this.cache = new cache_1.Cache();
    }
    /**
     * Remove JSON comments and trailing commas to make it valid JSON
     */
    cleanJson(content) {
        // Remove single-line comments
        content = content.replace(/\/\/[^\n]*/g, '');
        // Remove multi-line comments
        content = content.replace(/\/\*[\s\S]*?\*\//g, '');
        // Remove trailing commas before closing braces/brackets
        content = content.replace(/,(\s*[}\]])/g, '$1');
        return content;
    }
    /**
     * Parse a single tsconfig.json file and extract path mappings
     */
    parseTsConfigFile(filepath) {
        if (!fs.existsSync(filepath)) {
            return {};
        }
        try {
            const content = fs.readFileSync(filepath, 'utf-8');
            const cleanedContent = this.cleanJson(content);
            try {
                const tsconfig = JSON.parse(cleanedContent);
                return this.extractPathsFromTsConfig(tsconfig, filepath);
            }
            catch (jsonError) {
                // If JSON parsing fails, fall back to regex parsing
                this.logger.debug(`JSON parsing failed for ${filepath}, using regex fallback`);
                return this.parseTsConfigRegex(cleanedContent, filepath);
            }
        }
        catch (error) {
            this.logger.error(`Failed to read tsconfig file ${filepath}: ${error}`);
            return {};
        }
    }
    /**
     * Extract paths from parsed tsconfig object
     */
    extractPathsFromTsConfig(tsconfig, filepath) {
        const paths = {};
        const tsconfigDir = path.dirname(filepath);
        if (tsconfig.compilerOptions?.paths) {
            for (const [aliasPattern, targets] of Object.entries(tsconfig.compilerOptions.paths)) {
                if (Array.isArray(targets) && targets.length > 0) {
                    // Use the first target if multiple are specified
                    const targetPattern = targets[0];
                    // Remove the /* suffix from both alias and target
                    const alias = aliasPattern.replace(/\/\*$/, '');
                    const target = targetPattern.replace(/^\.\//, '').replace(/\/\*$/, '');
                    // Resolve target path relative to tsconfig directory
                    const absoluteTarget = path.resolve(tsconfigDir, target);
                    paths[alias] = absoluteTarget;
                }
            }
        }
        return paths;
    }
    /**
     * Fallback regex-based parser for when JSON parsing fails
     */
    parseTsConfigRegex(content, filepath) {
        const paths = {};
        const tsconfigDir = path.dirname(filepath);
        // Find the "paths" section in compilerOptions
        const pathsMatch = content.match(/"paths"\s*:\s*(\{[^}]*\})/);
        if (!pathsMatch) {
            return {};
        }
        const pathsSection = pathsMatch[1];
        // Extract each path mapping: "alias/*": ["target/*", ...]
        const aliasPattern = /"([^"]+)"\s*:\s*(\[[^\]]*\])/g;
        let match;
        while ((match = aliasPattern.exec(pathsSection)) !== null) {
            const alias = match[1];
            const targetsArray = match[2];
            // Extract the first target from the array
            const targetMatch = targetsArray.match(/\[\s*"([^"]+)"/);
            if (targetMatch) {
                const targetPattern = targetMatch[1];
                // Remove the /* suffix from both alias and target
                const cleanAlias = alias.replace(/\/\*$/, '');
                const cleanTarget = targetPattern.replace(/^\.\//, '').replace(/\/\*$/, '');
                // Resolve target path relative to tsconfig directory
                const absoluteTarget = path.resolve(tsconfigDir, cleanTarget);
                paths[cleanAlias] = absoluteTarget;
            }
        }
        return paths;
    }
    /**
     * Extract references from tsconfig
     */
    extractReferences(content) {
        const cleanedContent = this.cleanJson(content);
        const references = [];
        try {
            const tsconfig = JSON.parse(cleanedContent);
            if (tsconfig.references) {
                for (const ref of tsconfig.references) {
                    if (ref.path) {
                        references.push(ref.path);
                    }
                }
            }
        }
        catch {
            // Fallback: Extract references using regex
            const referencesMatch = cleanedContent.match(/"references"\s*:\s*(\[[^\]]*\])/);
            if (referencesMatch) {
                const referencesSection = referencesMatch[1];
                const pathPattern = /"path"\s*:\s*"([^"]+)"/g;
                let match;
                while ((match = pathPattern.exec(referencesSection)) !== null) {
                    references.push(match[1]);
                }
            }
        }
        return references;
    }
    /**
     * Load all path mappings from tsconfig and referenced configs
     */
    loadAllPathMappings() {
        const mainTsConfig = path.join(this.rootPath, 'tsconfig.json');
        if (!fs.existsSync(mainTsConfig)) {
            this.logger.warn(`No tsconfig.json found at ${mainTsConfig}`);
            return {};
        }
        const allPaths = {};
        // Read and parse main tsconfig
        const content = fs.readFileSync(mainTsConfig, 'utf-8');
        const references = this.extractReferences(content);
        // Add Nuxt-specific tsconfig files if not already in references
        const nuxtTsConfigs = [
            '.nuxt/tsconfig.json',
            '.nuxt/tsconfig.app.json',
            '.nuxt/tsconfig.server.json',
            '.nuxt/tsconfig.shared.json',
            '.nuxt/tsconfig.node.json',
        ];
        for (const configPath of nuxtTsConfigs) {
            if (!references.includes(configPath)) {
                references.push(configPath);
            }
        }
        // Parse each referenced tsconfig file
        for (const refPath of references) {
            const fullPath = path.join(this.rootPath, refPath);
            const paths = this.parseTsConfigFile(fullPath);
            // Merge paths
            Object.assign(allPaths, paths);
        }
        // Also parse the main tsconfig itself
        const mainPaths = this.parseTsConfigFile(mainTsConfig);
        Object.assign(allPaths, mainPaths);
        this.logger.debug(`Loaded ${Object.keys(allPaths).length} path aliases from tsconfig`);
        return allPaths;
    }
    /**
     * Get all path aliases (with caching)
     */
    getAliases() {
        const cached = this.cache.get('aliases');
        if (cached) {
            return cached;
        }
        const aliases = this.loadAllPathMappings();
        // Log all loaded aliases for debugging
        this.logger.info(`[TsConfig] Loaded ${Object.keys(aliases).length} path aliases from tsconfig:`);
        for (const [alias, target] of Object.entries(aliases)) {
            this.logger.info(`[TsConfig]   "${alias}" -> "${target}"`);
        }
        this.cache.set('aliases', aliases, 10000); // 10 second TTL
        return aliases;
    }
    /**
     * Resolve an aliased path to an absolute filesystem path
     */
    resolveAliasPath(importPath) {
        const aliases = this.getAliases();
        // Check each alias to see if it matches the import path
        for (const [alias, target] of Object.entries(aliases)) {
            if (importPath.startsWith(alias)) {
                // Replace the alias with the target path
                const resolved = importPath.replace(alias, target);
                return resolved;
            }
        }
        return null;
    }
    /**
     * Find a file by resolving its aliased import path
     */
    findFileFromImport(importPath) {
        const resolvedPath = this.resolveAliasPath(importPath);
        if (!resolvedPath) {
            return null;
        }
        // Check if the path already has an extension
        const hasExtension = /\.[^/\\]+$/.test(importPath);
        // If it has an extension, try it directly first
        if (hasExtension && fs.existsSync(resolvedPath)) {
            return resolvedPath;
        }
        // Try different file extensions (code, styles, and assets)
        const extensions = [
            '.vue', '.ts', '.js', '.mjs', '.tsx', '.jsx',
            '.css', '.pcss', '.scss', '.sass', '.less', '.styl'
        ];
        for (const ext of extensions) {
            const fullPath = resolvedPath + ext;
            if (fs.existsSync(fullPath)) {
                return fullPath;
            }
        }
        // Try index files for directories
        for (const ext of extensions) {
            const indexPath = path.join(resolvedPath, `index${ext}`);
            if (fs.existsSync(indexPath)) {
                return indexPath;
            }
        }
        return null;
    }
    /**
     * Clear the cache
     */
    clearCache() {
        this.cache.clear();
    }
}
exports.TsConfigParser = TsConfigParser;
//# sourceMappingURL=tsconfig-parser.js.map