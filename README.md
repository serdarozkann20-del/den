# AI Studio (Godot editor plugin)

Chat with AI models and let them use tools on your project, from inside the Godot 4.7 editor.
Bring your own key for OpenAI, Anthropic, Google, Nous/Hermes, OpenRouter, Ollama, LM Studio
or any OpenAI-compatible endpoint, and connect MCP servers — including Hermes Agent.

## Install

1. Copy this folder to `<your project>/addons/ai_studio`.
2. **Project → Project Settings → Plugins** → enable **AI Studio**.
3. Pick a provider and paste an API key in the **Model** tab, press *Refresh models*, choose a
   model.
4. Chat in the **Chat** tab. Agent mode lets the model call tools (with approval); Chat mode is
   a plain conversation.

Full documentation, the tool list and the MCP setup (including Hermes Agent presets) ship with
the source repository:

* `docs/providers.md` — providers, environment variables, custom endpoints, model discovery
* `docs/mcp.md` — stdio/HTTP transports, server definitions, Hermes Agent, sampling bridge
* `docs/tools.md` — all 36 built-in tools, guardrails and the agent loop
* `docs/3d.md` — rig/bone-map, animation retargeting, physics, lighting and import workflows
* `docs/testing.md` — test suite, mock servers, smoke test, install check

If the plugin does not show up in **Project → Project Settings → Plugins**, the archive was
most likely extracted one level too deep (Godot only loads `addons/ai_studio/plugin.cfg`).
`tools/check_install.sh /path/to/project` names the problem, and
`docs/install-troubleshooting.md` walks through the fixes.

## Verify the install

```bash
AI_STUDIO_SMOKE_TEST=1 godot --headless --editor --path /path/to/project
```

Prints one line per check and exits 0 when the plugin is healthy.

## Where things are stored

* Settings and API keys: `user://ai_studio/config.cfg` (never inside your project)
* Conversations: `user://ai_studio/sessions/`
* Screenshots taken by the model: `user://ai_studio/shots/`
* Optional team-shared, non-secret settings: `res://.ai_studio.json`
