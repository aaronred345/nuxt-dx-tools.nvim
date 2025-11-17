import { Hover, Position } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
export declare class HoverProvider {
    private projectManager;
    private logger;
    constructor(projectManager: NuxtProjectManager, logger: Logger);
    /**
     * Provide hover information for Nuxt-specific symbols
     *
     * Note: No early exit pattern check - each handler determines if it can provide info.
     * This prevents false positives where we match a pattern but can't actually provide hover info.
     */
    provideHover(document: TextDocument, position: Position): Promise<Hover | null>;
    /**
     * Handle virtual module hover
     */
    private handleVirtualModules;
    /**
     * Handle API route hover
     */
    private handleApiRoutes;
    /**
     * Handle page route hover
     */
    private handlePageRoutes;
    /**
     * Handle data fetching hover
     */
    private handleDataFetching;
    /**
     * Handle auto-imported symbols (composables, components)
     */
    private handleAutoImportedSymbols;
    /**
     * Resolve API route path to file (same logic as definition provider)
     */
    private resolveApiRoute;
    /**
     * Resolve page route path to file (same logic as definition provider)
     */
    private resolvePageRoute;
    /**
     * Read the first N lines of a file
     */
    private readFirstLines;
    /**
     * Get the line at the given offset
     */
    private getLine;
    /**
     * Get the word at the given position
     */
    private getWordAtPosition;
}
//# sourceMappingURL=hover-provider.d.ts.map