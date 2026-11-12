class_name HudLevelMarks
extends Control
## The weapon level as stacked amber chevrons (the rank marks of the concept bar): one per level, up to three. A shape, not
## only a color, so the level reads in High Contrast and for color-blind players.

const MAX_LEVEL: int = 3

var level: int = 1
var color: Color = Color(0.9451, 0.6392, 0.2902)


func _init() -> void:
	custom_minimum_size = Vector2(84.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_level(value: int, tint: Color) -> void:
	var l: int = clampi(value, 0, MAX_LEVEL)
	if l == level and tint == color:
		return
	level = l
	color = tint
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var w: float = minf(size.x / float(MAX_LEVEL), 30.0)
	var h: float = size.y
	var total: float = w * float(level)
	var x0: float = (size.x - total) * 0.5
	for i: int in level:
		var x: float = x0 + w * float(i)
		var t: float = h * 0.28
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x + 1.0, h - t), Vector2(x + w * 0.5, 2.0), Vector2(x + w - 1.0, h - t),
			Vector2(x + w - 1.0, h - 1.0), Vector2(x + w * 0.5, t + 2.0), Vector2(x + 1.0, h - 1.0),
		])
		draw_colored_polygon(pts, color)
