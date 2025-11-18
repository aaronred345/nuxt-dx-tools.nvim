"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CodeActionProvider = void 0;
class CodeActionProvider {
    projectManager;
    logger;
    constructor(projectManager, logger) {
        this.projectManager = projectManager;
        this.logger = logger;
    }
    /**
     * Provide code actions for Nuxt-specific contexts
     */
    async provideCodeActions(document, range, context) {
        const actions = [];
        // TODO: Implement code actions
        // - Add missing imports
        // - Convert to Nuxt 4 syntax
        // - Optimize data fetching patterns
        // - Fix common issues
        return actions.length > 0 ? actions : null;
    }
}
exports.CodeActionProvider = CodeActionProvider;
//# sourceMappingURL=code-action-provider.js.map