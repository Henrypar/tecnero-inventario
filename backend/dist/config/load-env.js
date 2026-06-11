"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadEnvFile = loadEnvFile;
const fs_1 = require("fs");
const path_1 = require("path");
function parseEnvLine(line) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
        return null;
    }
    const normalized = trimmed.startsWith('export ') ? trimmed.slice(7).trim() : trimmed;
    const separatorIndex = normalized.indexOf('=');
    if (separatorIndex <= 0) {
        return null;
    }
    const key = normalized.slice(0, separatorIndex).trim();
    let value = normalized.slice(separatorIndex + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
    }
    return [key, value];
}
function loadEnvFile() {
    const envPath = (0, path_1.resolve)(__dirname, '..', '.env');
    if (!(0, fs_1.existsSync)(envPath)) {
        return;
    }
    const content = (0, fs_1.readFileSync)(envPath, 'utf8');
    for (const line of content.split(/\r?\n/)) {
        const parsed = parseEnvLine(line);
        if (!parsed) {
            continue;
        }
        const [key, value] = parsed;
        if (process.env[key] === undefined) {
            process.env[key] = value;
        }
    }
}
//# sourceMappingURL=load-env.js.map