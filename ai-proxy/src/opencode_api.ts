import { OpenCodeSession, OpenCodePart, OpenCodeMessageResponse, OpenCodeProvidersResponse, OpenCodeProviderInfo } from './types';

export class OpenCodeApi {
  private baseUrl: string;
  private auth: string | null;

  constructor(baseUrl: string, password?: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.auth = password
      ? 'Basic ' + Buffer.from(`opencode:${password}`).toString('base64')
      : null;
  }

  private get headers(): Record<string, string> {
    const h: Record<string, string> = { 'Content-Type': 'application/json' };
    if (this.auth) h['Authorization'] = this.auth;
    return h;
  }

  private async fetchJson(path: string, options?: RequestInit): Promise<unknown> {
    const url = `${this.baseUrl}${path}`;
    const res = await fetch(url, {
      ...options,
      headers: { ...this.headers, ...(options?.headers as Record<string, string> || {}) },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`OpenCode API ${res.status} ${path}: ${body}`);
    }
    const ct = res.headers.get('content-type') || '';
    if (ct.includes('application/json')) return res.json();
    return res.text();
  }

  async getDefaultModel(): Promise<{ providerID: string; modelID: string } | null> {
    try {
      const data = await this.fetchJson('/config/providers') as OpenCodeProvidersResponse;
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
    } catch {
      return { providerID: 'anthropic', modelID: 'claude-sonnet-4-20250514' };
    }
  }

  private resolveModel(modelStr: string): { providerID: string; modelID: string } | null {
    if (modelStr.includes('/')) {
      const idx = modelStr.indexOf('/');
      return {
        providerID: modelStr.substring(0, idx),
        modelID: modelStr.substring(idx + 1),
      };
    }
    return null;
  }

  async resolveModelOrDefault(modelStr?: string): Promise<{ providerID: string; modelID: string }> {
    if (modelStr) {
      const resolved = this.resolveModel(modelStr);
      if (resolved) return resolved;
    }
    const def = await this.getDefaultModel();
    if (def) return def;
    return { providerID: 'anthropic', modelID: 'claude-sonnet-4-20250514' };
  }

  async listModels(): Promise<{ id: string; providerID: string; name: string }[]> {
    try {
      const data = await this.fetchJson('/config/providers') as OpenCodeProvidersResponse;
      const result: { id: string; providerID: string; name: string }[] = [];
      for (const p of (data.providers || [])) {
        for (const m of (p.models || [])) {
          result.push({ id: `${p.id}/${m.id}`, providerID: p.id, name: m.name || m.id });
        }
      }
      return result;
    } catch {
      return [];
    }
  }

  async createSession(model?: { providerID: string; modelID: string }): Promise<string> {
    const body: Record<string, unknown> = { title: 'ai-proxy' };
    const data = await this.fetchJson('/session', {
      method: 'POST',
      body: JSON.stringify(body),
    }) as OpenCodeSession;
    return data.id;
  }

  async sendMessage(
    sessionId: string,
    messages: { role: string; content: string }[],
    model?: { providerID: string; modelID: string },
  ): Promise<string> {
    const parts: OpenCodePart[] = [];
    const systemParts: string[] = [];

    for (const msg of messages) {
      if (msg.role === 'system') {
        systemParts.push(msg.content);
      } else {
        const rolePrefix = msg.role === 'assistant' ? 'Assistant: ' : '';
        parts.push({ type: 'text', text: rolePrefix + msg.content });
      }
    }

    const system = systemParts.length > 0 ? systemParts.join('\n') : undefined;

    const body: Record<string, unknown> = { parts };
    if (system) body['system'] = system;
    if (model) body['model'] = model;

    const data = await this.fetchJson(`/session/${sessionId}/message`, {
      method: 'POST',
      body: JSON.stringify(body),
    }) as OpenCodeMessageResponse;

    const textParts = data.parts?.filter(p => p.type === 'text') || [];
    return textParts.map(p => p.text).join('\n');
  }

  async deleteSession(sessionId: string): Promise<void> {
    try {
      await this.fetchJson(`/session/${sessionId}`, { method: 'DELETE' });
    } catch {
      // ignore cleanup errors
    }
  }
}
