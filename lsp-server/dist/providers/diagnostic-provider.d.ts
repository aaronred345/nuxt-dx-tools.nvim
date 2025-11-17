import { Connection } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
export declare class DiagnosticProvider {
    private projectManager;
    private logger;
    private connection;
    constructor(projectManager: NuxtProjectManager, logger: Logger, connection: Connection);
    /**
     * Provide diagnostics for Nuxt-specific issues
     */
    provideDiagnostics(document: TextDocument): Promise<void>;
    /**
     * Validate imports with Nuxt path aliases (~~/, ~/, @/)
     */
    private validatePathAliasImports;
    /**
     * Validate that imported symbols are actually exported from the file
     */
    private validateExports;
    /**
     * Check if the .nuxt directory exists
     */
    private checkNuxtDirectory;
    /**
     * Parse import statements from the document
     */
    private parseImports;
    /**
     * Check if an import path uses Nuxt path aliases
     */
    private isNuxtPathAlias;
}
//# sourceMappingURL=diagnostic-provider.d.ts.map