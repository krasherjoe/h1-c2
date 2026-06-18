"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpenCodeApi = void 0;
class OpenCodeApi {
    baseUrl;
    auth;
    constructor(baseUrl, password) {
        this.baseUrl = baseUrl.replace(/\/$/, '');
        this.auth = password
            ? 'Basic ' + Buffer.from(`opencode:${password}`).toString('base64')
            : null;
    }
    get headers() {
        const h = { 'Content-Type': 'application/json' };
        if (this.auth)
            h['Authorization'] = this.auth;
        return h;
    }
    async fetchJson(path, options) {
        const url = `${this.baseUrl}${path}`;
        const res = await fetch(url, {
            ...options,
            headers: { ...this.headers, ...(options?.headers || {}) },
        });
        if (!res.ok) {
            const body = await res.text().catch(() => '');
            throw new Error(`OpenCode API ${res.status} ${path}: ${body}`);
        }
        const ct = res.headers.get('content-type') || '';
        if (ct.includes('application/json'))
            return res.json();
        return res.text();
    }
    async getDefaultModel() {
        try {
            const data = await this.fetchJson('/config/providers');
            const defaultKey = data.default?.chat;
            if (defaultKey && defaultKey.includes('/')) {
                const [providerID, ...rest] = defaultKey.split('/');
                return { providerID, modelID: rest.join('/') };
            }
            if (data.providers?.length > 0) {
                const first = data.providers[0];
                if (first.models?.length > 0) {
                    return { providerID: first.id, modelID: first.models[0].id };
                }
            }
            return null;
        }
        catch {
            return { providerID: 'anthropic', modelID: 'claude-sonnet-4-20250514' };
        }
    }
    resolveModel(modelStr) {
        if (modelStr.includes('/')) {
            const idx = modelStr.indexOf('/');
            return {
                providerID: modelStr.substring(0, idx),
                modelID: modelStr.substring(idx + 1),
            };
        }
        return null;
    }
    async resolveModelOrDefault(modelStr) {
        if (modelStr) {
            const resolved = this.resolveModel(modelStr);
            if (resolved)
                return resolved;
        }
        const def = await this.getDefaultModel();
        if (def)
            return def;
        return { providerID: 'anthropic', modelID: 'claude-sonnet-4-20250514' };
    }
    async listModels() {
        try {
            const data = await this.fetchJson('/config/providers');
            const result = [];
            for (const p of (data.providers || [])) {
                for (const m of (p.models || [])) {
                    result.push({ id: `${p.id}/${m.id}`, providerID: p.id, name: m.name || m.id });
                }
            }
            return result;
        }
        catch {
            return [];
        }
    }
    async createSession(model) {
        const body = { title: 'ai-proxy' };
        const data = await this.fetchJson('/session', {
            method: 'POST',
            body: JSON.stringify(body),
        });
        return data.id;
    }
    async sendMessage(sessionId, messages, model) {
        const parts = [];
        const systemParts = [];
        for (const msg of messages) {
            if (msg.role === 'system') {
                systemParts.push(msg.content);
            }
            else {
                const rolePrefix = msg.role === 'assistant' ? 'Assistant: ' : '';
                parts.push({ type: 'text', text: rolePrefix + msg.content });
            }
        }
        const system = systemParts.length > 0 ? systemParts.join('\n') : undefined;
        const body = { parts };
        if (system)
            body['system'] = system;
        if (model)
            body['model'] = model;
        const data = await this.fetchJson(`/session/${sessionId}/message`, {
            method: 'POST',
            body: JSON.stringify(body),
        });
        const textParts = data.parts?.filter(p => p.type === 'text') || [];
        return textParts.map(p => p.text).join('\n');
    }
    async deleteSession(sessionId) {
        try {
            await this.fetchJson(`/session/${sessionId}`, { method: 'DELETE' });
        }
        catch {
            // ignore cleanup errors
        }
    }
}
exports.OpenCodeApi = OpenCodeApi;
//# sourceMappingURL=opencode_api.js.map