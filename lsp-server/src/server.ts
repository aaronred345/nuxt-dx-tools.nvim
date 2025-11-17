#!/usr/bin/env node

import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  TextDocumentSyncKind,
  InitializeResult,
  CompletionItem,
  CompletionParams,
  DefinitionParams,
  HoverParams,
  CodeActionParams,
  SignatureHelpParams,
} from 'vscode-languageserver/node';

import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from './nuxt/project-manager';
import { DefinitionProvider } from './providers/definition-provider';
import { HoverProvider } from './providers/hover-provider';
import { CompletionProvider } from './providers/completion-provider';
import { CodeActionProvider } from './providers/code-action-provider';
import { DiagnosticProvider } from './providers/diagnostic-provider';
import { Logger } from './utils/logger';

// Create a connection for the server using Node's IPC as a transport
const connection = createConnection(ProposedFeatures.all);

// Create a text document manager
const documents = new TextDocuments(TextDocument);

// Initialize logger
const logger = new Logger(connection);

// Project manager - handles all Nuxt-specific logic
let projectManager: NuxtProjectManager;

// Providers
let definitionProvider: DefinitionProvider;
let hoverProvider: HoverProvider;
let completionProvider: CompletionProvider;
let codeActionProvider: CodeActionProvider;
let diagnosticProvider: DiagnosticProvider;

connection.onInitialize((params: InitializeParams): InitializeResult => {
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
  projectManager = new NuxtProjectManager(rootUri, logger);

  // Initialize providers
  definitionProvider = new DefinitionProvider(projectManager, logger);
  hoverProvider = new HoverProvider(projectManager, logger);
  completionProvider = new CompletionProvider(projectManager, logger);
  codeActionProvider = new CodeActionProvider(projectManager, logger);
  diagnosticProvider = new DiagnosticProvider(projectManager, logger, connection);

  const result: InitializeResult = {
    capabilities: {
      // Only sync document open/close/save, not every change
      textDocumentSync: {
        openClose: true,
        change: TextDocumentSyncKind.None,
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
connection.onDefinition(async (params: DefinitionParams) => {
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
  } catch (error) {
    logger.error(`Error in onDefinition: ${error}`);
    return null;
  }
});

// Handle hover requests
connection.onHover(async (params: HoverParams) => {
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
  } catch (error) {
    logger.error(`Error in onHover: ${error}`);
    return null;
  }
});

// Handle completion requests
connection.onCompletion(async (params: CompletionParams) => {
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
  } catch (error) {
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
