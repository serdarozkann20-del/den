@tool
class_name AIStudioJsonRpc
extends RefCounted

## Tiny JSON-RPC 2.0 helper used by the MCP client (spec revision 2025-11-25).

const PARSE_ERROR := -32700
const INVALID_REQUEST := -32600
const METHOD_NOT_FOUND := -32601
const INVALID_PARAMS := -32602
const INTERNAL_ERROR := -32603


static func request(id: int, method: String, params: Dictionary = {}) -> Dictionary:
	var msg := {"jsonrpc": "2.0", "id": id, "method": method}
	if not params.is_empty():
		msg["params"] = params
	return msg


static func make_notification(method: String, params: Dictionary = {}) -> Dictionary:
	var msg := {"jsonrpc": "2.0", "method": method}
	if not params.is_empty():
		msg["params"] = params
	return msg


static func result(id: Variant, value: Variant) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "result": value}


static func error(id: Variant, code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"code": code, "message": message}
	if data != null:
		err["data"] = data
	return {"jsonrpc": "2.0", "id": id, "error": err}


static func is_request(msg: Dictionary) -> bool:
	return msg.has("method") and msg.has("id")


static func is_notification(msg: Dictionary) -> bool:
	return msg.has("method") and not msg.has("id")


static func is_response(msg: Dictionary) -> bool:
	return not msg.has("method") and msg.has("id")


## Normalises a JSON-RPC response into {"ok": bool, "result": Variant, "error": String, "code": int}
static func unwrap(msg: Dictionary) -> Dictionary:
	if msg.has("error"):
		var e = msg["error"]
		if typeof(e) == TYPE_DICTIONARY:
			return {
				"ok": false,
				"result": null,
				"code": int(e.get("code", INTERNAL_ERROR)),
				"error": String(e.get("message", JSON.stringify(e))),
			}
		return {"ok": false, "result": null, "code": INTERNAL_ERROR, "error": String(e)}
	return {"ok": true, "result": msg.get("result", null), "code": 0, "error": ""}
