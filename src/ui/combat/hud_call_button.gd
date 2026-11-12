class_name HudCallButton
extends Button
## A player-triggered call of the weapon bar (VARIETY_SPEC 11.4): STRIKE (charges left), VENT (its price) and, with
## signal_hijack, FREIGHT. 150 x 150. Ready = cyan rim; not callable (no charges, used this wave, core too low, offline) =
## dim with the same words, and a tap shakes instead of sending. The button never decides legality: the RunApi does
## (call_block_reason), it only shows it.

signal called(event_id: StringName)

const SIZE: float = 150.0
const SMALL: float = 132.0

var event_id: StringName = &""
var ready_now: bool = false
var icon_rect: TextureRect
var value_label: Label
var name_label: Label
var _tween: Tween
var _look: int = -1


func _init(id: StringName = &"", icon_id: StringName = &"call_strike", label_key: String = "") -> void:
	event_id = id
	custom_minimum_size = Vector2(SMALL, SMALL)
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func() -> void: called.emit(event_id))
	var body: MarginContainer = MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 8)
	add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override(&"separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	icon_rect = HudStyle.icon(icon_id, 52.0)
	top.add_child(icon_rect)
	value_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"core_amber"))
	HudStyle.bold(value_label)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(value_label)
	name_label = HudStyle.make_label(Strings.t(label_key) if label_key != "" else "-", HudStyle.FONT_SMALL, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(name_label)
	HudStyle.center(name_label)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	show_state(false, "")


## `callable_now` = the RunApi would accept the call; `value` = "x2" or "-8%". `reason_word` = a state word that replaces
## the name when the call is locked out (OFFLINE), or "".
func show_state(callable_now: bool, value: String, reason_word: String = "") -> void:
	ready_now = callable_now
	value_label.text = value
	var amber: Color = HudStyle.color(&"core_amber")
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var gun: Color = HudStyle.color(&"gunmetal")
	value_label.add_theme_color_override(&"font_color", amber if callable_now else gun.lightened(0.4))
	icon_rect.modulate = Color.WHITE if callable_now else Color(1.0, 1.0, 1.0, 0.45)
	if reason_word != "":
		name_label.text = reason_word
	var look: int = 1 if callable_now else 0
	if look == _look:
		return
	_look = look
	if callable_now:
		HudStyle.style_button(self, HudStyle.fill(), cyan)
	else:
		HudStyle.style_button(self, HudStyle.fill().darkened(0.25), gun)


func set_name_text(text: String) -> void:
	name_label.text = text


func play_deny() -> void:
	if not is_inside_tree() or HudStyle.reduced_flash():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	rotation = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "rotation", 0.045, 0.04)
	_tween.tween_property(self, "rotation", -0.045, 0.08)
	_tween.tween_property(self, "rotation", 0.0, 0.04)
