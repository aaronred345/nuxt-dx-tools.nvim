import { CompletionItem, Position } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
export declare class CompletionProvider {
    private projectManager;
    private logger;
    constructor(projectManager: NuxtProjectManager, logger: Logger);
    /**
     * Check if this looks like a Nuxt-specific completion context
     */
    private isLikelyNuxtContext;
    /**
     * Provide completions for Nuxt-specific contexts
     */
    provideCompletion(document: TextDocument, position: Position): Promise<CompletionItem[] | null>;
    /**
     * Check if cursor is in a Nuxt-specific import statement
     */
    private isInImportStatement;
    /**
     * Provide completions for import paths
     */
    private provideImportCompletions;
    /**
     * Get directory/file completions for a given path
     */
    private getDirectoryCompletions;
    /**
     * Check if cursor is in definePageMeta
     */
    private isInDefinePageMeta;
    /**
     * Provide completions for definePageMeta
     */
    private providePageMetaCompletions;
    /**
     * Get layout completions
     */
    private getLayoutCompletions;
    /**
     * Get middleware completions
     */
    private getMiddlewareCompletions;
    /**
     * Provide component completions
     */
    private provideComponentCompletions;
    /**
     * Get the line at the given offset
     */
    private getLine;
}
//# sourceMappingURL=completion-provider.d.ts.map