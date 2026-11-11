class_name HudAbilityButton
extends Button
## One ability button: icon with a radial sweep and the seconds over it, name, state word and a bar.
## Ready = cyan rim and a full bar; active = amber face, draining sweep and bar; cooling = dark face,
## a sweep of the remaining time and a filling bar; standby = dim (no wave is running). The state is
## always readable as a word and a shape, never by color alone (GDD 10.1, 10.3).

signal tapped(ability_id: StringName)

enum State { READY, ACTIVE, COOLING, STANDBY }

const ICON_PX: float = 96.0

var ability_id: StringName
var state: int = State.READY
var name_label: Label
var state_label: Label
var seconds_label: Label
var icon_rect: TextureRect
var radial: HudRadial
var bar: HudBar
var _body: MarginContainer
var _styled: int = -1
var _tween: Tween


func _init(which: StringName = &"") -> void:
	ability_id = which
	custom_minimum_size = Vector2(HudStyle.TOUCH * 2.0, HudStyle.TOUCH)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pressed.connect(_on_pressed)
	_build()
	show_state(State.READY, 0, 0.0, 1.0)


func _build() -> void:
	_body = MarginContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, 10)
	add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_body.add_child(row)
	var icon_box: Control = Control.new()
	icon_box.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_box)
	icon_rect = HudStyle.icon(ability_id, ICON_PX)
	icon_box.add_child(icon_rect)
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radial = HudRadial.new()
	icon_box.add_child(radial)
	radial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seconds_label = HudStyle.make_label("0", HudStyle.FONT_LARGE, Color.WHITE)
	HudStyle.center(seconds_label)
	HudStyle.bold(seconds_label)
	HudStyle.outline(seconds_label, 8)
	icon_box.add_child(seconds_label)
	seconds_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	name_label = HudStyle.make_label(Strings.t("ability.%s.name" % String(ability_id)).to_upper(), 34, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(name_label)
	col.add_child(name_label)
	state_label = HudStyle.make_label("-", HudStyle.FONT_SMALL, HudStyle.color(&"warden_cyan"))
	col.add_child(state_label)
	bar = HudBar.new()
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	bar.segments = 5
	col.add_child(bar)


## Shows one state. `secs` is the number on the icon (active or cooling), `sweep` the covered fraction of the
## radial (time left / total), `bar_fraction` the bar fill.
func show_state(new_state: int, secs: int, sweep: float, bar_fraction: float) -> void:
	state = new_state
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var amber: Color = HudStyle.color(&"core_amber")
	var gun: Color = HudStyle.color(&"gunmetal")
	var gun_text: Color = gun.lightened(0.4)  # plain gunmetal is only about 3.7:1 on the dark face
	match new_state:
		State.ACTIVE:
			state_label.text = Strings.t("hud.ability.active")
			state_label.add_theme_color_override(&"font_color", amber)
			seconds_label.text = Strings.tf("hud.seconds", [secs])
			radial.set_sweep(sweep, HudStyle.alpha(amber, 0.55))
			bar.set_fill_color(amber)
		State.COOLING:
			state_label.text = Strings.t("hud.ability.cooling")
			state_label.add_theme_color_override(&"font_color", gun_text)
			seconds_label.text = Strings.tf("hud.seconds", [secs])
			radial.set_sweep(sweep, Color(0.0, 0.0, 0.0, 0.66))
			bar.set_fill_color(gun)
		State.STANDBY:
			state_label.text = Strings.t("hud.ability.standby")
			state_label.add_theme_color_override(&"font_color", gun_text)
			radial.set_sweep(0.0, Color.TRANSPARENT)
			bar.set_fill_color(gun)
		_:
			state_label.text = Strings.t("hud.ability.ready")
			state_label.add_theme_color_override(&"font_color", cyan)
			radial.set_sweep(0.0, Color.TRANSPARENT)
			bar.set_fill_color(cyan)
	seconds_label.visible = new_state == State.ACTIVE or new_state == State.COOLING
	bar.set_state(bar_fraction, 0.0)
	icon_rect.modulate = Color(1.0, 1.0, 1.0, 0.55) if new_state == State.COOLING or new_state == State.STANDBY else Color.WHITE
	if _styled != new_state:
		_styled = new_state
		_apply_look(new_state)


func _apply_look(new_state: int) -> void:
	var base: Color = HudStyle.fill()
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var amber: Color = HudStyle.color(&"core_amber")
	var gun: Color = HudStyle.color(&"gunmetal")
	match new_state:
		State.ACTIVE:
			HudStyle.style_button(self, base.lerp(amber, 0.3), amber)
		State.COOLING, State.STANDBY:
			HudStyle.style_button(self, base.darkened(0.25), gun)
		_:
			HudStyle.style_button(self, base, cyan)


func play_pulse() -> void:
	_wobble(1.07, 0.0)


func play_deny() -> void:
	_wobble(1.0, 0.045)


func _wobble(peak_scale: float, tilt: float) -> void:
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_body.pivot_offset = _body.size * 0.5
	_body.scale = Vector2.ONE
	_body.rotation = 0.0
	_tween = create_tween()
	if tilt > 0.0:
		_tween.tween_property(_body, "rotation", tilt, 0.04)
		_tween.tween_property(_body, "rotation", -tilt, 0.08)
		_tween.tween_property(_body, "rotation", 0.0, 0.04)
	else:
		_tween.tween_property(_body, "scale", Vector2(peak_scale, peak_scale), 0.08)
		_tween.tween_property(_body, "scale", Vector2.ONE, 0.12)


func _on_pressed() -> void:
	tapped.emit(ability_id)
