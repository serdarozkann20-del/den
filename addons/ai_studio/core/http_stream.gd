@tool
class_name AIStudioHttpStream
extends RefCounted

## Streaming HTTP client (Server-Sent Events / NDJSON) running on a worker
## thread so the Godot editor never blocks while tokens arrive.
##
## Usage:
##     var s := AIStudioHttpStream.new()
##     s.payload.connect(_on_payload)          # one JSON string per SSE event
##     s.start(url, headers, body, opts)
##     var result := s.result if s.is_done else await s.finished
##
## The `finished` signal is always emitted on the main thread; `payload` too.
## Everything the model sends is delivered incrementally through `payload`.

signal payload(text: String)
signal finished(result: Dictionary)

const MODE_SSE := "sse"
const MODE_NDJSON := "ndjson"

var is_done: bool = false
var result: Dictionary = {}

var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false
var _url := ""
var _headers: PackedStringArray = PackedStringArray()
var _body := ""
var _method := HTTPClient.METHOD_POST
var _timeout_sec := 180.0
var _mode := MODE_SSE
var _extra_delay_ms := 8


func start(url: String, headers: PackedStringArray, body: String, opts: Dictionary = {}) -> void:
	_url = url
	_headers = headers
	_body = body
	_method = int(opts.get("method", HTTPClient.METHOD_POST))
	_timeout_sec = float(opts.get("timeout_sec", 180.0))
	_mode = String(opts.get("mode", MODE_SSE))
	_timeout_sec = maxf(_timeout_sec, 5.0)
	_thread = Thread.new()
	var err := _thread.start(_run)
	if err != OK:
		_finish({"ok": false, "error": "Could not start worker thread (error %d)." % err, "status": 0, "body": ""})


func cancel() -> void:
	_cancelled = true


## Waits up to `ms` milliseconds for the worker thread to end. Safe to call
## multiple times, and safe to give up: the thread has its own request deadline
## and only touches its local state, so the editor must never block on it.
func join(ms: int = 3000) -> void:
	if _thread == null or not _thread.is_started():
		_thread = null
		return
	var deadline := Time.get_ticks_msec() + maxi(ms, 0)
	while _thread.is_alive() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(2)
	if _thread.is_alive():
		# Still finishing (a slow socket close, typically). Leave it - the result
		# was already delivered through the `finished` signal.
		_thread = null
		return
	_thread.wait_to_finish()
	_thread = null


func _run() -> void:
	var res := {"ok": false, "status": 0, "error": "", "body": "", "headers": PackedStringArray()}
	var parsed := _parse_url(_url)
	if parsed.is_empty():
		res["error"] = "Invalid URL: " + _url
		_finish(res)
		return
	var host := String(parsed["host"])
	var port := int(parsed["port"])
	var path := String(parsed["path"])
	var tls: TLSOptions = null
	if bool(parsed["tls"]):
		tls = TLSOptions.client()

	var client := HTTPClient.new()
	client.set_read_chunk_size(1024)
	var err := client.connect_to_host(host, port, tls)
	if err != OK:
		res["error"] = "connect_to_host failed (%s)" % error_string(err)
		_finish(res)
		return

	var deadline := Time.get_ticks_msec() + int(_timeout_sec * 1000.0)
	while client.get_status() == HTTPClient.STATUS_RESOLVING \
			or client.get_status() == HTTPClient.STATUS_CONNECTING:
		if _cancelled:
			client.close()
			res["error"] = "cancelled"
			_finish(res)
			return
		if Time.get_ticks_msec() > deadline:
			client.close()
			res["error"] = "Timeout while connecting to %s" % host
			_finish(res)
			return
		client.poll()
		OS.delay_msec(_extra_delay_ms)

	if client.get_status() == HTTPClient.STATUS_CONNECTION_ERROR \
			or client.get_status() == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
		res["error"] = "Connection failed to %s:%d (%s)" % [host, port, _status_name(client.get_status())]
		_finish(res)
		return

	err = client.request_raw(_method, path, _headers, _body.to_utf8_buffer())
	if err != OK:
		client.close()
		res["error"] = "request failed (%s)" % error_string(err)
		_finish(res)
		return

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if _cancelled or Time.get_ticks_msec() > deadline:
			client.close()
			res["error"] = "cancelled" if _cancelled else "Timeout while sending request"
			_finish(res)
			return
		client.poll()
		OS.delay_msec(_extra_delay_ms)

	if not client.has_response():
		client.close()
		res["error"] = "No response from server"
		_finish(res)
		return

	res["status"] = client.get_response_code()
	res["headers"] = client.get_response_headers()

	var buffer := PackedByteArray()
	var line_buffer := ""
	var event_data: PackedStringArray = PackedStringArray()
	var body_all := PackedByteArray()

	while true:
		if _cancelled:
			res["error"] = "cancelled"
			client.close()
			_finish(res)
			return
		if Time.get_ticks_msec() > deadline:
			res["error"] = "Timeout waiting for model response (increase 'Request timeout' in Settings)"
			client.close()
			_finish(res)
			return
		var status := client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk := client.read_response_body_chunk()
			if chunk.size() == 0:
				client.poll()
				OS.delay_msec(_extra_delay_ms)
				continue
			body_all.append_array(chunk)
			buffer.append_array(chunk)
			var text := buffer.get_string_from_utf8()
			# get_string_from_utf8 on a partial multi-byte sequence can drop the
			# tail; recover it so we never emit a mangled character.
			var consumed := text.to_utf8_buffer().size()
			if consumed <= buffer.size():
				buffer = buffer.slice(consumed)
			else:
				buffer = PackedByteArray()
			line_buffer += text
			while true:
				var nl := line_buffer.find("\n")
				if nl < 0:
					break
				var line := line_buffer.substr(0, nl)
				line_buffer = line_buffer.substr(nl + 1)
				if line.ends_with("\r"):
					line = line.substr(0, line.length() - 1)
				_handle_line(line, event_data, res)
		elif status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_DISCONNECTED:
			break
		else:
			client.poll()
			OS.delay_msec(_extra_delay_ms)

	# flush trailing line / pending event
	if not line_buffer.is_empty():
		_handle_line(line_buffer, event_data, res)
	_flush_event(event_data, res)

	client.close()
	res["body"] = body_all.get_string_from_utf8()
	res["ok"] = int(res["status"]) >= 200 and int(res["status"]) < 300
	if not res["ok"] and String(res["error"]).is_empty():
		res["error"] = "HTTP %d" % int(res["status"])
	_finish(res)


func _handle_line(line: String, event_data: PackedStringArray, res: Dictionary) -> void:
	if _mode == MODE_NDJSON:
		var t := line.strip_edges()
		if not t.is_empty():
			_emit_payload(t)
		return
	# SSE framing
	if line.is_empty():
		_flush_event(event_data, res)
		return
	if line.begins_with(":"):
		return  # comment / keep-alive
	var colon := line.find(":")
	if colon < 0:
		return
	var field := line.substr(0, colon)
	var value := line.substr(colon + 1)
	if value.begins_with(" "):
		value = value.substr(1)
	if field == "data":
		event_data.append(value)
	# "event", "id", "retry" fields are not needed by the providers we support.


func _flush_event(event_data: PackedStringArray, _res: Dictionary) -> void:
	if event_data.is_empty():
		return
	var joined := "\n".join(event_data)
	event_data.clear()
	_emit_payload(joined)


func _emit_payload(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	payload.emit.call_deferred(text)


func _finish(res: Dictionary) -> void:
	is_done = true
	result = res
	finished.emit.call_deferred(res)


static func _status_name(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED: return "disconnected"
		HTTPClient.STATUS_RESOLVING: return "resolving"
		HTTPClient.STATUS_CONNECTING: return "connecting"
		HTTPClient.STATUS_CONNECTED: return "connected"
		HTTPClient.STATUS_REQUESTING: return "requesting"
		HTTPClient.STATUS_BODY: return "body"
		HTTPClient.STATUS_CONNECTION_ERROR: return "connection error"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: return "TLS handshake error"
	return "unknown"


## Minimal URL splitter (no dependency on RegEx, works for http/https).
static func _parse_url(url: String) -> Dictionary:
	var u := url.strip_edges()
	var tls := false
	if u.begins_with("https://"):
		tls = true
		u = u.substr(8)
	elif u.begins_with("http://"):
		u = u.substr(7)
	else:
		return {}
	var slash := u.find("/")
	var host_port := u if slash < 0 else u.substr(0, slash)
	var path := "/" if slash < 0 else u.substr(slash)
	var port := 443 if tls else 80
	var at := host_port.rfind("@")
	if at >= 0:
		host_port = host_port.substr(at + 1)
	var colon := host_port.rfind(":")
	if colon > 0 and not host_port.substr(colon + 1).contains("]"):
		var maybe_port := host_port.substr(colon + 1)
		if maybe_port.is_valid_int():
			port = maybe_port.to_int()
			host_port = host_port.substr(0, colon)
	if host_port.is_empty():
		return {}
	return {"host": host_port, "port": port, "path": path, "tls": tls}
