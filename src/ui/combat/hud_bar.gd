class_name HudBar
extends Control
## A segmented horizontal bar drawn in one pass: trough, fill, an optional overlay segment ending at the
## fill edge (the cyan shield on the core bar) and thin segment cuts. Redraws only when a value changes.

var fraction: float = 1.0  ## 0..1 of the fill
var overlay_fraction: float = 0.0  ## 0..1 of the whole bar, drawn over the right end of the fill
var fill_color: Color = Color(0.9451, 0.6392, 0.2902)
var overlay_color: Color = Color(0.2235, 0.7882, 0.8588)
var segments: int = 20


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 30.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(fill_fraction: float, overlay: float) -> void:
	var f: float = clampf(fill_fraction, 0.0, 1.0)
	var o: float = clampf(overlay, 0.0, 1.0)
	if is_equal_approx(f, fraction) and is_equal_approx(o, overlay_fraction):
		return
	fraction = f
	overlay_fraction = o
	queue_redraw()


func set_fill_color(c: Color) -> void:
	if c == fill_color:
		return
	fill_color = c
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var obsidian: Color = HudStyle.color(&"obsidian")
	draw_rect(Rect2(0.0, 0.0, w, h), obsidian.darkened(0.2))
	var fill_w: float = w * fraction
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, 0.0, fill_w, h), fill_color)
		# top sheen: a lighter strip so the fill reads as a lit bar, not a flat rectangle
		draw_rect(Rect2(0.0, 0.0, fill_w, h * 0.3), fill_color.lightened(0.25))
	var shield_w: float = minf(w * overlay_fraction, fill_w)
	if shield_w > 0.0:
		var x0: float = fill_w - shield_w
		draw_rect(Rect2(x0, 0.0, shield_w, h), overlay_color)
		draw_rect(Rect2(x0, 0.0, shield_w, h * 0.3), overlay_color.lightened(0.3))
		draw_rect(Rect2(x0, 0.0, 3.0, h), Color.WHITE)
	var step: float = w / float(maxi(segments, 1))
	for i: int in range(1, segments):
		draw_rect(Rect2(step * float(i) - 1.0, 0.0, 2.0, h), obsidian)
	draw_rect(Rect2(0.0, 0.0, w, h), HudStyle.color(&"gunmetal"), false, 2.0)
