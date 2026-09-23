# AI Studio (Godot editor plugin)

Chat with AI models and let them use tools on your project, from inside the Godot 4.7 editor.
Bring your own key for OpenAI, Anthropic, Google, Nous/Hermes, OpenRouter, 9Router, Ollama,
LM Studio or any OpenAI-compatible endpoint, and connect MCP servers — including Hermes Agent.

## Install

1. Copy this folder to `<your project>/addons/ai_studio`.
2. **Project → Project Settings → Plugins** → enable **AI Studio**.
3. Pick a provider and paste an API key in the **Model** tab, press *Refresh models*, choose a
   model — or type any model id the endpoint knows.
4. Chat in the **Chat** tab. Agent mode lets the model call tools (with approval); Chat mode is
   a plain conversation.

Godot only loads `addons/ai_studio/plugin.cfg`. If the plugin does not show up in
**Project → Project Settings → Plugins**, this folder was extracted one level too deep.

## Models: any id, any router

The **Model ID** field is free text: `gpt-5-mini`, `claude-sonnet-4-6`, a routed id such as
`kr/claude-sonnet-4.5`, or a **combo name** from a router like 9Router (`premium-coding`,
`free-combo`). Type it and press **Enter**, click *Use typed model*, or simply click elsewhere —
all three save it. *Refresh models* lists what the endpoint reports; ids that are not listed can
still be typed in.

`Provider → 9Router (local gateway)` is pre-configured for `http://localhost:20128/v1` (the port
without a path works too — `/v1` is appended for you). Paste the key from the 9Router dashboard,
type the combo name, press **Test**.

Providers, environment variables, 9Router notes and troubleshooting:
[`docs/providers.md`](docs/providers.md).

## Verify the install

```bash
AI_STUDIO_SMOKE_TEST=1 godot --headless --editor --path /path/to/project
```

Prints one line per check and exits 0 when the plugin is healthy.

## Where things are stored

* Settings and API keys: `user://ai_studio/config.cfg` (never inside your project)
* Conversations: `user://ai_studio/sessions/`
* Screenshots taken by the model: `user://ai_studio/shots/`
* Optional team-shared, non-secret settings: `res://.ai_studio.json` — it may set model choices,
  base URLs and MCP server definitions, but never API keys, the system prompt or approval
  settings, and its MCP servers only start after you tick *Trust this project's servers*.
