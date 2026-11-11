class_name ScreenFlash
extends CanvasLayer
## The only full-screen flash of the battle (EMP pulse, unshielded core hit). Reduced Flash removes it (GDD 10.3):
## the node is hidden and `trigger` does nothing.

const LAYER_BELOW_HUD: int = 0

var rect: ColorRect

var _alpha: float = 0.0
var _decay: float = 4.0
var _color: Color = Color.WHITE
var _reduced: bool = false


func setup() -> void:
	name = "ScreenFlash"
	layer = LAYER_BELOW_HUD
	rect = ColorRect.new()
	rect.name = "FlashRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	rect.visible = false
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_reduced(on: bool) -> void:
	_reduced = on
	if on:
		_alpha = 0.0
		rect.visible = false


## Flashes the screen with `color` at peak opacity `peak`, fading out over `seconds`.
func trigger(color: Color, peak: float, seconds: float) -> void:
	if _reduced:
		return
	_color = color
	_alpha = clampf(peak, 0.0, 1.0)
	_decay = _alpha / maxf(seconds, 0.01)
	rect.visible = true
	rect.color = Color(color.r, color.g, color.b, _alpha)


func step(delta: float) -> void:
	if _alpha <= 0.0:
		return
	_alpha = maxf(0.0, _alpha - _decay * delta)
	rect.color = Color(_color.r, _color.g, _color.b, _alpha)
	if _alpha <= 0.0:
		rect.visible = false


func is_flash_visible() -> bool:
	return rect.visible


func clear() -> void:
	_alpha = 0.0
	rect.visible = false
