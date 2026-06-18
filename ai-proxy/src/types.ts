export interface OpenAIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface ChatCompletionRequest {
  model?: string;
  messages: OpenAIMessage[];
  temperature?: number;
  max_tokens?: number;
  stream?: boolean;
}

export interface ChatCompletionResponse {
  id: string;
  object: 'chat.completion';
  created: number;
  model: string;
  choices: {
    index: number;
    message: OpenAIMessage;
    finish_reason: 'stop' | 'length' | null;
  }[];
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

export interface ChatCompletionChunk {
  id: string;
  object: 'chat.completion.chunk';
  created: number;
  model: string;
  choices: {
    index: number;
    delta: { role?: string; content?: string };
    finish_reason: 'stop' | 'length' | null;
  }[];
}

export interface ModelInfo {
  id: string;
  object: 'model';
  created: number;
  owned_by: string;
}

export interface ModelListResponse {
  object: 'list';
  data: ModelInfo[];
}

export interface OpenCodeSession {
  id: string;
  title?: string;
}

export interface OpenCodePart {
  type: 'text';
  text: string;
}

export interface OpenCodeMessageResponse {
  info: Record<string, unknown>;
  parts: OpenCodePart[];
}

export interface OpenCodeProviderInfo {
  id: string;
  name: string;
  models: { id: string; name?: string }[];
}

export interface OpenCodeProvidersResponse {
  providers: OpenCodeProviderInfo[];
  default: Record<string, string>;
}
