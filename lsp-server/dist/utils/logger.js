"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.Logger = void 0;
const node_1 = require("vscode-languageserver/node");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
class Logger {
    connection;
    debugMode = false;
    logFilePath;
    constructor(connection) {
        this.connection = connection;
        // Create log file path in the lsp-server directory
        this.logFilePath = path.join(__dirname, '../../server-debug.log');
        // Clear the log file on initialization
        try {
            fs.writeFileSync(this.logFilePath, `[${new Date().toISOString()}] Logger initialized\n`);
        }
        catch (err) {
            // If we can't write to file, just continue
        }
    }
    writeToFile(message) {
        try {
            fs.appendFileSync(this.logFilePath, `[${new Date().toISOString()}] ${message}\n`);
        }
        catch (err) {
            // Silently fail if we can't write
        }
    }
    setDebugMode(enabled) {
        this.debugMode = enabled;
        this.writeToFile(`Debug mode set to: ${enabled}`);
    }
    info(message) {
        const msg = `[INFO] ${message}`;
        this.connection.console.log(msg);
        this.writeToFile(msg);
    }
    warn(message) {
        const msg = `[WARN] ${message}`;
        this.connection.console.warn(msg);
        this.writeToFile(msg);
    }
    error(message) {
        const msg = `[ERROR] ${message}`;
        this.connection.console.error(msg);
        this.writeToFile(msg);
    }
    debug(message) {
        if (this.debugMode) {
            const msg = `[DEBUG] ${message}`;
            this.connection.console.log(msg);
            this.writeToFile(msg);
        }
    }
    showMessage(message, type = node_1.MessageType.Info) {
        this.connection.sendNotification('window/showMessage', { type, message });
    }
}
exports.Logger = Logger;
//# sourceMappingURL=logger.js.map