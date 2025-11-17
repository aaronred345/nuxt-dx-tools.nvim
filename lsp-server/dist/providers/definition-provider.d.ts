import { Location, Position } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
export declare class DefinitionProvider {
    private projectManager;
    private logger;
    constructor(projectManager: NuxtProjectManager, logger: Logger);
    /**
     * Provide goto definition for Nuxt-specific symbols
     *
     * Note: No early exit pattern check - each handler determines if it can provide a definition.
     * This prevents false positives where we match a pattern but can't actually provide a definition.
     */
    provideDefinition(document: TextDocument, position: Position): Promise<Location | Location[] | null>;
    /**
     * Handle import statements with path aliases
     * import MyComponent from '~/components/MyComponent.vue'
     * import { helper } from '@/utils/helpers'
     * import './styles.css'
     */
    private handleImportStatement;
    /**
     * Handle virtual module imports (#imports, #app, #build, etc.)
     */
    private handleVirtualModules;
    /**
     * Handle definePageMeta context (layout, middleware)
     */
    private handleDefinePageMeta;
    /**
     * Handle page routes (navigateTo, NuxtLink, router.push)
     */
    private handlePageRoutes;
    /**
     * Resolve a route path to a page file
     * /about -> pages/about.vue
     * /users/:id -> pages/users/[id].vue
     */
    private resolvePageRoute;
    /**
     * Handle API routes ($fetch, useFetch, useAsyncData)
     */
    private handleApiRoutes;
    /**
     * Resolve an API route path to a handler file
     * /api/users -> server/api/users.ts or server/api/users/index.ts
     */
    private resolveApiRoute;
    /**
     * Handle components and composables
     */
    private handleComponents;
    /**
     * Handle custom plugin definitions (e.g., $dialog, $myPlugin)
     */
    private handleCustomPlugins;
    /**
     * Get the line at the given offset
     */
    private getLine;
    /**
     * Get the word at the given position
     */
    private getWordAtPosition;
    /**
     * Get the string literal at the given position
     * Handles both single and double quoted strings
     */
    private getStringAtPosition;
}
//# sourceMappingURL=definition-provider.d.ts.map