# Providers, custom endpoints and 9Router

AI Studio talks to any endpoint that speaks one of the three wire formats below.
A provider is just a row of defaults; every one of them can be overridden with a
custom base URL, a custom model id and extra headers.

| Provider | Wire format | Default base URL | Key environment variables |
|---|---|---|---|
| OpenAI | `openai` | `https://api.openai.com/v1` | `OPENAI_API_KEY`, `AI_STUDIO_OPENAI_API_KEY` |
| Anthropic (Claude) | `anthropic` | `https://api.anthropic.com/v1` | `ANTHROPIC_API_KEY`, `AI_STUDIO_ANTHROPIC_API_KEY` |
| Google Gemini (native) | `gemini` | `https://generativelanguage.googleapis.com/v1beta` | `GEMINI_API_KEY`, `GOOGLE_API_KEY` |
| Google Gemini (OpenAI-compatible) | `openai` | `.../v1beta/openai` | `GEMINI_API_KEY`, `GOOGLE_API_KEY` |
| Nous Portal (Hermes models) | `openai` | `https://inference-api.nousresearch.com/v1` | `NOUS_API_KEY`, `NOUS_PORTAL_API_KEY` |
| OpenRouter | `openai` | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` |
| **9Router (local gateway)** | `openai` | `http://localhost:20128/v1` | `NINE_ROUTER_API_KEY`, `ROUTER_API_KEY` |
| Hermes Agent (local subscription proxy) | `openai` | `http://127.0.0.1:8645/v1` | – (no key required) |
| Ollama | `openai` | `http://127.0.0.1:11434/v1` | – (no key required) |
| LM Studio | `openai` | `http://127.0.0.1:1234/v1` | – (no key required) |
| Custom (OpenAI-compatible) | `openai` | `http://127.0.0.1:8000/v1` | `AI_STUDIO_CUSTOM_API_KEY` |

Environment variables always win over the value stored in
`user://ai_studio/config.cfg`, so a shared machine or a CI runner only needs the
variable set. `store_keys_in_config` (Model tab) decides whether a key typed into
the panel is written to that file at all; the file lives outside your project and
is `chmod 600` on POSIX when it contains a key.

## Model ids are free text

The model field accepts **any** id the endpoint understands: `gpt-5-mini`,
`claude-sonnet-4-6`, `kr/claude-sonnet-4.5`, or a router alias such as
`premium-coding`. A model that is not in the *Refresh models* list is still used –
it is kept per provider and shown in the list as `… (typed)`.

Type the id and either press **Enter**, click **Use typed model**, or just click
somewhere else: focus loss saves it too. (Typing and clicking away used to leave
the old model in place, which is the usual reason an alias or combo name appeared
to "not work".)

## 9Router

[9Router](https://github.com/decolua/9router) is a self-hosted gateway that sits
in front of 40+ upstream providers and exposes a single OpenAI-compatible
endpoint, with fallback chains ("combos") that you define in its dashboard.

1. Start 9Router and open its dashboard (`http://localhost:20128/dashboard`).
2. Connect at least one provider and copy the API key the dashboard shows.
3. In Godot: **AI Studio → Model → Provider → 9Router (local gateway)**. The base
   URL is pre-filled with `http://localhost:20128/v1`.
4. Paste the API key. `http://localhost:20128` (no path) works as well – `/v1` is
   appended automatically and the field is updated to show what will be used.
5. In **Model ID**, type either
   * a routed model with its prefix – `kr/claude-sonnet-4.5`, `cc/claude-opus-4-7`,
     `cx/gpt-5.2-codex`, or
   * the name of a combo you created – `premium-coding`, `free-combo`, `budget-combo`.
6. Press **Enter** (or *Use typed model*), then **Test**. A reply of `OK` means
   key + model + routing are all fine.
7. **Refresh models** asks `GET /v1/models` and lists everything the gateway
   reports – routed models and combos alike. Combos a gateway does not list can
   still be typed in; nothing has to be discovered first.

The Custom provider (`Provider → Custom (OpenAI-compatible)`) works the same way
if you prefer to keep it separate from the preset: set the base URL to
`http://localhost:20128/v1`, paste the key, type the combo name.

### When something does not work

| Symptom | Cause |
|---|---|
| `HTTP 401` / `Authentication failed` | Wrong or missing key. Keys come from the environment first (see the table), then from the panel. The Model tab prints the *key source* it is using. |
| `HTTP 404` on `/chat/completions` | Base URL missing `/v1` (or pointing at the dashboard port). Apply the URL and check the field's normalised value. |
| The combo's first provider is exhausted | Not a plugin problem: 9Router itself returns the upstream error, and that text is shown in the chat. Check the combo in the 9Router dashboard. |
| `HTTP 400 ... stream_options` | The gateway or its upstream rejects `stream_options.include_usage`. AI Studio retries the request without it and remembers that for this provider, so it happens only once. The chat status line reports the fallback. |
| `HTTP 400 ... tools` | The routed upstream does not accept tool definitions. AI Studio retries without tools; the model then answers in plain chat mode. Pick a tool-capable model for agent mode. |

Optional request fields are retried this way per provider
(`omit_stream_options`, `omit_tools`, `omit_temperature` in the config file).
Delete those keys to start from the full request again.

## Project overrides: `res://.ai_studio.json`

A project may commit a file with team-wide, non-secret settings:

```json
{
  "general": { "model": "premium-coding" },
  "providers": { "9router": { "base_url": "http://192.168.1.20:20128/v1" } },
  "mcp": { "servers": { "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "."] } } }
}
```

* It **may** set model choices, base URLs, MCP server definitions and other
  convenience settings.
* It **may not** set `api_key`, `system_prompt`, approval prompts
  (`confirm_mutations`, `approve_mcp_tools`, `auto_approve_safe_tools`) or MCP
  auto-start/sampling switches – those are ignored there on purpose, because the
  file travels with cloned projects.
* MCP servers that come from this file are listed on the MCP tab but are **not
  started automatically** until you tick *Trust this project's servers*.
