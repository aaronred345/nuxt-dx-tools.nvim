import { Connection, MessageType } from 'vscode-languageserver/node';
import * as fs from 'fs';
import * as path from 'path';

export class Logger {
  private debugMode = false;
  private logFilePath: string;

  constructor(private connection: Connection) {
    // Create log file path in the lsp-server directory
    this.logFilePath = path.join(__dirname, '../../server-debug.log');

    // Clear the log file on initialization
    try {
      fs.writeFileSync(this.logFilePath, `[${new Date().toISOString()}] Logger initialized\n`);
    } catch (err) {
      // If we can't write to file, just continue
    }
  }

  private writeToFile(message: string) {
    if (!this.debugMode) {
      return;
    }
    try {
      fs.appendFileSync(this.logFilePath, `[${new Date().toISOString()}] ${message}\n`);
    } catch (err) {
      // Silently fail if we can't write
    }
  }

  setDebugMode(enabled: boolean) {
    const previousMode = this.debugMode;
    this.debugMode = enabled;

    if (enabled && !previousMode) {
      // Clear log file when enabling debug mode
      try {
        fs.writeFileSync(this.logFilePath, `[${new Date().toISOString()}] Debug mode enabled\n`);
      } catch (err) {
        // Silently fail if we can't write
      }
    } else if (enabled) {
      this.writeToFile(`Debug mode re-enabled`);
    }
  }

  getDebugMode(): boolean {
    return this.debugMode;
  }

  info(message: string) {
    const msg = `[INFO] ${message}`;
    if (this.debugMode) {
      this.connection.console.log(msg);
    }
    this.writeToFile(msg);
  }

  warn(message: string) {
    const msg = `[WARN] ${message}`;
    if (this.debugMode) {
      this.connection.console.warn(msg);
    }
    this.writeToFile(msg);
  }

  error(message: string) {
    const msg = `[ERROR] ${message}`;
    if (this.debugMode) {
      this.connection.console.error(msg);
    }
    this.writeToFile(msg);
  }

  debug(message: string) {
    if (this.debugMode) {
      const msg = `[DEBUG] ${message}`;
      this.connection.console.log(msg);
      this.writeToFile(msg);
    }
  }

  showMessage(message: string, type: MessageType = MessageType.Info) {
    this.connection.sendNotification('window/showMessage', { type, message });
  }
}
