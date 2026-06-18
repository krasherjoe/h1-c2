export declare class OpenCodeApi {
    private baseUrl;
    private auth;
    constructor(baseUrl: string, password?: string);
    private get headers();
    private fetchJson;
    getDefaultModel(): Promise<{
        providerID: string;
        modelID: string;
    } | null>;
    private resolveModel;
    resolveModelOrDefault(modelStr?: string): Promise<{
        providerID: string;
        modelID: string;
    }>;
    listModels(): Promise<{
        id: string;
        providerID: string;
        name: string;
    }[]>;
    createSession(model?: {
        providerID: string;
        modelID: string;
    }): Promise<string>;
    sendMessage(sessionId: string, messages: {
        role: string;
        content: string;
    }[], model?: {
        providerID: string;
        modelID: string;
    }): Promise<string>;
    deleteSession(sessionId: string): Promise<void>;
}
//# sourceMappingURL=opencode_api.d.ts.map