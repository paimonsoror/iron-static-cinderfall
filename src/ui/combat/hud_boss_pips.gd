class_name HudBossPips
extends Control
## The phase pips of the boss bar (GDD 10.1): one square per phase of the living boss; the squares up to the current phase
## are filled, the later ones hollow. Hidden when the boss has a single phase. Shape and count carry the phase, not color.

const PIP: float = 22.0
const STEP: float = 30.0

var phase: int = 0
var count: int = 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_phase(current: int, total: int) -> void:
	if current == phase and total == count:
		return
	phase = current
	count = total
	visible = count > 1
	custom_minimum_size = Vector2(STEP * float(count), PIP) if count > 1 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var red: Color = HudStyle.color(&"chorus_red").lightened(0.15)
	for i: int in count:
		var r: Rect2 = Rect2(float(i) * STEP + 2.0, (size.y - PIP) * 0.5, PIP, PIP)
		if i <= phase:
			draw_rect(r, red)
		else:
			draw_rect(r, Color(0.0, 0.0, 0.0, 0.5))
			draw_rect(r, red, false, 3.0)
