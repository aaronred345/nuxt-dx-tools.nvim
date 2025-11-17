"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DiagnosticProvider = void 0;
class DiagnosticProvider {
    projectManager;
    logger;
    connection;
    constructor(projectManager, logger, connection) {
        this.projectManager = projectManager;
        this.logger = logger;
        this.connection = connection;
    }
    /**
     * Provide diagnostics for Nuxt-specific issues
     */
    async provideDiagnostics(document) {
        const diagnostics = [];
        // TODO: Implement diagnostics
        // - Check for missing .nuxt directory
        // - Warn about SSR issues in useFetch
        // - Check for deprecated Nuxt 3 patterns
        // - Validate API route paths
        // - Check for missing layouts/middleware
        // Send diagnostics to the client
        this.connection.sendDiagnostics({
            uri: document.uri,
            diagnostics,
        });
    }
}
exports.DiagnosticProvider = DiagnosticProvider;
//# sourceMappingURL=diagnostic-provider.js.map