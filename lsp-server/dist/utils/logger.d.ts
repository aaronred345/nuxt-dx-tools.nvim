import { Connection, MessageType } from 'vscode-languageserver/node';
export declare class Logger {
    private connection;
    private debugMode;
    constructor(connection: Connection);
    setDebugMode(enabled: boolean): void;
    info(message: string): void;
    warn(message: string): void;
    error(message: string): void;
    debug(message: string): void;
    showMessage(message: string, type?: MessageType): void;
}
//# sourceMappingURL=logger.d.ts.map