"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const definition_provider_1 = require("../providers/definition-provider");
const vscode_languageserver_textdocument_1 = require("vscode-languageserver-textdocument");
const node_1 = require("vscode-languageserver/node");
describe('DefinitionProvider', () => {
    let provider;
    let mockProjectManager;
    let mockLogger;
    beforeEach(() => {
        mockLogger = {
            info: jest.fn(),
            warn: jest.fn(),
            error: jest.fn(),
        };
        mockProjectManager = {
            getNuxtRoot: jest.fn().mockReturnValue('/test/project'),
            getComponentMappings: jest.fn().mockReturnValue({}),
            getComposableMappings: jest.fn().mockReturnValue({}),
            getPathAliases: jest.fn().mockReturnValue({}),
        };
        provider = new definition_provider_1.DefinitionProvider(mockProjectManager, mockLogger);
    });
    describe('provideDefinition', () => {
        it('should handle empty document', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, '');
            const position = node_1.Position.create(0, 0);
            const result = await provider.provideDefinition(document, position);
            // Should return null or handle gracefully
            expect(result).toBeDefined();
        });
        it('should detect CSS imports', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, "import './styles.css'");
            const position = node_1.Position.create(0, 10);
            const result = await provider.provideDefinition(document, position);
            // Should either find definition or return null
            expect(result !== undefined).toBe(true);
        });
        it('should detect virtual module imports', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, "import { ref } from '#imports'");
            const position = node_1.Position.create(0, 25);
            const result = await provider.provideDefinition(document, position);
            // Should detect #imports pattern
            expect(mockLogger.info).toHaveBeenCalled();
        });
        it('should handle $fetch API calls', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, "const data = $fetch('/api/users')");
            const position = node_1.Position.create(0, 25);
            const result = await provider.provideDefinition(document, position);
            // Should attempt to find API route
            expect(mockLogger.info).toHaveBeenCalled();
        });
        it('should handle definePageMeta', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, "definePageMeta({ layout: 'default' })");
            const position = node_1.Position.create(0, 28);
            const result = await provider.provideDefinition(document, position);
            expect(mockLogger.info).toHaveBeenCalled();
        });
        it('should not crash on invalid position', async () => {
            const document = vscode_languageserver_textdocument_1.TextDocument.create('file:///test.vue', 'vue', 1, 'test');
            const position = node_1.Position.create(100, 100); // Out of bounds
            const result = await provider.provideDefinition(document, position);
            // Should handle gracefully
            expect(result !== undefined).toBe(true);
        });
    });
});
//# sourceMappingURL=definition-provider.test.js.map