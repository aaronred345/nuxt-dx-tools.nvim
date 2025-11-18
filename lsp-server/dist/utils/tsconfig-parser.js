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
        // Use a library like strip-json-comments would be ideal, but we'll do a simple approach
        // Split into lines and remove comment lines
        const lines = content.split('\n');
        const cleanedLines = lines.map(line => {
            // Remove single-line comments, but only if they're not inside a string
            // Simple heuristic: if the line has an opening quote before //, keep it
            const commentIndex = line.indexOf('//');
            if (commentIndex !== -1) {
                // Count quotes before the comment
                const beforeComment = line.substring(0, commentIndex);
                const quoteCount = (beforeComment.match(/"/g) || []).length;
                // If odd number of quotes, the // is inside a string
                if (quoteCount % 2 === 0) {
                    // Even quotes or no quotes: the // is a comment
                    line = line.substring(0, commentIndex);
                }
            }
            return line;
        });
        content = cleanedLines.join('\n');
        // Remove multi-line comments
        content = content.replace(/\/\*[\s\S]*?\*\//g, '');
        // Remove trailing commas before closing braces/brackets (global, multiline)
        content = content.replace(/,(\s*[}\]])/gm, '$1');
        return content;
    }
    /**
     * Parse a single tsconfig.json file and extract path mappings
     */
    parseTsConfigFile(filepath) {
        if (!fs.existsSync(filepath)) {
            this.logger.info(`[TsConfig:Parse] File does not exist: ${filepath}`);
            return {};
        }
        this.logger.info(`[TsConfig:Parse] Reading file: ${filepath}`);
        try {
            const content = fs.readFileSync(filepath, 'utf-8');
            const cleanedContent = this.cleanJson(content);
            try {
                const tsconfig = JSON.parse(cleanedContent);
                const paths = this.extractPathsFromTsConfig(tsconfig, filepath);
                this.logger.info(`[TsConfig:Parse] Extracted ${Object.keys(paths).length} aliases from ${filepath}`);
                return paths;
            }
            catch (jsonError) {
                // If JSON parsing fails, fall back to regex parsing
                this.logger.info(`[TsConfig:Parse] JSON parsing failed for ${filepath}: ${jsonError}`);
                if (filepath.includes('.nuxt')) {
                    this.logger.info(`[TsConfig:Parse] Cleaned content length: ${cleanedContent.length}`);
                    // Show content around position 1083 where the error occurs
                    const errorPos = 1083;
                    const snippet = cleanedContent.substring(Math.max(0, errorPos - 200), Math.min(cleanedContent.length, errorPos + 100));
                    this.logger.info(`[TsConfig:Parse] Content around position ${errorPos} (200 chars before): ${snippet}`);
                    // Also show lines around the error
                    const lines = cleanedContent.split('\n');
                    let charCount = 0;
                    let lineNum = 0;
                    for (let i = 0; i < lines.length; i++) {
                        charCount += lines[i].length + 1; // +1 for newline
                        if (charCount >= errorPos) {
                            lineNum = i + 1;
                            break;
                        }
                    }
                    this.logger.info(`[TsConfig:Parse] Error at line ${lineNum}: "${lines[lineNum - 1]}"`);
                    if (lineNum > 1)
                        this.logger.info(`[TsConfig:Parse] Previous line ${lineNum - 1}: "${lines[lineNum - 2]}"`);
                }
                const paths = this.parseTsConfigRegex(cleanedContent, filepath);
                this.logger.info(`[TsConfig:Parse] Regex extracted ${Object.keys(paths).length} aliases from ${filepath}`);
                return paths;
            }
        }
        catch (error) {
            this.logger.error(`[TsConfig:Parse] Failed to read tsconfig file ${filepath}: ${error}`);
            return {};
        }
    }
    /**
     * Extract paths from parsed tsconfig object
     */
    extractPathsFromTsConfig(tsconfig, filepath) {
        const paths = {};
        // In Nuxt, paths in .nuxt/tsconfig.*.json use ../ to navigate back to project root
        // We strip the ../ prefix and resolve from project root
        const baseDir = this.rootPath;
        if (tsconfig.compilerOptions?.paths) {
            for (const [aliasPattern, targets] of Object.entries(tsconfig.compilerOptions.paths)) {
                if (Array.isArray(targets) && targets.length > 0) {
                    // Use the first target if multiple are specified
                    const targetPattern = targets[0];
                    // Remove the /* suffix from alias and target
                    // Also remove leading ./ and ../ from target
                    const alias = aliasPattern.replace(/\/\*$/, '');
                    let target = targetPattern.replace(/\/\*$/, '');
                    // Strip leading ../ or ./ to resolve from project root
                    target = target.replace(/^(?:\.\.\/)+/, '').replace(/^\.\//, '');
                    // Handle special case of ".." which becomes empty string
                    if (targetPattern === '..' || targetPattern === '../') {
                        target = '';
                    }
                    // Resolve target path relative to project root
                    const absoluteTarget = path.resolve(baseDir, target);
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
        // In Nuxt, paths use ../ to navigate back to project root
        const baseDir = this.rootPath;
        // Find the start of the "paths" section
        const pathsStartMatch = content.match(/"paths"\s*:\s*\{/);
        if (!pathsStartMatch) {
            return {};
        }
        // Find the entire paths object by counting braces
        const startIndex = pathsStartMatch.index + pathsStartMatch[0].length - 1; // Position of opening {
        let braceCount = 0;
        let endIndex = startIndex;
        for (let i = startIndex; i < content.length; i++) {
            if (content[i] === '{')
                braceCount++;
            if (content[i] === '}')
                braceCount--;
            if (braceCount === 0) {
                endIndex = i;
                break;
            }
        }
        const pathsSection = content.substring(startIndex, endIndex + 1);
        // For all .nuxt tsconfig files, check if ~~ is in the raw content
        if (filepath.includes('.nuxt')) {
            const hasDoubleTilde = pathsSection.includes('"~~"');
            const filename = path.basename(filepath);
            this.logger.info(`[TsConfig:Regex:DEBUG] ${filename} - paths section contains "~~": ${hasDoubleTilde}`);
            if (hasDoubleTilde) {
                // Log the section around ~~
                const tildeIndex = pathsSection.indexOf('"~~"');
                const snippet = pathsSection.substring(Math.max(0, tildeIndex - 50), Math.min(pathsSection.length, tildeIndex + 150));
                this.logger.info(`[TsConfig:Regex:DEBUG] ${filename} - Snippet around ~~: ${snippet}`);
            }
        }
        // Extract each path mapping: "alias/*": ["target/*", ...]
        // Use [\s\S] instead of . to match newlines, and [^\]]* to match array contents
        const aliasPattern = /"([^"]+)"\s*:\s*\[([\s\S]*?)\]/g;
        let match;
        while ((match = aliasPattern.exec(pathsSection)) !== null) {
            const alias = match[1];
            const targetsArray = match[2];
            // Log all matches for .nuxt tsconfig files
            if (filepath.includes('.nuxt')) {
                const filename = path.basename(filepath);
                this.logger.info(`[TsConfig:Regex:DEBUG] ${filename} - Match found - alias: "${alias}", targetsArray: "${targetsArray.substring(0, 100)}"`);
            }
            // Extract the first target from the array
            const targetMatch = targetsArray.match(/"([^"]+)"/);
            if (targetMatch) {
                const targetPattern = targetMatch[1];
                // Remove the /* suffix from both alias and target
                const cleanAlias = alias.replace(/\/\*$/, '');
                let cleanTarget = targetPattern.replace(/\/\*$/, '');
                // Strip leading ../ or ./ to resolve from project root
                cleanTarget = cleanTarget.replace(/^(?:\.\.\/)+/, '').replace(/^\.\//, '');
                // Handle special case of ".." which becomes empty string
                if (targetPattern === '..' || targetPattern === '../') {
                    cleanTarget = '';
                }
                // Resolve target path relative to project root
                const absoluteTarget = path.resolve(baseDir, cleanTarget);
                this.logger.info(`[TsConfig:Regex] Extracted alias: "${cleanAlias}" -> "${absoluteTarget}"`);
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
        // Nuxt fallback: if ~~ is not in tsconfig but ~ is, add ~~ pointing to the same location
        // This handles cases where Nuxt's generated tsconfig is missing the ~~ alias
        if (!aliases['~~'] && aliases['~']) {
            aliases['~~'] = aliases['~'];
            this.logger.info(`[TsConfig:Resolve] Added fallback: "~~" -> "${aliases['~']}"`);
        }
        // Similarly for @@ alias
        if (!aliases['@@'] && aliases['@']) {
            aliases['@@'] = aliases['@'];
            this.logger.info(`[TsConfig:Resolve] Added fallback: "@@" -> "${aliases['@']}"`);
        }
        // Sort aliases by length (descending) to match longer aliases first
        // This prevents "~" from matching before "~~", "@" before "@@", etc.
        const sortedAliases = Object.entries(aliases).sort((a, b) => b[0].length - a[0].length);
        // Check each alias to see if it matches the import path
        for (const [alias, target] of sortedAliases) {
            if (importPath.startsWith(alias)) {
                // Replace the alias prefix with the target path
                // Use slice instead of replace to avoid issues with partial matches
                // For example: "~~/foo" with alias "~" should not become "<target>~/foo"
                const resolved = target + importPath.slice(alias.length);
                this.logger.info(`[TsConfig:Resolve] Matched alias "${alias}" in "${importPath}" -> "${resolved}"`);
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