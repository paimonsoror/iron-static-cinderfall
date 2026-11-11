class_name UiChevrons
extends Control
## Amber chevron rank marks (armory_style.png): `count` lit chevrons out of `max_count`. Unlit ones stay as a dim
## outline, so the rank reads by shape and number, never by color alone.

const STEP: float = 56.0
const CHEVRON_W: float = 44.0
const HEIGHT: float = 48.0

var count: int = 1
var max_count: int = 4


func _init(lit: int = 1, total: int = 4) -> void:
	count = lit
	max_count = maxi(total, lit)
	custom_minimum_size = Vector2(STEP * float(max_count) - (STEP - CHEVRON_W), HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var lit: Color = UiTheme.color(&"core_amber")
	var dim: Color = UiTheme.alpha(UiTheme.color(&"gunmetal"), 0.55)
	if UiTheme.high_contrast_on():
		lit = lit.lerp(Color.WHITE, 0.3)
		dim = UiTheme.alpha(UiTheme.color(&"gunmetal"), 0.9)
	var top: float = (size.y - HEIGHT) * 0.5
	for i: int in max_count:
		var x: float = STEP * float(i)
		var col: Color = lit if i < count else dim
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x, top + HEIGHT * 0.72), Vector2(x + CHEVRON_W * 0.5, top + HEIGHT * 0.2), Vector2(x + CHEVRON_W, top + HEIGHT * 0.72),
		])
		draw_polyline(pts, col, 9.0 if i < count else 4.0, true)
