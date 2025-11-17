import { Connection, MessageType } from 'vscode-languageserver/node';

export class Logger {
  private debugMode = false;

  constructor(private connection: Connection) {}

  setDebugMode(enabled: boolean) {
    this.debugMode = enabled;
  }

  info(message: string) {
    this.connection.console.log(`[INFO] ${message}`);
  }

  warn(message: string) {
    this.connection.console.warn(`[WARN] ${message}`);
  }

  error(message: string) {
    this.connection.console.error(`[ERROR] ${message}`);
  }

  debug(message: string) {
    if (this.debugMode) {
      this.connection.console.log(`[DEBUG] ${message}`);
    }
  }

  showMessage(message: string, type: MessageType = MessageType.Info) {
    this.connection.sendNotification('window/showMessage', { type, message });
  }
}
