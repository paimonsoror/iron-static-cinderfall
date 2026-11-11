class_name HudRadial
extends Control
## A clockwise radial sweep over its rect, like a clock face: `fraction` of the square is covered, starting at
## 12 o'clock. Used for the cooldown (dark, remaining time) and the active drain (amber, time left).

var fraction: float = 0.0  ## 0..1 covered
var tint: Color = Color(0.0, 0.0, 0.0, 0.66)
var hand_color: Color = Color(1.0, 1.0, 1.0, 0.9)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_sweep(covered: float, color: Color) -> void:
	var f: float = clampf(covered, 0.0, 1.0)
	if is_equal_approx(f, fraction) and color == tint:
		return
	fraction = f
	tint = color
	queue_redraw()


func _draw() -> void:
	if fraction <= 0.0 or size.x < 4.0 or size.y < 4.0:
		return
	var c: Vector2 = size * 0.5
	var reach: float = maxf(size.x, size.y) * 0.75  # past the corners; clip_contents trims it
	var start: float = -PI * 0.5
	var finish: float = start + TAU * minf(fraction, 0.9999)
	var steps: int = maxi(2, ceili(fraction * 48.0))
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(c)
	for i: int in steps + 1:
		var a: float = lerpf(start, finish, float(i) / float(steps))
		pts.append(c + Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(pts, tint)
	if fraction < 0.9999:
		draw_line(c, c + Vector2(cos(finish), sin(finish)) * reach, hand_color, 3.0)
