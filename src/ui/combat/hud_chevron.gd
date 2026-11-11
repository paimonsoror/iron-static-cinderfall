class_name HudChevron
extends Control
## A drawn chevron (the fonts have no arrow glyph): points up when `up` is true, down otherwise.

var up: bool = true
var color: Color = Color(0.9451, 0.6392, 0.2902)


func _init() -> void:
	custom_minimum_size = Vector2(44.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_up(value: bool) -> void:
	if value == up:
		return
	up = value
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < 4.0:
		return  # not laid out yet: a degenerate polygon makes the canvas log an error
	var t: float = h * 0.4  # stroke thickness
	var pts: PackedVector2Array
	# two parallel V strokes, the lower one shifted down by t (a self-crossing outline fails triangulation)
	if up:
		pts = PackedVector2Array([
			Vector2(0.0, h - t), Vector2(w * 0.5, 0.0), Vector2(w, h - t),
			Vector2(w, h), Vector2(w * 0.5, t), Vector2(0.0, h),
		])
	else:
		pts = PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(w * 0.5, h - t), Vector2(w, 0.0),
			Vector2(w, t), Vector2(w * 0.5, h), Vector2(0.0, t),
		])
	draw_colored_polygon(pts, color)
