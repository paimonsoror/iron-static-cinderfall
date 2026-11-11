class_name HudUpgradeCard
extends Button
## One upgrade card: icon, name, level n/max with pips, the exact next effect, the exact cost and a reason
## line (GDD 9). A blocked card keeps receiving taps so it can shake and say why; it never issues a command.
## At the max level the cost is replaced by a MAX badge.

signal tapped(upgrade_id: StringName)

const ICON_PX: float = 72.0
const CARD_H: float = 364.0  ## a Button ignores its children when sizing itself, so the height is set here

var upgrade_id: StringName
var blocked: bool = false
var is_max: bool = false
var icon_rect: TextureRect
var name_label: Label
var level_label: Label
var level_bar: HudBar
var effect_label: Label
var cost_box: PanelContainer
var cost_label: Label
var max_box: PanelContainer
var max_label: Label
var reason_label: Label
var _body: MarginContainer
var _cost_icon: TextureRect
var _styled: int = -1
var _tween: Tween
var _flash_reason: String = ""


func _init(which: StringName = &"") -> void:
	upgrade_id = which
	custom_minimum_size = Vector2(HudStyle.TOUCH, CARD_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	pressed.connect(func() -> void: tapped.emit(upgrade_id))
	_build()


func _build() -> void:
	_body = MarginContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, 10)
	add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_body.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	col.add_child(top)
	icon_rect = HudStyle.icon(upgrade_id, ICON_PX)
	top.add_child(icon_rect)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override(&"separation", 6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lv)
	level_label = HudStyle.make_label("-", 28, HudStyle.color(&"warden_cyan"))
	HudStyle.bold(level_label)
	lv.add_child(level_label)
	level_bar = HudBar.new()
	level_bar.custom_minimum_size = Vector2(0.0, 12.0)
	level_bar.segments = 5
	lv.add_child(level_bar)
	name_label = HudStyle.make_label("-", 30, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(name_label)
	HudStyle.center(name_label)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0.0, 74.0)
	col.add_child(name_label)
	effect_label = HudStyle.make_label("-", 26, HudStyle.color(&"bone_ceramic"))
	HudStyle.center(effect_label)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(0.0, 62.0)
	col.add_child(effect_label)
	var slot: Control = Control.new()  # the cost pill and the MAX badge share one slot
	slot.custom_minimum_size = Vector2(0.0, 56.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(slot)
	cost_box = PanelContainer.new()
	slot.add_child(cost_box)
	cost_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cost_row: HBoxContainer = HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override(&"separation", 8)
	cost_box.add_child(cost_row)
	_cost_icon = HudStyle.icon(&"scrap", 36.0)
	cost_row.add_child(_cost_icon)
	cost_label = HudStyle.make_label("-", 38, HudStyle.color(&"obsidian"))
	HudStyle.mono(cost_label)
	HudStyle.bold(cost_label)
	cost_row.add_child(cost_label)
	max_box = PanelContainer.new()
	max_box.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.fill(), HudStyle.color(&"warden_cyan"), 10, 3))
	slot.add_child(max_box)
	max_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	max_label = HudStyle.make_label(Strings.t("hud.card.max"), 38, HudStyle.color(&"warden_cyan"))
	HudStyle.center(max_label)
	HudStyle.bold(max_label)
	max_box.add_child(max_label)
	max_box.visible = false
	reason_label = HudStyle.make_label("-", 26, HudStyle.color(&"warden_cyan"))
	HudStyle.center(reason_label)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.custom_minimum_size = Vector2(0.0, 62.0)
	col.add_child(reason_label)
	HudStyle.ignore_mouse(self)
	name_label.text = Strings.t("upgrade.%s.name" % String(upgrade_id)).to_upper()
	_apply_look(false, false)


## Shows one state. `reason` is a Reason.Id (OK = buyable), `effect` the already formatted next effect,
## `maxed` true when no level is left to buy (the cost is then replaced by MAX).
func show_state(level: int, max_level: int, cost: int, reason: int, effect: String, maxed: bool) -> void:
	is_max = maxed
	blocked = reason != Reason.Id.OK
	level_label.text = Strings.tf("hud.card.level", [level, max_level])
	level_bar.segments = maxi(max_level, 1)
	level_bar.set_state(float(level) / float(maxi(max_level, 1)), 0.0)
	effect_label.text = Strings.t("hud.effect.done") if is_max else effect
	if cost >= 0:
		cost_label.text = "%d" % cost
	cost_box.visible = not is_max
	max_box.visible = is_max
	if is_max:
		reason_label.text = Strings.t("reason.max_level")
		reason_label.visible = false
	elif blocked:
		reason_label.text = Strings.t(Reason.string_key(reason))
		reason_label.visible = true
	else:
		reason_label.text = Strings.t("hud.card.tap")
		reason_label.visible = true
	if _flash_reason != "" and not is_max:
		reason_label.text = _flash_reason
	var look: int = 2 if is_max else (1 if blocked else 0)
	if look != _styled:
		_apply_look(blocked, is_max)


func _apply_look(is_blocked: bool, maxed: bool) -> void:
	_styled = 2 if maxed else (1 if is_blocked else 0)
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var amber: Color = HudStyle.color(&"core_amber")
	var gun: Color = HudStyle.color(&"gunmetal")
	var base: Color = HudStyle.fill()
	if maxed:
		HudStyle.style_button(self, base, cyan)
	elif is_blocked:
		HudStyle.style_button(self, base.darkened(0.3), gun)
	else:
		HudStyle.style_button(self, base, cyan)
	var pill_fill: Color = amber
	var pill_text: Color = HudStyle.color(&"obsidian")
	if is_blocked and not maxed:
		pill_fill = base.darkened(0.2)
		pill_text = amber.darkened(0.15)
	cost_box.add_theme_stylebox_override(&"panel", HudStyle.panel(pill_fill, amber if not is_blocked else gun, 10, 3))
	cost_label.add_theme_color_override(&"font_color", pill_text)
	# the gear is amber: on the amber pill it is tinted dark, on the dark pill it keeps its colors
	_cost_icon.modulate = Color.WHITE if (is_blocked and not maxed) else Color(0.06, 0.09, 0.13)
	var dim: float = 0.5 if (is_blocked and not maxed) else 1.0
	icon_rect.modulate = Color(1.0, 1.0, 1.0, dim)
	name_label.modulate = Color(1.0, 1.0, 1.0, 0.78 if (is_blocked and not maxed) else 1.0)
	effect_label.modulate = name_label.modulate
	var rc: Color = cyan
	if is_blocked:
		rc = HudStyle.color(&"bone_ceramic").darkened(0.15)
	reason_label.add_theme_color_override(&"font_color", rc)


func play_pulse() -> void:
	_wobble(1.06, 0.0)


## Shake, and show `why` on the reason line for a moment.
func play_deny(why: String) -> void:
	_flash_reason = why
	reason_label.text = why
	reason_label.visible = not is_max
	_wobble(1.0, 0.04)
	if is_inside_tree():
		get_tree().create_timer(1.6).timeout.connect(_clear_flash)


func _clear_flash() -> void:
	_flash_reason = ""


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
