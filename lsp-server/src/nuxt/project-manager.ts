import * as fs from 'fs';
import * as path from 'path';
import { URI } from 'vscode-uri';
import { Logger } from '../utils/logger';
import { TsConfigParser } from '../utils/tsconfig-parser';
import { TypeParser } from '../utils/type-parser';

export interface NuxtStructure {
  hasAppDir: boolean;
  hasNuxtDir: boolean;
  isNuxt4: boolean;
  rootPath: string;
  appPath: string; // Either 'app/' or './' depending on Nuxt version
}

export class NuxtProjectManager {
  private rootPath: string;
  private logger: Logger;
  private tsConfigParser: TsConfigParser;
  private typeParser: TypeParser;
  private structure: NuxtStructure | null = null;

  constructor(rootUri: string, logger: Logger) {
    this.rootPath = URI.parse(rootUri).fsPath;
    this.logger = logger;
    this.tsConfigParser = new TsConfigParser(this.rootPath, logger);
    this.typeParser = new TypeParser(this.rootPath, logger);
  }

  /**
   * Initialize the project manager
   */
  async initialize(): Promise<void> {
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
  private detectNuxtStructure(): NuxtStructure {
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
  getStructure(): NuxtStructure {
    if (!this.structure) {
      this.structure = this.detectNuxtStructure();
    }
    return this.structure;
  }

  /**
   * Get the tsconfig parser
   */
  getTsConfigParser(): TsConfigParser {
    return this.tsConfigParser;
  }

  /**
   * Get the type parser
   */
  getTypeParser(): TypeParser {
    return this.typeParser;
  }

  /**
   * Get the root path
   */
  getRootPath(): string {
    return this.rootPath;
  }

  /**
   * Get the app path (with trailing slash)
   */
  getAppPath(): string {
    return this.getStructure().appPath;
  }

  /**
   * Resolve a path relative to the app directory
   * @param relativePath Path relative to app/ or root
   * @returns Absolute path
   */
  resolveAppPath(...segments: string[]): string {
    const structure = this.getStructure();
    const base = structure.isNuxt4 ? path.join(this.rootPath, 'app') : this.rootPath;
    return path.join(base, ...segments);
  }

  /**
   * Check if a file exists in either app/ or root (for Nuxt 3/4 compatibility)
   */
  findFile(...segments: string[]): string | null {
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
  async findFiles(pattern: string): Promise<string[]> {
    const fg = await import('fast-glob');
    const structure = this.getStructure();

    const results: string[] = [];

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
  invalidateCaches(): void {
    this.tsConfigParser.clearCache();
    this.typeParser.clearCache();
    this.logger.debug('All caches invalidated');
  }
}
