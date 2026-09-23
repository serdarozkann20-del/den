@tool
class_name AIStudioProviders
extends RefCounted

## Central registry of model providers.
##
## Every provider is described by a plain Dictionary so that the plugin works
## even when the vendor's model catalogue changes: model lists are discovered
## at runtime from the provider's own listing endpoint ("Refresh models"), and
## the `hints` array is only ever a convenience placeholder, never a whitelist.
##
## "api" selects the wire format implemented in llm_client.gd:
##   - "openai"    : POST {base}/chat/completions  (OpenAI Chat Completions shape,
##                   also implemented by Nous Portal, OpenRouter, Ollama, LM Studio,
##                   Hermes Agent's subscription proxy, vLLM, llama.cpp, ...)
##   - "anthropic" : POST {base}/messages          (Anthropic Messages API)
##   - "gemini"    : POST {base}/models/{model}:streamGenerateContent?alt=sse

const DEFAULT_ID := "openai"

const PROVIDERS := {
	"openai": {
		"label": "OpenAI",
		"api": "openai",
		"base_url": "https://api.openai.com/v1",
		"auth": "bearer",
		"key_env": ["OPENAI_API_KEY", "AI_STUDIO_OPENAI_API_KEY"],
		"key_url": "https://platform.openai.com/api-keys",
		"default_model": "",
		"hints": ["gpt-5.1", "gpt-5", "gpt-5-mini"],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
	},
	"anthropic": {
		"label": "Anthropic (Claude)",
		"api": "anthropic",
		"base_url": "https://api.anthropic.com/v1",
		"auth": "x-api-key",
		"extra_headers": {"anthropic-version": "2023-06-01"},
		"key_env": ["ANTHROPIC_API_KEY", "AI_STUDIO_ANTHROPIC_API_KEY"],
		"key_url": "https://console.anthropic.com/settings/keys",
		"default_model": "",
		"hints": ["claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5"],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
	},
	"google": {
		"label": "Google Gemini (native API)",
		"api": "gemini",
		"base_url": "https://generativelanguage.googleapis.com/v1beta",
		"auth": "query_key",
		"key_env": ["GEMINI_API_KEY", "GOOGLE_API_KEY", "AI_STUDIO_GEMINI_API_KEY"],
		"key_url": "https://aistudio.google.com/app/apikey",
		"default_model": "",
		"hints": ["gemini-3.1-pro", "gemini-3.6-flash"],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
	},
	"google_openai": {
		"label": "Google Gemini (OpenAI-compatible)",
		"api": "openai",
		"base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
		"auth": "bearer",
		"key_env": ["GEMINI_API_KEY", "GOOGLE_API_KEY", "AI_STUDIO_GEMINI_API_KEY"],
		"key_url": "https://aistudio.google.com/app/apikey",
		"default_model": "",
		"hints": ["gemini-3.6-flash"],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
	},
	"nous_portal": {
		"label": "Nous Portal (Hermes models)",
		"api": "openai",
		"base_url": "https://inference-api.nousresearch.com/v1",
		"auth": "bearer",
		"key_env": ["NOUS_API_KEY", "NOUS_PORTAL_API_KEY", "AI_STUDIO_NOUS_API_KEY"],
		"key_url": "https://portal.nousresearch.com",
		"default_model": "Hermes-4-70B",
		"hints": ["Hermes-4-70B", "Hermes-4.3-36B", "Hermes-4-405B"],
		"supports_tools": true,
		"supports_vision": false,
		"needs_key": true,
		"notes": "OpenAI-compatible endpoint serving Nous' own Hermes models (128K context) plus, per your subscription, a wider catalogue.",
	},
	"openrouter": {
		"label": "OpenRouter",
		"api": "openai",
		"base_url": "https://openrouter.ai/api/v1",
		"auth": "bearer",
		"key_env": ["OPENROUTER_API_KEY", "AI_STUDIO_OPENROUTER_API_KEY"],
		"key_url": "https://openrouter.ai/keys",
		"default_model": "nousresearch/hermes-4-70b",
		"hints": ["nousresearch/hermes-4-70b", "nousresearch/hermes-4-405b", "anthropic/claude-sonnet-4.6"],
		"extra_headers": {"X-Title": "Godot AI Studio"},
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
	},
	"hermes_agent": {
		"label": "Hermes Agent (local subscription proxy)",
		"api": "openai",
		"base_url": "http://127.0.0.1:8645/v1",
		"auth": "bearer",
		"key_env": [],
		"default_model": "Hermes-4-70B",
		"hints": ["Hermes-4-70B", "Hermes-4.3-36B", "Hermes-4-405B"],
		"supports_tools": true,
		"supports_vision": false,
		"needs_key": false,
		"local": true,
		"notes": "Start it with `hermes proxy start` (or `hermes proxy`). Hermes attaches your real credentials, so any non-empty API key works. Agent tools live on the MCP tab (`hermes mcp serve`).",
	},
	"ollama": {
		"label": "Ollama (local)",
		"api": "openai",
		"base_url": "http://127.0.0.1:11434/v1",
		"auth": "bearer",
		"key_env": [],
		"default_model": "",
		"hints": [],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": false,
		"local": true,
		"notes": "Ollama's OpenAI-compatible endpoint. Install models with `ollama pull <model>`; discovered models appear after Refresh.",
	},
	"lmstudio": {
		"label": "LM Studio (local)",
		"api": "openai",
		"base_url": "http://127.0.0.1:1234/v1",
		"auth": "bearer",
		"key_env": [],
		"default_model": "",
		"hints": [],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": false,
		"local": true,
		"notes": "Enable the Local Server in LM Studio and load a model that supports tool calling for agent mode.",
	},
	"9router": {
		"label": "9Router (local gateway)",
		"api": "openai",
		"base_url": "http://localhost:20128/v1",
		"auth": "bearer",
		"key_env": ["NINE_ROUTER_API_KEY", "ROUTER_API_KEY", "AI_STUDIO_9ROUTER_API_KEY"],
		"default_model": "",
		"hints": [],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": true,
		"local": true,
		"normalize_base_url": true,   # accept http://localhost:20128 as well as .../v1
		"notes": "9Router is a self-hosted OpenAI-compatible gateway (dashboard: http://localhost:20128/dashboard). Paste the key shown in the dashboard. The model field takes either a routed model ('kr/claude-sonnet-4.5', 'cc/claude-opus-4-7') or the name of a combo you created ('premium-coding', 'free-combo', 'budget-combo') - exactly what you would type in Cline/Cursor. Type it and press Enter; Refresh models also lists combos when the gateway reports them.",
	},
	"custom": {
		"label": "Custom (OpenAI-compatible)",
		"api": "openai",
		"base_url": "http://127.0.0.1:8000/v1",
		"auth": "bearer",
		"key_env": ["AI_STUDIO_CUSTOM_API_KEY"],
		"default_model": "",
		"hints": [],
		"supports_tools": true,
		"supports_vision": true,
		"needs_key": false,
		"normalize_base_url": true,   # http://host:port becomes http://host:port/v1
		"notes": "vLLM, llama.cpp server, text-generation-webui, LiteLLM, 9Router, a company gateway... anything that speaks /chat/completions. The model field accepts any id the endpoint knows, including router aliases and combo names - type it and press Enter (or click 'Use typed model'). No model list is required for those.",
	},
}


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in PROVIDERS:
		out.append(id)
	out.sort()
	return out


## Returns the provider metadata with `id` merged in, or an empty Dictionary.
static func get_info(id: String) -> Dictionary:
	if not PROVIDERS.has(id):
		return {}
	var info: Dictionary = (PROVIDERS[id] as Dictionary).duplicate(true)
	info["id"] = id
	return info


static func default_model(id: String) -> String:
	return String(get_info(id).get("default_model", ""))


static func api_of(id: String) -> String:
	return String(get_info(id).get("api", "openai"))


## Providers whose tools/vision flags should be trusted for capability warnings.
static func supports_tools(id: String) -> bool:
	return bool(get_info(id).get("supports_tools", true))


static func supports_vision(id: String) -> bool:
	return bool(get_info(id).get("supports_vision", false))


## Human readable list used in the settings UI dropdown.
static func labels() -> Array:
	var out: Array = []
	for id in ids():
		out.append({"id": id, "label": String(get_info(id).get("label", id))})
	return out
