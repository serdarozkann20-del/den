@tool
class_name AIStudioLLMClient
extends Node

## Provider-agnostic chat client with streaming and tool-calling support.
##
## Wire formats implemented (see AIStudioProviders.PROVIDERS[...]["api"]):
##   * openai    - POST /chat/completions with `stream: true` (SSE)
##   * anthropic - POST /messages          (SSE, Anthropic event types)
##   * gemini    - POST /models/{m}:streamGenerateContent?alt=sse
##
## The client keeps one canonical message format (the OpenAI one) and converts
## on the way out, so the agent loop only ever deals with a single shape:
##
##   {"role": "user"|"assistant"|"system"|"tool",
##    "content": "text",
##    "tool_calls": [{"id": String, "name": String, "arguments": Dictionary}],
##    "tool_call_id": String}

signal text_delta(text: String)
signal thinking_delta(text: String)
signal tool_call_announced(name: String)
signal stream_finished(result: Dictionary)

var config: AIStudioConfig

var _stream: AIStudioHttpStream
var _active := false


func _init(cfg: AIStudioConfig) -> void:
	config = cfg


func is_busy() -> bool:
	return _active


func cancel() -> void:
	if _stream != null:
		_stream.cancel()


# ---------------------------------------------------------------------------
# Model discovery
# ---------------------------------------------------------------------------

## Lists models offered by the provider. Returns
## {"ok": bool, "models": PackedStringArray, "error": String}
func list_models(provider_id: String = "", timeout_sec: float = 30.0) -> Dictionary:
	var pid := provider_id if not provider_id.is_empty() else config.get_provider_id()
	var info := AIStudioProviders.get_info(pid)
	var base := config.base_url(pid)
	var api := AIStudioProviders.api_of(pid)
	var headers := _auth_headers(pid)
	var models_path := "/models"
	if api == "gemini":
		models_path = "/models"
	var url := base + models_path
	if api == "gemini":
		# Gemini accepts the key as a header, which keeps it out of logs/URLs.
		headers["x-goog-api-key"] = config.resolve_api_key(pid)

	var fetch := AIStudioFetch.new()
	add_child(fetch)
	var res: Dictionary = await fetch.fetch_json(url, HTTPClient.METHOD_GET, headers, "", timeout_sec)
	fetch.queue_free()

	if not bool(res["ok"]):
		var msg := String(res["error"])
		if int(res["status"]) == 401 or int(res["status"]) == 403:
			msg = "Authentication failed (HTTP %d). Check the API key for '%s'." % [int(res["status"]), info.get("label", pid)]
		return {"ok": false, "models": PackedStringArray(), "error": msg}

	var models := PackedStringArray()
	var json = res["json"]
	if api == "gemini":
		for m in (json.get("models", []) if typeof(json) == TYPE_DICTIONARY else []):
			var name := String(m.get("name", "")).trim_prefix("models/")
			if name.is_empty():
				continue
			var methods: Array = m.get("supportedGenerationMethods", [])
			if methods.is_empty() or methods.has("generateContent"):
				models.append(name)
	else:
		var arr = json.get("data", []) if typeof(json) == TYPE_DICTIONARY else []
		for m in arr:
			if typeof(m) == TYPE_DICTIONARY:
				var mid := String(m.get("id", m.get("name", "")))
				if mid.is_empty():
					continue
				models.append(mid)
			elif typeof(m) == TYPE_STRING:
				models.append(String(m))
	models.sort()
	return {"ok": true, "models": models, "error": ""}


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------

## Streams a chat completion. Await the returned Dictionary:
##   {ok, text, thinking, tool_calls: Array, finish_reason, usage: Dictionary,
##    error, status, provider, model}
func stream_chat(messages: Array, tools: Array = [], opts: Dictionary = {}) -> Dictionary:
	var pid := String(opts.get("provider", config.get_provider_id()))
	var model := String(opts.get("model", config.get_model()))
	var api := AIStudioProviders.api_of(pid)
	var base := config.base_url(pid)
	var api_key := config.resolve_api_key(pid)
	var stream := bool(opts.get("stream", config.get_value("general", "stream", true)))
	var timeout := float(opts.get("timeout_sec", config.get_value("general", "request_timeout_sec", 180)))
	var temperature := float(opts.get("temperature", config.get_value("general", "temperature", 0.4)))
	var max_tokens := int(opts.get("max_tokens", config.get_value("general", "max_tokens", 0)))
	var extra_headers: Dictionary = opts.get("extra_headers", {})

	var info := AIStudioProviders.get_info(pid)
	if bool(info.get("needs_key", true)) and api_key.is_empty():
		var fail := _fail("No API key configured for '%s'. Open AI Studio -> Settings." % info.get("label", pid))
		return fail
	if model.strip_edges().is_empty():
		var fail2 := _fail("No model selected for '%s'. Open AI Studio -> Settings and pick one (Refresh loads the live list)." % info.get("label", pid))
		return fail2

	# Gateways differ in which optional fields they accept; a router such as
	# 9Router forwards to upstreams that are stricter than OpenAI itself. Start
	# with everything and drop what the endpoint rejects, remembering the
	# decision per provider so the extra round trip happens only once.
	var flags := _request_flags(pid)
	var attempts := 0
	var notes := PackedStringArray()

	while true:
		var builder := _build_request(pid, base, api, api_key, model, messages, tools, stream,
			temperature, max_tokens, extra_headers, opts, flags)
		if not builder["ok"]:
			_fail_emit(String(builder["error"]))
			return _fail(String(builder["error"]))

		var outcome := await _send_once(builder, api, stream, timeout)
		var result: Dictionary = outcome["result"]
		result["provider"] = pid
		result["model"] = model
		if bool(outcome["ok"]):
			if not notes.is_empty():
				result["note"] = ", ".join(notes)
			stream_finished.emit(result)
			return result

		var drop := _next_degradation(int(outcome["status"]), String(result.get("error", "")), flags)
		if drop.is_empty() or attempts >= 3:
			if not notes.is_empty():
				result["note"] = ", ".join(notes)
			stream_finished.emit(result)
			return result
		# Retry: remember the dropped field, drop it and try once more.
		flags[drop] = false
		_set_flag(pid, drop, false)
		notes.append(_degradation_note(drop))
		attempts += 1


## One HTTP attempt with a request that is already built.
## Returns {"ok": bool, "status": int, "result": Dictionary}.
func _send_once(builder: Dictionary, api: String, stream: bool, timeout: float) -> Dictionary:
	var state := _new_state(api)
	var result: Dictionary
	_active = true

	if not stream:
		# Non-streaming: one request, parse the whole body at once.
		var fetch := AIStudioFetch.new()
		add_child(fetch)
		var res: Dictionary = await fetch.fetch_json(
			String(builder["url"]), HTTPClient.METHOD_POST, builder["headers"],
			JSON.stringify(builder["body"]), timeout,
			"application/json, text/event-stream")
		fetch.queue_free()
		if bool(res["ok"]) and res["json"] != null:
			_ingest_non_streaming(api, res["json"], state)
			_finalize(api, state)
			result = state["result"]
		else:
			result = _handle_http_failure(int(res["status"]), String(res["body"]), String(res["error"]), state)
		_active = false
		return {"ok": bool(result.get("ok", false)), "status": int(result.get("status", 0)), "result": result}

	_stream = AIStudioHttpStream.new()
	_stream.payload.connect(_on_payload.bind(state))
	_stream.start(String(builder["url"]), _header_array(builder["headers"]), JSON.stringify(builder["body"]),
		{"timeout_sec": timeout, "mode": AIStudioHttpStream.MODE_SSE})
	var http_result: Dictionary
	if _stream.is_done:
		http_result = _stream.result
	else:
		http_result = await _stream.finished
	_stream.join()
	_stream = null
	_active = false

	if not bool(http_result.get("ok", false)):
		result = _handle_http_failure(int(http_result.get("status", 0)), String(http_result.get("body", "")),
			String(http_result.get("error", "")), state)
	else:
		result = state["result"]
		_finalize(api, state)
	return {"ok": bool(result.get("ok", false)), "status": int(result.get("status", 0)), "result": result}


# ---------------------------------------------------------------------------
# Optional-field fallbacks
# ---------------------------------------------------------------------------

## Which optional parts of a request this provider still accepts. Anything the
## endpoint rejected before is remembered in the config and skipped from then on.
func _request_flags(pid: String) -> Dictionary:
	return {
		"stream_options": not bool(config.get_provider_field(pid, "omit_stream_options", false)),
		"tools": not bool(config.get_provider_field(pid, "omit_tools", false)),
		"temperature": not bool(config.get_provider_field(pid, "omit_temperature", false)),
	}


func _set_flag(pid: String, name: String, value: bool) -> void:
	config.set_provider_field(pid, "omit_" + name, not value, false)
	config.save()


## Decides what to retry without, based on the HTTP status and the provider's own
## error message. Returns "" when retrying cannot help.
func _next_degradation(status: int, message: String, flags: Dictionary) -> String:
	if status != 400 and status != 404 and status != 422:
		return ""
	var text := message.to_lower()
	var candidates := [
		{"flag": "stream_options", "needles": ["stream_options", "include_usage", "unknown field", "unrecognized field", "unsupported parameter"]},
		{"flag": "tools", "needles": ["tool_choice", "\"tools\"", "tools:", "function calling", "tool calling", "tools are not supported", "does not support tools"]},
		{"flag": "temperature", "needles": ["temperature"]},
	]
	for candidate in candidates:
		var flag := String(candidate["flag"])
		if not bool(flags.get(flag, true)):
			continue
		for needle in candidate["needles"] as Array:
			if text.contains(String(needle)):
				return flag
	return ""


func _degradation_note(drop: String) -> String:
	match drop:
		"stream_options":
			return "provider rejects stream_options/include_usage, retrying without it"
		"tools":
			return "provider rejects the tool definitions, retrying without tools (agent tools unavailable for this model)"
		"temperature":
			return "provider rejects 'temperature', retrying without it"
	return "retrying with a reduced request"



func _fail(message: String) -> Dictionary:
	_fail_emit(message)
	return {
		"ok": false, "text": "", "thinking": "", "tool_calls": [], "finish_reason": "error",
		"usage": {}, "error": message, "status": 0, "provider": "", "model": "",
	}


func _fail_emit(message: String) -> void:
	stream_finished.emit(_fail(message))


func _handle_http_failure(status: int, body: String, error: String, state: Dictionary) -> Dictionary:
	# Surface server-side error messages verbatim - they are the most useful
	# thing an API can give us (bad model id, quota, content filter, ...).
	var detail := ""
	var parsed = JSON.parse_string(body)
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error"):
			var e = parsed["error"]
			if typeof(e) == TYPE_DICTIONARY:
				detail = String(e.get("message", JSON.stringify(e)))
			else:
				detail = String(e)
		elif parsed.has("message"):
			detail = String(parsed["message"])
	if detail.is_empty():
		detail = body.strip_edges().substr(0, 500)
	if detail.is_empty():
		detail = error
	var msg := "HTTP %d: %s" % [status, detail] if status > 0 else error
	var out: Dictionary = state["result"]
	out["ok"] = false
	out["error"] = msg
	out["status"] = status
	return out


# ---------------------------------------------------------------------------
# Request building
# ---------------------------------------------------------------------------

func _build_request(pid: String, base: String, api: String, api_key: String, model: String,
		messages: Array, tools: Array, stream: bool, temperature: float, max_tokens: int,
		extra_headers: Dictionary, opts: Dictionary, flags: Dictionary) -> Dictionary:
	var headers := _auth_headers(pid)
	headers["Content-Type"] = "application/json"
	for k in extra_headers.keys():
		headers[k] = extra_headers[k]
	if stream:
		headers["Accept"] = "text/event-stream"
	else:
		headers["Accept"] = "application/json"

	match api:
		"anthropic":
			var body := _anthropic_body(model, messages, tools, stream, temperature, max_tokens, flags)
			return {"ok": true, "url": base + "/messages", "headers": headers, "body": body}
		"gemini":
			var gbody := _gemini_body(messages, tools, temperature, max_tokens, flags)
			var key := api_key
			if not key.is_empty():
				headers["x-goog-api-key"] = key
			var path := "/models/%s:%s" % [model, "streamGenerateContent?alt=sse" if stream else "generateContent"]
			return {"ok": true, "url": base + path, "headers": headers, "body": gbody}
		_:
			var body := _openai_body(model, messages, tools, stream, temperature, max_tokens, flags)
			return {"ok": true, "url": base + "/chat/completions", "headers": headers, "body": body}


func _auth_headers(pid: String) -> Dictionary:
	var info := AIStudioProviders.get_info(pid)
	var headers := config.extra_headers(pid)
	var key := config.resolve_api_key(pid)
	match String(info.get("auth", "bearer")):
		"x-api-key":
			if not key.is_empty():
				headers["x-api-key"] = key
		"query_key":
			# Gemini accepts x-goog-api-key; avoids putting the key in the URL.
			if not key.is_empty():
				headers["x-goog-api-key"] = key
		_:
			if not key.is_empty():
				headers["Authorization"] = "Bearer " + key
	if not headers.has("User-Agent"):
		headers["User-Agent"] = "Godot-AI-Studio/1.0 (+godot %s)" % Engine.get_version_info().get("string", "")
	return headers


func _openai_body(model: String, messages: Array, tools: Array, stream: bool, temperature: float,
		max_tokens: int, flags: Dictionary = {}) -> Dictionary:
	var out_messages: Array = []
	for m in messages:
		out_messages.append(_to_openai_message(m))
	var body := {
		"model": model,
		"messages": out_messages,
		"stream": stream,
	}
	if temperature >= 0.0 and bool(flags.get("temperature", true)):
		body["temperature"] = temperature
	if max_tokens > 0:
		body["max_tokens"] = max_tokens
	if not tools.is_empty() and bool(flags.get("tools", true)):
		body["tools"] = tools
		body["tool_choice"] = "auto"
	if stream and bool(flags.get("stream_options", true)):
		# Usage in the final chunk. Endpoints that do not understand the field
		# are retried without it - see _next_degradation().
		body["stream_options"] = {"include_usage": true}
	return body


func _to_openai_message(m: Dictionary) -> Dictionary:
	var role := String(m.get("role", "user"))
	var out := {"role": role}
	match role:
		"tool":
			out["role"] = "tool"
			out["content"] = _content_to_string(m.get("content", ""))
			out["tool_call_id"] = String(m.get("tool_call_id", ""))
			return out
		"assistant":
			out["content"] = _content_to_string(m.get("content", ""))
			var calls: Array = m.get("tool_calls", [])
			if not calls.is_empty():
				var oai_calls: Array = []
				for c in calls:
					oai_calls.append({
						"id": String(c.get("id", "")),
						"type": "function",
						"function": {
							"name": String(c.get("name", "")),
							"arguments": JSON.stringify(c.get("arguments", {})),
						},
					})
				out["tool_calls"] = oai_calls
				if String(out["content"]).is_empty():
					out["content"] = null
			return out
		_:
			out["content"] = _content_to_string(m.get("content", ""))
			return out


func _anthropic_body(model: String, messages: Array, tools: Array, stream: bool, temperature: float,
		max_tokens: int, flags: Dictionary = {}) -> Dictionary:
	var system := ""
	var out_messages: Array = []
	for m in messages:
		var role := String(m.get("role", "user"))
		if role == "system":
			var s := _content_to_string(m.get("content", ""))
			system = s if system.is_empty() else system + "\n\n" + s
			continue
		if role == "assistant":
			var blocks: Array = []
			var text := _content_to_string(m.get("content", ""))
			if not text.is_empty():
				blocks.append({"type": "text", "text": text})
			for c in m.get("tool_calls", []) as Array:
				blocks.append({
					"type": "tool_use",
					"id": String(c.get("id", "")),
					"name": String(c.get("name", "")),
					"input": c.get("arguments", {}),
				})
			if blocks.is_empty():
				blocks.append({"type": "text", "text": "(no content)"})
			out_messages.append({"role": "assistant", "content": blocks})
		elif role == "tool":
			out_messages.append({
				"role": "user",
				"content": [{
					"type": "tool_result",
					"tool_use_id": String(m.get("tool_call_id", "")),
					"content": _content_to_string(m.get("content", "")),
				}],
			})
		else:
			out_messages.append({"role": "user", "content": _anthropic_user_content(m.get("content", ""))})

	# Anthropic requires strictly alternating roles; merge consecutive same-role turns.
	out_messages = _merge_consecutive(out_messages)

	var body := {
		"model": model,
		"messages": out_messages,
		"max_tokens": max_tokens if max_tokens > 0 else 8192,
		"stream": stream,
	}
	if not system.is_empty():
		body["system"] = system
	if temperature >= 0.0 and bool(flags.get("temperature", true)):
		body["temperature"] = temperature
	if not tools.is_empty() and bool(flags.get("tools", true)):
		var atools: Array = []
		for t in tools:
			if String(t.get("type", "")) == "function":
				var fn: Dictionary = t.get("function", {})
				atools.append({
					"name": String(fn.get("name", "")),
					"description": String(fn.get("description", "")),
					"input_schema": fn.get("parameters", {"type": "object", "properties": {}}),
				})
		if not atools.is_empty():
			body["tools"] = atools
	return body


func _anthropic_user_content(content: Variant) -> Variant:
	if typeof(content) == TYPE_ARRAY:
		var blocks: Array = []
		for part in content:
			if typeof(part) != TYPE_DICTIONARY:
				continue
			if String(part.get("type", "")) == "image":
				blocks.append(part.get("anthropic", part))
			else:
				blocks.append({"type": "text", "text": String(part.get("text", ""))})
		if not blocks.is_empty():
			return blocks
	return _content_to_string(content)


func _merge_consecutive(messages: Array) -> Array:
	var out: Array = []
	for m in messages:
		if not out.is_empty() and String(out[out.size() - 1].get("role")) == String(m.get("role")):
			var prev: Dictionary = out[out.size() - 1]
			var a: Array = prev["content"] if typeof(prev["content"]) == TYPE_ARRAY else [{"type": "text", "text": String(prev["content"])}]
			var b: Array = m["content"] if typeof(m["content"]) == TYPE_ARRAY else [{"type": "text", "text": String(m["content"])}]
			prev["content"] = a + b
		else:
			out.append(m)
	return out


func _gemini_body(messages: Array, tools: Array, temperature: float, max_tokens: int, flags: Dictionary = {}) -> Dictionary:
	var contents: Array = []
	var system_text := ""
	var pending_function_responses: Array = []
	for m in messages:
		var role := String(m.get("role", "user"))
		if role == "system":
			var s := _content_to_string(m.get("content", ""))
			system_text = s if system_text.is_empty() else system_text + "\n\n" + s
			continue
		if role == "tool":
			pending_function_responses.append({
				"functionResponse": {
					"name": String(m.get("name", "tool")),
					"response": {"result": _content_to_string(m.get("content", ""))},
				},
			})
			contents.append({"role": "user", "parts": pending_function_responses.duplicate(true)})
			pending_function_responses.clear()
			continue
		if role == "assistant":
			var parts: Array = []
			var text := _content_to_string(m.get("content", ""))
			if not text.is_empty():
				parts.append({"text": text})
			for c in m.get("tool_calls", []) as Array:
				parts.append({"functionCall": {"name": String(c.get("name", "")), "args": c.get("arguments", {})}})
			if parts.is_empty():
				parts.append({"text": "(no content)"})
			contents.append({"role": "model", "parts": parts})
			continue
		contents.append({"role": "user", "parts": _gemini_parts(m.get("content", ""))})

	var body := {"contents": contents}
	if not system_text.is_empty():
		body["systemInstruction"] = {"parts": [{"text": system_text}]}
	var decls: Array = []
	if bool(flags.get("tools", true)):
		for t in tools:
			if String(t.get("type", "")) == "function":
				var fn: Dictionary = t.get("function", {})
				decls.append({
					"name": String(fn.get("name", "")),
					"description": String(fn.get("description", "")),
					"parameters": _gemini_schema(fn.get("parameters", {"type": "object", "properties": {}})),
				})
	if not decls.is_empty():
		body["tools"] = [{"functionDeclarations": decls}]
	var gen: Dictionary = {}
	if temperature >= 0.0 and bool(flags.get("temperature", true)):
		gen["temperature"] = temperature
	if max_tokens > 0:
		gen["maxOutputTokens"] = max_tokens
	if not gen.is_empty():
		body["generationConfig"] = gen
	return body


func _gemini_parts(content: Variant) -> Array:
	if typeof(content) == TYPE_ARRAY:
		var parts: Array = []
		for p in content:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			if String(p.get("type", "")) == "image" and p.has("gemini"):
				parts.append(p["gemini"])
			else:
				parts.append({"text": String(p.get("text", ""))})
		if not parts.is_empty():
			return parts
	return [{"text": _content_to_string(content)}]


## Gemini's schema dialect does not accept every JSON-Schema keyword.
func _gemini_schema(schema: Variant) -> Variant:
	if typeof(schema) != TYPE_DICTIONARY:
		return {"type": "object", "properties": {}}
	var out := {}
	for key in (schema as Dictionary).keys():
		if key in ["$schema", "additionalProperties", "strict", "title", "default", "examples"]:
			continue
		var v = schema[key]
		if key == "properties" and typeof(v) == TYPE_DICTIONARY:
			var props := {}
			for pname in v.keys():
				props[pname] = _gemini_schema(v[pname])
			out["properties"] = props
		elif key == "items":
			out["items"] = _gemini_schema(v)
		else:
			out[key] = v
	return out


func _content_to_string(content: Variant) -> String:
	if typeof(content) == TYPE_STRING:
		return content
	if typeof(content) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for p in content:
			if typeof(p) == TYPE_DICTIONARY:
				if p.has("text"):
					parts.append(String(p["text"]))
				elif String(p.get("type", "")) == "image":
					parts.append("[image]")
			else:
				parts.append(String(p))
		return "\n".join(parts)
	if content == null:
		return ""
	return String(content)


func _header_array(headers: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in headers.keys():
		out.append("%s: %s" % [String(k), String(headers[k])])
	return out


# ---------------------------------------------------------------------------
# Stream state / parsing
# ---------------------------------------------------------------------------

func _new_state(api: String) -> Dictionary:
	return {
		"api": api,
		"text": "",
		"thinking": "",
		"tool_calls": {},      # index -> {id, name, arguments_json}
		"tool_order": [],
		"finish_reason": "",
		"usage": {},
		"done": false,
		"result": {
			"ok": true, "text": "", "thinking": "", "tool_calls": [], "finish_reason": "",
			"usage": {}, "error": "", "status": 200, "provider": "", "model": "",
		},
	}


func _on_payload(raw: String, state: Dictionary) -> void:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return
	if trimmed == "[DONE]":
		state["done"] = true
		return
	var json = JSON.parse_string(trimmed)
	if typeof(json) != TYPE_DICTIONARY:
		return
	match String(state["api"]):
		"anthropic":
			_parse_anthropic(json, state)
		"gemini":
			_parse_gemini(json, state)
		_:
			_parse_openai(json, state)


func _parse_openai(json: Dictionary, state: Dictionary) -> void:
	if json.has("error"):
		var e = json["error"]
		var msg := String(e.get("message", JSON.stringify(e))) if typeof(e) == TYPE_DICTIONARY else String(e)
		state["result"]["ok"] = false
		state["result"]["error"] = msg
		return
	if json.has("usage") and typeof(json["usage"]) == TYPE_DICTIONARY:
		state["usage"] = json["usage"]
	var choices: Array = json.get("choices", [])
	if choices.is_empty():
		return
	var choice: Dictionary = choices[0]
	var delta: Dictionary = choice.get("delta", choice.get("message", {}))
	var content = delta.get("content", null)
	if typeof(content) == TYPE_STRING and not content.is_empty():
		state["text"] += content
		text_delta.emit(content)
	elif typeof(content) == TYPE_ARRAY:
		# Some gateways stream content as parts.
		for part in content:
			if typeof(part) == TYPE_DICTIONARY and part.has("text"):
				var t := String(part["text"])
				state["text"] += t
				text_delta.emit(t)
	for rkey in ["reasoning_content", "reasoning", "reasoning_text"]:
		var rt = delta.get(rkey, null)
		if typeof(rt) == TYPE_STRING and not rt.is_empty():
			state["thinking"] += rt
			thinking_delta.emit(rt)
	for tc in delta.get("tool_calls", []) as Array:
		var index := int(tc.get("index", 0))
		if not state["tool_calls"].has(index):
			state["tool_calls"][index] = {"id": "", "name": "", "arguments_json": ""}
			state["tool_order"].append(index)
		var entry: Dictionary = state["tool_calls"][index]
		if tc.has("id") and not String(tc["id"]).is_empty():
			entry["id"] = String(tc["id"])
		var fn: Dictionary = tc.get("function", {})
		if fn.has("name") and not String(fn["name"]).is_empty():
			if String(entry["name"]).is_empty():
				entry["name"] = String(fn["name"])
				tool_call_announced.emit(String(fn["name"]))
			else:
				entry["name"] += String(fn["name"])
		if fn.has("arguments"):
			entry["arguments_json"] += String(fn["arguments"])
	var fr = choice.get("finish_reason", null)
	if fr != null and not String(fr).is_empty():
		state["finish_reason"] = String(fr)


func _parse_anthropic(json: Dictionary, state: Dictionary) -> void:
	var type := String(json.get("type", ""))
	match type:
		"error":
			var err: Dictionary = json.get("error", {})
			state["result"]["ok"] = false
			state["result"]["error"] = String(err.get("message", JSON.stringify(err)))
		"message_start":
			var msg: Dictionary = json.get("message", {})
			if msg.has("usage"):
				state["usage"] = msg["usage"]
		"content_block_start":
			var index := int(json.get("index", 0))
			var block: Dictionary = json.get("content_block", {})
			if String(block.get("type", "")) == "tool_use":
				state["tool_calls"][index] = {
					"id": String(block.get("id", "")),
					"name": String(block.get("name", "")),
					"arguments_json": "",
				}
				state["tool_order"].append(index)
				tool_call_announced.emit(String(block.get("name", "")))
			elif String(block.get("type", "")) == "text" and not String(block.get("text", "")).is_empty():
				var t0 := String(block["text"])
				state["text"] += t0
				text_delta.emit(t0)
		"content_block_delta":
			var index2 := int(json.get("index", 0))
			var delta: Dictionary = json.get("delta", {})
			match String(delta.get("type", "")):
				"text_delta":
					var t := String(delta.get("text", ""))
					if not t.is_empty():
						state["text"] += t
						text_delta.emit(t)
				"thinking_delta":
					var th := String(delta.get("thinking", ""))
					if not th.is_empty():
						state["thinking"] += th
						thinking_delta.emit(th)
				"input_json_delta":
					if state["tool_calls"].has(index2):
						state["tool_calls"][index2]["arguments_json"] += String(delta.get("partial_json", ""))
		"message_delta":
			var d: Dictionary = json.get("delta", {})
			if d.has("stop_reason") and not String(d["stop_reason"]).is_empty():
				state["finish_reason"] = String(d["stop_reason"])
			if json.has("usage") and typeof(json["usage"]) == TYPE_DICTIONARY:
				var u: Dictionary = state["usage"]
				for k in (json["usage"] as Dictionary).keys():
					u[k] = json["usage"][k]
				state["usage"] = u
		"message_stop":
			state["done"] = true


func _parse_gemini(json: Dictionary, state: Dictionary) -> void:
	if json.has("error"):
		var e: Dictionary = json["error"]
		state["result"]["ok"] = false
		state["result"]["error"] = String(e.get("message", JSON.stringify(e)))
		return
	if json.has("usageMetadata"):
		state["usage"] = json["usageMetadata"]
	for cand in json.get("candidates", []) as Array:
		var content: Dictionary = cand.get("content", {})
		for part in content.get("parts", []) as Array:
			if part.has("text") and String(part["text"]) != "":
				var t := String(part["text"])
				state["text"] += t
				text_delta.emit(t)
			if part.has("thought") and bool(part["thought"]):
				state["thinking"] += String(part.get("text", ""))
			if part.has("functionCall"):
				var fc: Dictionary = part["functionCall"]
				var idx: int = (state["tool_calls"] as Dictionary).size()
				state["tool_calls"][idx] = {
					"id": "call_%d_%s" % [idx, String(fc.get("name", ""))],
					"name": String(fc.get("name", "")),
					"arguments_json": JSON.stringify(fc.get("args", {})),
				}
				state["tool_order"].append(idx)
				tool_call_announced.emit(String(fc.get("name", "")))
		if cand.has("finishReason") and not String(cand["finishReason"]).is_empty():
			state["finish_reason"] = String(cand["finishReason"]).to_lower()


func _ingest_non_streaming(api: String, json: Dictionary, state: Dictionary) -> void:
	match api:
		"anthropic":
			if json.has("error"):
				_parse_anthropic({"type": "error", "error": json["error"]}, state)
				return
			state["usage"] = json.get("usage", {})
			state["finish_reason"] = String(json.get("stop_reason", ""))
			for i in (json.get("content", []) as Array).size():
				var block: Dictionary = json["content"][i]
				match String(block.get("type", "")):
					"text":
						var t := String(block.get("text", ""))
						if not t.is_empty():
							state["text"] += t
							text_delta.emit(t)
					"tool_use":
						state["tool_calls"][i] = {
							"id": String(block.get("id", "")),
							"name": String(block.get("name", "")),
							"arguments_json": JSON.stringify(block.get("input", {})),
						}
						state["tool_order"].append(i)
		"gemini":
			_parse_gemini(json, state)
		_:
			if json.has("error"):
				_parse_openai(json, state)
				return
			var choices: Array = json.get("choices", [])
			if choices.is_empty():
				state["result"]["ok"] = false
				state["result"]["error"] = "Provider returned no choices: " + JSON.stringify(json).substr(0, 300)
				return
			var msg: Dictionary = choices[0].get("message", {})
			var content = msg.get("content", "")
			if typeof(content) == TYPE_STRING and not content.is_empty():
				state["text"] += content
				text_delta.emit(content)
			for rkey in ["reasoning_content", "reasoning"]:
				if msg.has(rkey) and String(msg[rkey]) != "":
					state["thinking"] += String(msg[rkey])
			var tcs: Array = msg.get("tool_calls", [])
			for i in tcs.size():
				var tc: Dictionary = tcs[i]
				var fn: Dictionary = tc.get("function", {})
				state["tool_calls"][i] = {
					"id": String(tc.get("id", "")),
					"name": String(fn.get("name", "")),
					"arguments_json": String(fn.get("arguments", "{}")),
				}
				state["tool_order"].append(i)
			state["finish_reason"] = String(choices[0].get("finish_reason", ""))
			state["usage"] = json.get("usage", {})


func _finalize(api: String, state: Dictionary) -> void:
	var calls: Array = []
	for index in state["tool_order"]:
		var entry: Dictionary = state["tool_calls"][index]
		var raw := String(entry["arguments_json"]).strip_edges()
		var args: Dictionary = {}
		if raw.is_empty():
			args = {}
		else:
			var parsed = JSON.parse_string(raw)
			if typeof(parsed) == TYPE_DICTIONARY:
				args = parsed
			else:
				args = {"__raw": raw}
		calls.append({
			"id": String(entry["id"]) if not String(entry["id"]).is_empty() else "call_%d" % index,
			"name": String(entry["name"]),
			"arguments": args,
			"raw_arguments": raw,
		})
	var result: Dictionary = state["result"]
	result["text"] = state["text"]
	result["thinking"] = state["thinking"]
	result["tool_calls"] = calls
	result["usage"] = state["usage"]
	if String(result["finish_reason"]).is_empty():
		result["finish_reason"] = state["finish_reason"]
	if String(result["finish_reason"]).is_empty():
		result["finish_reason"] = "tool_calls" if not calls.is_empty() else "stop"
	result["ok"] = bool(result["ok"]) and String(result["error"]).is_empty()
