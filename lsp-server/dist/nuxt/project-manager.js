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
exports.NuxtProjectManager = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const vscode_uri_1 = require("vscode-uri");
const tsconfig_parser_1 = require("../utils/tsconfig-parser");
const type_parser_1 = require("../utils/type-parser");
class NuxtProjectManager {
    rootPath;
    logger;
    tsConfigParser;
    typeParser;
    structure = null;
    constructor(rootUri, logger) {
        this.rootPath = vscode_uri_1.URI.parse(rootUri).fsPath;
        this.logger = logger;
        this.tsConfigParser = new tsconfig_parser_1.TsConfigParser(this.rootPath, logger);
        this.typeParser = new type_parser_1.TypeParser(this.rootPath, logger);
    }
    /**
     * Initialize the project manager
     */
    async initialize() {
        this.logger.info(`Initializing Nuxt project at: ${this.rootPath}`);
        // Detect Nuxt structure
        this.structure = this.detectNuxtStructure();
        if (!this.structure.hasNuxtDir) {
            this.logger.warn('No .nuxt directory found. Project may not be built yet.');
            this.logger.warn('Run `nuxt dev` or `nuxt build` to generate type definitions.');
        }
        // Initial parse of tsconfig and types
        this.tsConfigParser.getAliases();
        this.typeParser.getImports();
        this.typeParser.getComponents();
        this.logger.info('Nuxt project initialized successfully');
    }
    /**
     * Detect Nuxt project structure (Nuxt 3 vs Nuxt 4)
     */
    detectNuxtStructure() {
        const appDir = path.join(this.rootPath, 'app');
        const nuxtDir = path.join(this.rootPath, '.nuxt');
        const hasAppDir = fs.existsSync(appDir) && fs.statSync(appDir).isDirectory();
        const hasNuxtDir = fs.existsSync(nuxtDir) && fs.statSync(nuxtDir).isDirectory();
        // Nuxt 4 uses 'app/' directory, Nuxt 3 uses root directory
        const isNuxt4 = hasAppDir;
        const appPath = isNuxt4 ? 'app/' : './';
        this.logger.info(`Detected Nuxt ${isNuxt4 ? '4' : '3'} structure`);
        this.logger.info(`App directory: ${appPath}`);
        return {
            hasAppDir,
            hasNuxtDir,
            isNuxt4,
            rootPath: this.rootPath,
            appPath,
        };
    }
    /**
     * Get the Nuxt project structure
     */
    getStructure() {
        if (!this.structure) {
            this.structure = this.detectNuxtStructure();
        }
        return this.structure;
    }
    /**
     * Get the tsconfig parser
     */
    getTsConfigParser() {
        return this.tsConfigParser;
    }
    /**
     * Get the type parser
     */
    getTypeParser() {
        return this.typeParser;
    }
    /**
     * Get the root path
     */
    getRootPath() {
        return this.rootPath;
    }
    /**
     * Get the app path (with trailing slash)
     */
    getAppPath() {
        return this.getStructure().appPath;
    }
    /**
     * Resolve a path relative to the app directory
     * @param relativePath Path relative to app/ or root
     * @returns Absolute path
     */
    resolveAppPath(...segments) {
        const structure = this.getStructure();
        const base = structure.isNuxt4 ? path.join(this.rootPath, 'app') : this.rootPath;
        return path.join(base, ...segments);
    }
    /**
     * Check if a file exists in either app/ or root (for Nuxt 3/4 compatibility)
     */
    findFile(...segments) {
        const structure = this.getStructure();
        // Try app/ directory first (Nuxt 4)
        if (structure.hasAppDir) {
            const appPath = path.join(this.rootPath, 'app', ...segments);
            if (fs.existsSync(appPath)) {
                return appPath;
            }
        }
        // Try root directory (Nuxt 3)
        const rootPath = path.join(this.rootPath, ...segments);
        if (fs.existsSync(rootPath)) {
            return rootPath;
        }
        return null;
    }
    /**
     * Find files matching a pattern
     * @param pattern Glob pattern relative to app/ or root
     * @returns Array of absolute file paths
     */
    async findFiles(pattern) {
        const fg = await Promise.resolve().then(() => __importStar(require('fast-glob')));
        const structure = this.getStructure();
        const results = [];
        // Search in app/ directory (Nuxt 4)
        if (structure.hasAppDir) {
            const appResults = await fg.default(pattern, {
                cwd: path.join(this.rootPath, 'app'),
                absolute: true,
            });
            results.push(...appResults);
        }
        // Search in root directory (Nuxt 3)
        const rootResults = await fg.default(pattern, {
            cwd: this.rootPath,
            absolute: true,
            ignore: ['node_modules/**', '.nuxt/**', '.output/**'],
        });
        // Avoid duplicates
        for (const result of rootResults) {
            if (!results.includes(result)) {
                results.push(result);
            }
        }
        return results;
    }
    /**
     * Invalidate all caches (useful for file changes)
     */
    invalidateCaches() {
        this.tsConfigParser.clearCache();
        this.typeParser.clearCache();
        this.logger.debug('All caches invalidated');
    }
}
exports.NuxtProjectManager = NuxtProjectManager;
//# sourceMappingURL=project-manager.js.map