import { Connection, Diagnostic, DiagnosticSeverity } from 'vscode-languageserver/node';
import { TextDocument } from 'vscode-languageserver-textdocument';
import { NuxtProjectManager } from '../nuxt/project-manager';
import { Logger } from '../utils/logger';

export class DiagnosticProvider {
  constructor(
    private projectManager: NuxtProjectManager,
    private logger: Logger,
    private connection: Connection
  ) {}

  /**
   * Provide diagnostics for Nuxt-specific issues
   */
  async provideDiagnostics(document: TextDocument): Promise<void> {
    const diagnostics: Diagnostic[] = [];

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
