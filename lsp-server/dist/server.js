#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const node_1 = require("vscode-languageserver/node");
const vscode_languageserver_textdocument_1 = require("vscode-languageserver-textdocument");
const project_manager_1 = require("./nuxt/project-manager");
const definition_provider_1 = require("./providers/definition-provider");
const hover_provider_1 = require("./providers/hover-provider");
const completion_provider_1 = require("./providers/completion-provider");
const code_action_provider_1 = require("./providers/code-action-provider");
const diagnostic_provider_1 = require("./providers/diagnostic-provider");
const logger_1 = require("./utils/logger");
// Create a connection for the server using Node's IPC as a transport
const connection = (0, node_1.createConnection)(node_1.ProposedFeatures.all);
// Create a text document manager
const documents = new node_1.TextDocuments(vscode_languageserver_textdocument_1.TextDocument);
// Initialize logger
const logger = new logger_1.Logger(connection);
// Project manager - handles all Nuxt-specific logic
let projectManager;
// Providers
let definitionProvider;
let hoverProvider;
let completionProvider;
let codeActionProvider;
let diagnosticProvider;
connection.onInitialize((params) => {
    const workspaceFolders = params.workspaceFolders;
    const rootUri = workspaceFolders?.[0]?.uri || params.rootUri || '';
    // Get init options (capability toggles from client)
    const initOptions = params.initializationOptions || {};
    const enableHover = initOptions.enableHover === true; // Default false to avoid "No information available" with multiple servers
    const enableDefinition = initOptions.enableDefinition !== false; // Default true
    const enableCompletion = initOptions.enableCompletion !== false; // Default true
    logger.info(`Initializing Nuxt DX Tools LSP Server for workspace: ${rootUri}`);
    logger.info(`Capabilities: hover=${enableHover}, definition=${enableDefinition}, completion=${enableCompletion}`);
    // Initialize project manager
    projectManager = new project_manager_1.NuxtProjectManager(rootUri, logger);
    // Initialize providers
    definitionProvider = new definition_provider_1.DefinitionProvider(projectManager, logger);
    hoverProvider = new hover_provider_1.HoverProvider(projectManager, logger);
    completionProvider = new completion_provider_1.CompletionProvider(projectManager, logger);
    codeActionProvider = new code_action_provider_1.CodeActionProvider(projectManager, logger);
    diagnosticProvider = new diagnostic_provider_1.DiagnosticProvider(projectManager, logger, connection);
    const result = {
        capabilities: {
            // Only sync document open/close/save, not every change
            textDocumentSync: {
                openClose: true,
                change: node_1.TextDocumentSyncKind.None,
                save: true,
            },
            // ONLY provide capabilities for Nuxt-specific features
            // Return undefined (not implemented) for everything else so other servers handle it
            // Capabilities can be disabled via init_options to avoid conflicts with other servers
            definitionProvider: enableDefinition ? true : undefined,
            hoverProvider: enableHover ? true : undefined,
            completionProvider: enableCompletion
                ? {
                    resolveProvider: false,
                    // Only trigger on Nuxt-specific characters
                    triggerCharacters: ['/', '@', '~', '#'],
                }
                : undefined,
            // Workspace capabilities
            workspace: {
                workspaceFolders: {
                    supported: true,
                },
            },
        },
    };
    return result;
});
connection.onInitialized(() => {
    logger.info('Nuxt DX Tools LSP Server initialized successfully');
    // Start initial scan of the project
    projectManager.initialize().catch((err) => {
        logger.error(`Failed to initialize project: ${err}`);
    });
});
// Handle goto definition requests
connection.onDefinition(async (params) => {
    try {
        const document = documents.get(params.textDocument.uri);
        if (!document) {
            return null;
        }
        const result = await definitionProvider.provideDefinition(document, params.position);
        // Only log when we actually provide something (not null)
        if (result) {
            logger.debug(`[Definition] Provided Nuxt-specific result`);
        }
        return result;
    }
    catch (error) {
        logger.error(`Error in onDefinition: ${error}`);
        return null;
    }
});
// Handle hover requests
connection.onHover(async (params) => {
    try {
        const document = documents.get(params.textDocument.uri);
        if (!document) {
            return null;
        }
        const result = await hoverProvider.provideHover(document, params.position);
        // Only log when we actually provide something (not null)
        if (result) {
            logger.debug(`[Hover] Provided Nuxt-specific result`);
        }
        return result;
    }
    catch (error) {
        logger.error(`Error in onHover: ${error}`);
        return null;
    }
});
// Handle completion requests
connection.onCompletion(async (params) => {
    try {
        const document = documents.get(params.textDocument.uri);
        if (!document) {
            return null;
        }
        const result = await completionProvider.provideCompletion(document, params.position);
        // Only log when we actually provide results
        if (result && result.length > 0) {
            logger.debug(`[Completion] Provided ${result.length} Nuxt-specific items`);
        }
        return result;
    }
    catch (error) {
        logger.error(`Error in onCompletion: ${error}`);
        return null;
    }
});
// NOTE: We deliberately DON'T handle:
// - codeAction (let other servers handle refactoring, quick fixes)
// - signatureHelp (let TypeScript server handle this)
// Validate Nuxt-specific imports on document open and change
documents.onDidOpen(async (event) => {
    await diagnosticProvider.provideDiagnostics(event.document);
});
documents.onDidChangeContent(async (event) => {
    // Debounce diagnostics to avoid running on every keystroke
    // Only run diagnostics on save or after a delay
});
documents.onDidSave(async (event) => {
    await diagnosticProvider.provideDiagnostics(event.document);
});
// Make the text document manager listen on the connection
documents.listen(connection);
// Listen on the connection
connection.listen();
logger.info('Nuxt DX Tools LSP Server is now listening for connections');
//# sourceMappingURL=server.js.map