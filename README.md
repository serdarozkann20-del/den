# AI Studio (Godot editor plugin)

Chat with AI models and let them use tools on your project, from inside the Godot 4.7 editor.
Bring your own key for OpenAI, Anthropic, Google, Nous/Hermes, OpenRouter, **9Router**, Ollama,
LM Studio or any OpenAI-compatible endpoint, and connect MCP servers — including Hermes Agent.

## Install

1. Copy the `addons/ai_studio` folder from this repository into `<your project>/addons/ai_studio`.
2. **Project → Project Settings → Plugins** → enable **AI Studio**.
3. Pick a provider and paste an API key in the **Model** tab, press *Refresh models*, choose a
   model — or simply type any model id the endpoint knows.
4. Chat in the **Chat** tab. Agent mode lets the model call tools (with approval); Chat mode is
   a plain conversation.

The plugin only loads from `addons/ai_studio/plugin.cfg`. If it does not show up in
**Project → Project Settings → Plugins**, the folder ended up one level too deep — the path has to
be `<project>/addons/ai_studio/`.

## Using 9Router (or any router with combo names)

[9Router](https://github.com/decolua/9router) is a self-hosted OpenAI-compatible gateway with
fallback chains ("combos"):

1. **Model → Provider → 9Router (local gateway)** — base URL is pre-filled with
   `http://localhost:20128/v1`. (`http://localhost:20128` alone also works; `/v1` is added for you.)
2. Paste the key from the 9Router dashboard.
3. In **Model ID** type a routed model (`kr/claude-sonnet-4.5`) or **the name of your combo**
   (`premium-coding`, `free-combo`, …) and press **Enter**. Then press **Test** — `OK` means the
   key, model and routing all work.
4. *Refresh models* lists the models and combos the gateway reports; a combo it does not list can
   still be typed in, nothing has to be discovered first.

The **Custom (OpenAI-compatible)** provider does the same thing if you prefer to keep it separate:
base URL `http://localhost:20128/v1`, your key, combo name as the model.

Full provider table, environment variables, troubleshooting (`401`, `404`, `stream_options`,
tool-support fallbacks) and the `.ai_studio.json` rules:
[`addons/ai_studio/docs/providers.md`](addons/ai_studio/docs/providers.md).

## Verify the install

```bash
AI_STUDIO_SMOKE_TEST=1 godot --headless --editor --path /path/to/project
```

Prints one line per check and exits 0 when the plugin is healthy. With
`AI_STUDIO_SMOKE_TEST_SCENE=res://level.tscn` it also opens that scene and drives the editing
tools (nodes, material, physics, camera, lighting, save) before reporting.

## Where things are stored

* Settings and API keys: `user://ai_studio/config.cfg` (never inside your project)
* Conversations: `user://ai_studio/sessions/`
* Screenshots taken by the model: `user://ai_studio/shots/`
* Optional team-shared, non-secret settings: `res://.ai_studio.json` — it cannot set API keys,
  the system prompt or approval settings, and MCP servers defined there only start after you tick
  *Trust this project's servers* on the MCP tab.

## Layout

```
addons/ai_studio/
├── ai_studio_plugin.gd     EditorPlugin entry point (dock, services, smoke test)
├── core/                   config, LLM client + SSE streaming, providers, MCP (stdio/HTTP)
├── core/agent/             agent loop, editor context, built-in Godot tools
├── runtime/                game bridge server (autoload, runs only in editor-launched games)
├── ui/                     dock, chat view, model settings, MCP view
├── docs/providers.md       providers, 9Router, environment variables
└── docs/tools.md           every built-in tool, the game bridge, safety rules
```

Built-in tools cover scenes and files, the class reference, rigs (bone maps, animation
retargeting), materials, physics, lighting and import settings, scene files and resources on
disk, animation renaming (including names inside imported models, with reference updates)
and in-place animation fixes, a one-off editor script runner and the editor error log, script
validation, autoloads, input map, layers, plugins, translations, export presets,
exports and CI files, plus 110 runtime `game_*` commands that inspect and drive the running game
(ported from [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp), MIT). MCP servers add
theirs on top. See [`addons/ai_studio/docs/tools.md`](addons/ai_studio/docs/tools.md).

## Changes in this revision

* The godot-mcp tool set now runs natively inside the plugin, with no Node.js server and no
  extra Godot processes: 28 editor tools for scene files, resources, scripts and project
  configuration, and a game bridge with 110 runtime commands (see `docs/tools.md`).
* Animation-name tools: rename animations/libraries/SpriteFrames and every reference, fix names
  inside imported models via a generated post-import script, edit animations in place (track
  paths, bones, broken tracks, loop, speed, copy/move), plus `godot_run_editor_script` and
  `godot_editor_log`.

* 9Router preset added; arbitrary model ids, router aliases and combo names are saved reliably
  (Enter, focus loss or *Use typed model*) and kept per provider.
* Base URLs without a path get `/v1` appended, and the normalised value is shown.
* Requests that an endpoint rejects (`stream_options`, `tools`, `temperature`) are retried
  automatically and the choice is remembered per provider.
* Project-shipped MCP servers no longer start without consent; `.ai_studio.json` can no longer
  change API keys, the system prompt or approval settings.
* Session/config fixes: `mcp/servers` sections can no longer shadow each other, project overrides
  are actually applied, `chmod` only runs when a key is stored, `join()` honours its timeout,
  `is_waiting_for_approval()` reports the real state.
