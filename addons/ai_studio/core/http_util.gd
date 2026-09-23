@tool
class_name AIStudioFetch
extends Node

## Small async JSON fetch helper built on HTTPRequest (main-thread friendly).
## Used for non-streaming calls: model discovery and the MCP HTTP transport.
##
##     var f := AIStudioFetch.new()
##     add_child(f)
##     var res := await f.fetch_json(url, HTTPClient.METHOD_GET, headers, "")


func fetch_json(url: String, method: int, headers: Dictionary, body: String = "", timeout_sec: float = 60.0, accept: String = "application/json") -> Dictionary:
	var req := HTTPRequest.new()
	req.use_threads = true
	if timeout_sec > 0.0:
		req.timeout = timeout_sec
	add_child(req)
	# HTTPRequest rejects requests until it has entered the tree and been readied.
	if not req.is_node_ready():
		if is_inside_tree():
			await get_tree().process_frame
		else:
			await req.ready

	var hdr := PackedStringArray()
	for k in headers.keys():
		hdr.append("%s: %s" % [String(k), String(headers[k])])
	if not accept.is_empty():
		hdr.append("Accept: " + accept)

	var err := req.request_raw(url, hdr, method, body.to_utf8_buffer())
	if err != OK:
		req.queue_free()
		return _err("request rejected (%s)" % error_string(err), 0)

	var res: Array = await req.request_completed
	req.queue_free()

	var result_code := int(res[0])
	var response_code := int(res[1])
	var response_headers: PackedStringArray = res[2]
	var raw: PackedByteArray = res[3]
	var text := raw.get_string_from_utf8()

	var out := {
		"ok": false,
		"status": response_code,
		"body": text,
		"json": null,
		"events": [],
		"headers": response_headers,
		"error": "",
	}

	if result_code != HTTPRequest.RESULT_SUCCESS:
		out["error"] = _result_message(result_code)
		return out

	var content_type := ""
	for h in response_headers:
		if String(h).to_lower().begins_with("content-type:"):
			content_type = String(h).to_lower()
			break

	if text.strip_edges().is_empty():
		out["ok"] = response_code >= 200 and response_code < 300
		if not out["ok"]:
			out["error"] = "HTTP %d with an empty body" % response_code
		return out

	if content_type.contains("text/event-stream"):
		out["events"] = parse_sse_events(text)
		if not out["events"].is_empty():
			out["json"] = out["events"][out["events"].size() - 1]
	else:
		var parsed = JSON.parse_string(text)
		if parsed != null:
			out["json"] = parsed
		elif response_code >= 200 and response_code < 300:
			out["error"] = "Response was not valid JSON (first 200 chars): " + text.substr(0, 200)

	out["ok"] = response_code >= 200 and response_code < 300
	if not out["ok"] and String(out["error"]).is_empty():
		out["error"] = "HTTP %d: %s" % [response_code, _short(text)]
	elif out["ok"] and String(out["error"]).is_empty() and out["json"] == null and content_type.contains("json"):
		out["error"] = "Empty or invalid JSON body"
	return out


## Extracts every JSON object carried by an SSE body (used by the MCP
## Streamable HTTP transport, which may answer a POST with an event stream).
static func parse_sse_events(text: String) -> Array:
	var events: Array = []
	var data_lines: PackedStringArray = PackedStringArray()
	for raw_line in text.split("\n"):
		var line := String(raw_line)
		if line.ends_with("\r"):
			line = line.substr(0, line.length() - 1)
		if line.is_empty():
			if not data_lines.is_empty():
				var payload := "\n".join(data_lines)
				data_lines.clear()
				var parsed = JSON.parse_string(payload)
				if parsed != null:
					events.append(parsed)
			continue
		if line.begins_with("data:"):
			var v := line.substr(5)
			if v.begins_with(" "):
				v = v.substr(1)
			data_lines.append(v)
	if not data_lines.is_empty():
		var parsed := JSON.parse_string("\n".join(data_lines))
		if parsed != null:
			events.append(parsed)
	return events


## Optional additional delay could be added for misbehaving servers.
static func _short(text: String) -> String:
	var t := text.strip_edges()
	t = t.replace("\n", " ")
	return t.substr(0, 300)


static func _result_message(code: int) -> String:
	match code:
		HTTPRequest.RESULT_CANT_CONNECT: return "Could not connect (is the server running?)"
		HTTPRequest.RESULT_CANT_RESOLVE: return "Could not resolve host name"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "Connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLS handshake failed"
		HTTPRequest.RESULT_NO_RESPONSE: return "No response from server"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "Response body too large"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: return "Could not decompress response"
		HTTPRequest.RESULT_REQUEST_FAILED: return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "Could not open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "Could not write download file"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "Too many redirects"
		HTTPRequest.RESULT_TIMEOUT: return "Request timed out"
	return "HTTP request error (code %d)" % code


static func _err(message: String, status: int) -> Dictionary:
	return {"ok": false, "status": status, "body": "", "json": null, "events": [], "headers": PackedStringArray(), "error": message}
