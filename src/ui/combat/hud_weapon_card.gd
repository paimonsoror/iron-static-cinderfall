class_name HudWeaponCard
extends Button
## One weapon of the weapon bar (VARIETY_SPEC 11.4): the silhouette with level chevrons, "1 ARC PROJ.", and the feed: a
## magazine count, or a heat bar, or RELOADING / VENTING / SWAPPING / CHARGING with a progress bar. The active card is
## amber-rimmed and wide (400 x 150), a holstered card cyan and narrower (300 x 150); a tap on a holstered card swaps. The
## active card pulses (a steady thick rim under Reduced Flash) when a swap would help: it is reloading or venting and the
## other weapon is ready. A hint, never an automatic action. The state is always a word and a bar, never a color alone.

signal tapped(slot: int)

const HEIGHT: float = 150.0
const NARROW: float = 290.0  ## below this width the silhouette column is left out

var slot: int = 0
var weapon_id: StringName = &""
var state: int = RunApi.SLOT_READY
var active: bool = false
var hinting: bool = false
var name_label: Label
var status_label: Label
var bar: HudBar
var icon_rect: TextureRect
var marks: HudLevelMarks
var _icon_col: VBoxContainer
var _total: int = 0
var _look: String = ""
var _tween: Tween


func _init(card_slot: int = 0) -> void:
	slot = card_slot
	custom_minimum_size = Vector2(HudStyle.TOUCH, HEIGHT)
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func() -> void: tapped.emit(slot))
	var body: MarginContainer = MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 10)
	add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(row)
	_icon_col = VBoxContainer.new()
	_icon_col.add_theme_constant_override(&"separation", 4)
	_icon_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon_col)
	icon_rect = HudStyle.icon(&"weapon_pistol", 84.0)
	icon_rect.custom_minimum_size = Vector2(84.0, 44.0)
	_icon_col.add_child(icon_rect)
	marks = HudLevelMarks.new()
	_icon_col.add_child(marks)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	name_label = HudStyle.make_label("-", HudStyle.FONT_SMALL, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(name_label)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	status_label = HudStyle.make_label("-", HudStyle.FONT_SMALL, HudStyle.color(&"warden_cyan"))
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	HudStyle.bold(status_label)
	col.add_child(status_label)
	bar = HudBar.new()
	bar.custom_minimum_size = Vector2(0.0, 16.0)
	bar.segments = 10
	col.add_child(bar)


## Shows slot `info` (RunApi.weapon_slot): `is_active` = the weapon in hand, `hint` = swapping would help now.
func show_slot(info: Dictionary, is_active: bool, hint: bool) -> void:
	var id: StringName = info.get("id", &"")
	var new_state: int = info.get("state", RunApi.SLOT_READY)
	var left: int = info.get("ticks_left", 0)
	if id != weapon_id or new_state != state:
		_total = 0
	_total = maxi(_total, left)
	weapon_id = id
	state = new_state
	active = is_active
	var level: int = info.get("level", 1)
	var empty: bool = id == &"" or new_state == RunApi.SLOT_EMPTY
	var amber: Color = HudStyle.color(&"core_amber")
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var red: Color = HudStyle.color(&"chorus_red")
	if empty:
		name_label.text = str(slot + 1)
		_status(Strings.t("hud.weapon.empty"), HudStyle.color(&"gunmetal").lightened(0.4))
		bar.visible = false
		icon_rect.texture = null
		marks.set_level(0, amber)
	else:
		name_label.text = "%d %s" % [slot + 1, WeaponStats.short_name(id)]
		icon_rect.texture = HudStyle.texture(StringName("weapon_%s" % String(id)))
		marks.set_level(level, amber)
		_feed(info, left, amber, cyan, red)
	icon_rect.modulate = Color.WHITE if is_active else Color(1.0, 1.0, 1.0, 0.6)
	name_label.add_theme_color_override(&"font_color", HudStyle.color(&"bone_ceramic") if is_active else HudStyle.color(&"bone_ceramic").darkened(0.12))
	_restyle(hint, empty)


func _feed(info: Dictionary, left: int, amber: Color, cyan: Color, red: Color) -> void:
	var heat_cap: int = info.get("heat_cap", 0)
	var heat: int = info.get("heat", 0)
	match state:
		RunApi.SLOT_RELOADING:
			_status(Strings.t("hud.weapon.reloading"), amber)
			_progress(1.0 - float(left) / float(maxi(_total, 1)), amber)
		RunApi.SLOT_VENTING:
			_status(Strings.t("hud.weapon.venting"), red.lightened(0.2))
			_progress(float(left) / float(maxi(_total, 1)), red)
		RunApi.SLOT_SWAPPING:
			_status(Strings.t("hud.weapon.swapping"), cyan)
			_progress(1.0 - float(left) / float(maxi(_total, 1)), cyan)
		RunApi.SLOT_CHARGING:
			_status(Strings.t("hud.weapon.charging"), amber)
			_progress(1.0 - float(left) / float(maxi(_total, 1)), amber)
		_:
			if heat_cap > 0:
				var frac: float = float(heat) / float(heat_cap)
				_status(Strings.tf("hud.weapon.heat_pct", [roundi(frac * 100.0)]), red.lightened(0.2) if frac >= 0.8 else cyan)
				_progress(frac, red if frac >= 0.8 else amber)
			else:
				var mag: int = info.get("magazine", 0)
				var size_mag: int = info.get("size", 0)
				_status(Strings.tf("hud.ammo.mag", [mag, size_mag]), HudStyle.color(&"bone_ceramic"))
				bar.visible = false
	if state == RunApi.SLOT_READY and heat_cap <= 0:
		status_label.add_theme_font_size_override(&"font_size", HudStyle.FONT_BODY)
	else:
		status_label.add_theme_font_size_override(&"font_size", HudStyle.FONT_SMALL)


func _status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override(&"font_color", color)


func _progress(fraction: float, color: Color) -> void:
	bar.visible = true
	bar.set_fill_color(color)
	bar.set_state(fraction, 0.0)


## The card's width decides whether the silhouette column fits (a narrow card keeps the chevrons under the name instead).
func set_card_width(w: float) -> void:
	_icon_col.visible = w >= NARROW


func _restyle(hint: bool, empty: bool) -> void:
	var look: String = "%s|%s|%s|%s" % [active, hint, empty, HudStyle.high_contrast()]
	if look == _look:
		return
	_look = look
	hinting = hint
	var amber: Color = HudStyle.color(&"core_amber")
	var cyan: Color = HudStyle.color(&"warden_cyan")
	var base: Color = HudStyle.fill()
	if empty:
		HudStyle.style_button(self, base.darkened(0.2), HudStyle.color(&"gunmetal"))
	elif active:
		HudStyle.style_button(self, base.lerp(amber, 0.16), amber)
	else:
		HudStyle.style_button(self, base, cyan.darkened(0.15))
	if hint:
		add_theme_stylebox_override(&"normal", HudStyle.panel(base.lerp(amber, 0.22), amber, HudStyle.CHAMFER, 6))
	_pulse(hint)


func _pulse(on: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate = Color.WHITE
	if not on or not is_inside_tree() or HudStyle.reduced_flash():
		return
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "modulate:a", 0.7, 0.45)
	_tween.tween_property(self, "modulate:a", 1.0, 0.45)
