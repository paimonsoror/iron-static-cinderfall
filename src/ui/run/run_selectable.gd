class_name RunSelectable
extends PanelContainer
## A panel that is one choice of an intermission screen (a directive card, a route card, a weapon panel). A tap selects it
## (`tapped`), a long press (0.5 s) asks for the detail (`long_pressed`); nothing is committed here, the screen's CONFIRM
## does that (VARIETY_SPEC 11, two-tap rule). Children other than Buttons ignore the mouse, so the whole panel is the
## touch target. Selected = brighter fill, a wider rim, a halo (a shadow) and a small lift (scale), never color alone.

signal tapped
signal long_pressed

const LONG_PRESS_SECONDS: float = 0.5
const LIFT: float = 1.035

var selected: bool = false
var enabled: bool = true  ## false: a taken or unavailable choice that ignores taps and long presses
var selectable: bool = true  ## false: information only (a tap does nothing, a long press still shows the detail)
var dimmed: bool = false
var rim_color: Color = Color.WHITE
var _timer: Timer
var _pressed: bool = false
var _swallow: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LONG_PRESS_SECONDS
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	resized.connect(_on_resized)
	mouse_exited.connect(_cancel)


func tap() -> void:
	if enabled and selectable:
		tapped.emit()


func long_press() -> void:
	if enabled:
		long_pressed.emit()


func set_selected(on: bool) -> void:
	selected = on
	scale = Vector2(LIFT, LIFT) if on else Vector2.ONE
	z_index = 1 if on else 0
	restyle()


func set_dimmed(on: bool) -> void:
	dimmed = on
	modulate = Color(1.0, 1.0, 1.0, 0.68) if on and enabled else Color.WHITE


## Rebuilds the frame from `rim_color` and the selected state. Called by the subclasses after they set their colors.
func restyle() -> void:
	var fill: Color = RunUi.fill()
	var width: int = UiTheme.rim_width(RunUi.hc())
	if selected:
		fill = fill.lerp(rim_color, 0.16)
		width += 3
	var sb: StyleBoxFlat = RunUi.box(fill, rim_color, width)
	if selected:
		sb.shadow_color = UiTheme.alpha(rim_color, 0.55)
		sb.shadow_size = 16
	add_theme_stylebox_override(&"panel", sb)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not enabled:
		return
	if button.pressed:
		_pressed = true
		_swallow = false
		_timer.start()
		accept_event()
	elif _pressed:
		_pressed = false
		_timer.stop()
		accept_event()
		if not _swallow and selectable:
			tapped.emit()
		_swallow = false


func _on_timer() -> void:
	if _pressed:
		_swallow = true
		long_pressed.emit()


func _cancel() -> void:
	_pressed = false
	_swallow = false
	_timer.stop()


func _on_resized() -> void:
	pivot_offset = size * 0.5
