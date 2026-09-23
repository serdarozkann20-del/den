@tool
class_name AIStudioIcons
extends RefCounted

## The dock icon is generated at runtime instead of shipping an imported image:
## nothing to re-import, nothing to break when the addon is copied around.

static var _plugin_icon: Texture2D = null


static func plugin_icon() -> Texture2D:
	if _plugin_icon != null:
		return _plugin_icon
	# Prefer a hand-made SVG when the project has one (nicer at large sizes).
	if ResourceLoader.exists("res://addons/ai_studio/icon.svg"):
		var texture: Texture2D = load("res://addons/ai_studio/icon.svg")
		if texture is Texture2D:
			_plugin_icon = texture
			return _plugin_icon
	_plugin_icon = _draw_icon(32)
	return _plugin_icon


static func _draw_icon(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var accent := Color("#7aa2f7")
	var accent_dark := Color("#3d59a1")
	var bubble := Rect2i(int(size * 0.09), int(size * 0.16), int(size * 0.82), int(size * 0.58))
	var radius := int(size * 0.14)
	for y in range(bubble.position.y, bubble.end.y):
		for x in range(bubble.position.x, bubble.end.x):
			if _in_rounded_rect(x, y, bubble, radius):
				var edge := y >= bubble.end.y - 2 or x <= bubble.position.x + 1
				image.set_pixel(x, y, accent_dark if edge else accent)
	# speech tail
	var tail_x := int(size * 0.28)
	for i in int(size * 0.16):
		for j in range(0, int(size * 0.14) - i):
			var px := tail_x + i
			var py := bubble.end.y + j
			if px < size and py < size:
				image.set_pixel(px, py, accent_dark if i > 1 else accent)
	# three "chat" dots
	var dot_color := Color(1, 1, 1, 0.92)
	var dot_y := bubble.position.y + int(bubble.size.y * 0.42)
	var dot_radius := maxi(1, int(size * 0.05))
	for k in 3:
		var cx := bubble.position.x + int(bubble.size.x * (0.24 + 0.26 * k))
		_fill_circle(image, Vector2i(cx, dot_y), dot_radius, dot_color)
	return ImageTexture.create_from_image(image)


static func _in_rounded_rect(x: int, y: int, rect: Rect2i, radius: int) -> bool:
	if not rect.has_point(Vector2i(x, y)):
		return false
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x - 1
	var bottom := rect.end.y - 1
	# Straight edges need no corner math.
	if x >= left + radius and x <= right - radius:
		return true
	if y >= top + radius and y <= bottom - radius:
		return true
	var corner_x := left + radius if x < left + radius else right - radius
	var corner_y := top + radius if y < top + radius else bottom - radius
	var dx: int = x - corner_x
	var dy: int = y - corner_y
	return dx * dx + dy * dy <= radius * radius


static func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if (x - center.x) * (x - center.x) + (y - center.y) * (y - center.y) <= radius * radius:
				image.set_pixel(x, y, color)
