class_name HudStaticOverlay
extends Control
## The static pattern over an ability locked by a Static Front (VARIETY_SPEC 11.4): diagonal hatch lines with a few
## offset breaks, drawn in one pass. With the word OFFLINE it says "locked" by shape and text, not by color alone. A plain
## still pattern (no animation), so Reduced Flash needs no variant.

const STEP: float = 18.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip_contents = true


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var tone: Color = HudStyle.alpha(HudStyle.color(&"gunmetal").lightened(0.5), 0.5 if HudStyle.high_contrast() else 0.32)
	var x: float = -size.y
	var n: int = 0
	while x < size.x:
		var broke: bool = n % 5 == 3
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0.0), tone, 4.0 if broke else 2.5)
		x += STEP
		n += 1
