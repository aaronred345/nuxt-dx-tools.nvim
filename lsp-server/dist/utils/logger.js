"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Logger = void 0;
const node_1 = require("vscode-languageserver/node");
class Logger {
    connection;
    debugMode = false;
    constructor(connection) {
        this.connection = connection;
    }
    setDebugMode(enabled) {
        this.debugMode = enabled;
    }
    info(message) {
        this.connection.console.log(`[INFO] ${message}`);
    }
    warn(message) {
        this.connection.console.warn(`[WARN] ${message}`);
    }
    error(message) {
        this.connection.console.error(`[ERROR] ${message}`);
    }
    debug(message) {
        if (this.debugMode) {
            this.connection.console.log(`[DEBUG] ${message}`);
        }
    }
    showMessage(message, type = node_1.MessageType.Info) {
        this.connection.sendNotification('window/showMessage', { type, message });
    }
}
exports.Logger = Logger;
//# sourceMappingURL=logger.js.map