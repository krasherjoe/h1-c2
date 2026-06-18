"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const opencode_api_1 = require("./opencode_api");
const OPENCODE_SERVER_URL = process.env.OPENCODE_SERVER_URL || 'http://localhost:8686';
const OPENCODE_SERVER_PASSWORD = process.env.OPENCODE_SERVER_PASSWORD || '';
const PORT = parseInt(process.env.PORT || '8787', 10);
const HOST = process.env.HOST || '0.0.0.0';
const api = new opencode_api_1.OpenCodeApi(OPENCODE_SERVER_URL, OPENCODE_SERVER_PASSWORD);
const app = (0, express_1.default)();
app.use((0, cors_1.default)());
app.use(express_1.default.json());
function createId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = 'chatcmpl-';
    for (let i = 0; i < 24; i++)
        result += chars[Math.floor(Math.random() * chars.length)];
    return result;
}
function estimateTokens(text) {
    return Math.ceil(text.length / 4);
}
async function handleChatCompletion(req, res) {
    const body = req.body;
    if (!body || !body.messages || !Array.isArray(body.messages) || body.messages.length === 0) {
        res.status(400).json({ error: { message: 'messages is required', type: 'invalid_request_error' } });
        return;
    }
    const isStream = body.stream === true;
    const model = await api.resolveModelOrDefault(body.model);
    const chatId = createId();
    const created = Math.floor(Date.now() / 1000);
    const modelStr = body.model || `${model.providerID}/${model.modelID}`;
    let sessionId = null;
    try {
        sessionId = await api.createSession(model);
        const content = await api.sendMessage(sessionId, body.messages, model);
        if (isStream) {
            res.setHeader('Content-Type', 'text/event-stream');
            res.setHeader('Cache-Control', 'no-cache');
            res.setHeader('Connection', 'keep-alive');
            res.setHeader('X-Accel-Buffering', 'no');
            const firstChunk = {
                id: chatId,
                object: 'chat.completion.chunk',
                created,
                model: modelStr,
                choices: [{ index: 0, delta: { role: 'assistant' }, finish_reason: null }],
            };
            res.write(`data: ${JSON.stringify(firstChunk)}\n\n`);
            const words = content.split(/(?<=\s)/);
            for (const word of words) {
                const chunk = {
                    id: chatId,
                    object: 'chat.completion.chunk',
                    created,
                    model: modelStr,
                    choices: [{ index: 0, delta: { content: word }, finish_reason: null }],
                };
                res.write(`data: ${JSON.stringify(chunk)}\n\n`);
            }
            const finalChunk = {
                id: chatId,
                object: 'chat.completion.chunk',
                created,
                model: modelStr,
                choices: [{ index: 0, delta: {}, finish_reason: 'stop' }],
            };
            res.write(`data: ${JSON.stringify(finalChunk)}\n\n`);
            res.write('data: [DONE]\n\n');
            res.end();
        }
        else {
            const promptTokens = body.messages.reduce((sum, m) => sum + estimateTokens(m.content || ''), 0);
            const completionTokens = estimateTokens(content);
            const response = {
                id: chatId,
                object: 'chat.completion',
                created,
                model: modelStr,
                choices: [{
                        index: 0,
                        message: { role: 'assistant', content },
                        finish_reason: 'stop',
                    }],
                usage: {
                    prompt_tokens: promptTokens,
                    completion_tokens: completionTokens,
                    total_tokens: promptTokens + completionTokens,
                },
            };
            res.json(response);
        }
    }
    catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        if (isStream) {
            if (!res.headersSent) {
                res.setHeader('Content-Type', 'text/event-stream');
                res.setHeader('Cache-Control', 'no-cache');
                res.setHeader('Connection', 'keep-alive');
            }
            const errChunk = {
                id: chatId,
                object: 'chat.completion.chunk',
                created,
                model: modelStr,
                choices: [{ index: 0, delta: { content: `\n\n[Error: ${message}]` }, finish_reason: 'stop' }],
            };
            res.write(`data: ${JSON.stringify(errChunk)}\n\n`);
            res.write('data: [DONE]\n\n');
            res.end();
        }
        else {
            res.status(502).json({
                error: { message: `OpenCode API error: ${message}`, type: 'server_error' },
            });
        }
    }
    finally {
        if (sessionId) {
            api.deleteSession(sessionId).catch(() => { });
        }
    }
}
app.post('/v1/chat/completions', (req, res) => {
    handleChatCompletion(req, res).catch(err => {
        if (!res.headersSent) {
            res.status(500).json({ error: { message: String(err), type: 'server_error' } });
        }
    });
});
app.get('/v1/models', async (_req, res) => {
    try {
        const models = await api.listModels();
        const data = models.map((m, i) => ({
            id: m.id,
            object: 'model',
            created: Math.floor(Date.now() / 1000) - i,
            owned_by: m.providerID,
        }));
        const response = { object: 'list', data };
        res.json(response);
    }
    catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        res.status(502).json({ error: { message: `OpenCode API error: ${message}`, type: 'server_error' } });
    }
});
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', opencode_server: OPENCODE_SERVER_URL });
});
app.use((err, _req, res, _next) => {
    console.error('[ai-proxy]', err);
    if (!res.headersSent) {
        res.status(500).json({ error: { message: 'Internal server error', type: 'server_error' } });
    }
});
app.listen(PORT, HOST, () => {
    console.log(`ai-proxy running on http://${HOST}:${PORT}`);
    console.log(`  OpenAI-compatible API: http://${HOST}:${PORT}/v1`);
    console.log(`  OpenCode Server: ${OPENCODE_SERVER_URL}`);
    console.log(`  Streaming: supported (pseudo-streaming)`);
});
//# sourceMappingURL=index.js.map