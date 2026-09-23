@tool
class_name AIStudioMarkdown
extends RefCounted

## Deliberately small Markdown -> BBCode converter for the chat view. It covers
## what models actually emit: fenced code, inline code, emphasis, headings,
## lists, links and quotes. Anything unknown is passed through as plain text.

const CODE_COLOR := "#9cdcfe"
const HEAD_COLOR := "#e0e0e0"


static func to_bbcode(markdown: String) -> String:
	var out := PackedStringArray()
	var lines := markdown.replace("\r\n", "\n").split("\n")
	var in_code := false
	var code_lang := ""
	var code_lines := PackedStringArray()
	for line in lines:
		var l := String(line)
		if l.strip_edges().begins_with("```"):
			if in_code:
				out.append(_code_block(code_lines, code_lang))
				code_lines = PackedStringArray()
				in_code = false
				code_lang = ""
			else:
				in_code = true
				code_lang = l.strip_edges().trim_prefix("```").strip_edges()
			continue
		if in_code:
			code_lines.append(l)
			continue
		out.append(_inline_line(l))
	if in_code:
		out.append(_code_block(code_lines, code_lang))
	return "\n".join(out)


static func _code_block(lines: PackedStringArray, lang: String) -> String:
	var body := _escape(String("\n".join(lines)))
	var header := ""
	if not lang.is_empty():
		header = "[color=#808080]%s[/color]\n" % _escape(lang)
	# [code] renders monospace and keeps whitespace; [lb]/[rb] escape brackets.
	return "%s[bgcolor=#1e1e1e][code]%s[/code][/bgcolor]" % [header, body]


static func _inline_line(line: String) -> String:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return ""
	# headings
	var level := 0
	while level < 6 and trimmed.begins_with("#"):
		level += 1
		trimmed = trimmed.substr(1)
	if level > 0:
		var title := trimmed.strip_edges()
		var size := 22 - level * 2
		return "[b][color=%s][font_size=%d]%s[/font_size][/color][/b]" % [HEAD_COLOR, size, _inline(title)]
	# horizontal rule
	if trimmed == "---" or trimmed == "***":
		return "[color=#606060]────────────────────────[/color]"
	# block quote
	if trimmed.begins_with(">"):
		return "[i][color=#a0a0a0]│ %s[/color][/i]" % _inline(trimmed.substr(1).strip_edges())
	# lists
	var indent := line.length() - line.lstrip(" \t").length()
	var depth := int(indent / 2)
	if trimmed.begins_with("- ") or trimmed.begins_with("* ") or trimmed.begins_with("+ "):
		return "%s[b]•[/b] %s" % ["  ".repeat(depth), _inline(trimmed.substr(2))]
	var ordered := false
	var dot := trimmed.find(". ")
	if dot > 0 and dot <= 3 and trimmed.substr(0, dot).is_valid_int():
		ordered = true
		return "%s[b]%s.[/b] %s" % ["  ".repeat(depth), trimmed.substr(0, dot), _inline(trimmed.substr(dot + 2))]
	return _inline(line)


## Inline formatting; input is *not* pre-escaped, so escape brackets first.
static func _inline(text: String) -> String:
	var s := _escape(text)
	s = _replace_code_spans(s)
	s = _replace_links(s)
	s = _replace_wrapped(s, "**", "[b]", "[/b]")
	s = _replace_wrapped(s, "__", "[b]", "[/b]")
	s = _replace_wrapped(s, "*", "[i]", "[/i]")
	return s


static func _escape(text: String) -> String:
	# BBCode uses [] for tags, so every literal bracket becomes [lb]/[rb].
	# Done in a single pass: replacing "[" first and "]" second would corrupt
	# the very escape sequences the first replacement just inserted.
	var out := ""
	for i in text.length():
		var c := text.substr(i, 1)
		if c == "[":
			out += "[lb]"
		elif c == "]":
			out += "[rb]"
		else:
			out += c
	return out


static func _replace_code_spans(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		if s[i] == "`":
			var close := s.find("`", i + 1)
			if close > i:
				out += "[code]%s[/code]" % s.substr(i + 1, close - i - 1)
				i = close + 1
				continue
		out += s[i]
		i += 1
	return out


static func _replace_links(s: String) -> String:
	# [label](url) arrives here as [lb]label[rb](url) because _escape() ran
	# first, so look for that shape and turn it into a real BBCode url tag.
	var out := ""
	var i := 0
	while i < s.length():
		if s.substr(i, 4) == "[lb]":
			var close_label := s.find("[rb]", i)
			if close_label > i:
				var after := close_label + 4
				if s.substr(after, 1) == "(":
					var close_url := s.find(")", after)
					if close_url > after:
						var label := s.substr(i + 4, close_label - i - 4)
						var url := s.substr(after + 1, close_url - after - 1)
						out += "[url=%s]%s[/url]" % [url, label]
						i = close_url + 1
						continue
		out += s[i]
		i += 1
	return out


static func _replace_wrapped(s: String, marker: String, open_tag: String, close_tag: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		if s.substr(i, marker.length()) == marker:
			var close := s.find(marker, i + marker.length())
			if close > i + marker.length() - 1 and close > i:
				var inner := s.substr(i + marker.length(), close - i - marker.length())
				if not inner.strip_edges().is_empty() and not inner.contains("\n"):
					out += open_tag + inner + close_tag
					i = close + marker.length()
					continue
		out += s[i]
		i += 1
	return out


## Very small helper for the tool cards: pretty print JSON-ish dictionaries.
static func pretty(value: Variant, max_chars: int = 4000) -> String:
	var text := ""
	if typeof(value) == TYPE_STRING:
		text = value
	else:
		text = JSON.stringify(value, "  ")
	if text.length() > max_chars:
		text = text.substr(0, max_chars) + "\n... [truncated]"
	return text
