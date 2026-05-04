export type LlmModelOption = {
  value: string;
  label: string;
};

export const DEFAULT_MARKET_FLOW_MODEL = "google/gemma-4-26b-a4b-it";

export const SHARED_MARKET_FLOW_MODEL_OPTIONS: LlmModelOption[] = [
  { value: "google/gemma-4-26b-a4b-it", label: "Gemma 4 26B (Default)" },
  { value: "google/gemini-2.5-flash", label: "Gemini 2.5 Flash" },
  { value: "openai/gpt-5-mini", label: "GPT-5 Mini" },
  { value: "qwen/qwen3-30b-a3b", label: "Qwen3 30B" },
  { value: "qwen/qwen3.5-flash-02-23", label: "Qwen3.5 Flash" },
  { value: "qwen/qwen3.6-plus", label: "Qwen3.6 Plus" },
  { value: "openai/gpt-5.1", label: "GPT-5.1" },
  { value: "openai/gpt-4.1-mini", label: "GPT-4.1 Mini" },
  { value: "openai/gpt-4o-mini", label: "GPT-4o Mini" },
  { value: "google/gemini-2.5-pro", label: "Gemini 2.5 Pro" },
  { value: "google/gemma-4-26b-a4b-it:free", label: "Gemma 4 26B (Free)" },
  { value: "google/gemma-4-31b-it:free", label: "Gemma 4 31B (Free)" },
  { value: "deepseek/deepseek-v3.2", label: "DeepSeek V3.2" },
  { value: "deepseek/deepseek-r1-distill-qwen-32b", label: "DeepSeek R1 Qwen3 32B" },
  { value: "x-ai/grok-4.1-fast", label: "Grok 4.1 Fast" },
  { value: "bytedance-seed/seed-1.6-flash", label: "Seed 1.6 Flash" },
  { value: "moonshotai/kimi-k2-thinking", label: "Kimi K2 Thinking" },
  { value: "z-ai/glm-4.7-flash", label: "GLM-4.7 Flash" },
];
