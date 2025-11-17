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
}
//# sourceMappingURL=diagnostic-provider.d.ts.map