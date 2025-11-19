import { Connection, MessageType } from 'vscode-languageserver/node';
export declare class Logger {
    private connection;
    private debugMode;
    private logFilePath;
    constructor(connection: Connection);
    private writeToFile;
    setDebugMode(enabled: boolean): void;
    getDebugMode(): boolean;
    info(message: string): void;
    warn(message: string): void;
    error(message: string): void;
    debug(message: string): void;
    showMessage(message: string, type?: MessageType): void;
}
//# sourceMappingURL=logger.d.ts.map