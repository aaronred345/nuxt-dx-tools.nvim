import { CodeAction, CodeActionContext, Range } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';
export declare class CodeActionProvider {
    private projectManager;
    private logger;
    constructor(projectManager: NuxtProjectManager, logger: Logger);
    /**
     * Provide code actions for Nuxt-specific contexts
     */
    provideCodeActions(document: TextDocument, range: Range, context: CodeActionContext): Promise<CodeAction[] | null>;
}
//# sourceMappingURL=code-action-provider.d.ts.map