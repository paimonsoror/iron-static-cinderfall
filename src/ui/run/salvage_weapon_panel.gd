class_name SalvageWeaponPanel
extends RunSelectable
## One weapon panel of the salvage screen (VARIETY_SPEC 11.3). Three kinds: the recovered weapon (tier, name, NEW, rules text,
## stats; selectable only on a boss crate), a carried slot (slot number, name, level, stats and a REPLACE or TAKE plate: the
## whole panel is the touch target) and a plain action plate (LEVEL UP, SCRAP IT) made with `build_action`.

var weapon_id: StringName = &""
var slot: int = -1  ## the carried slot, or -1
var name_label: Label
var slot_label: Label
var stats_label: Label
var desc_label: Label
var plate_label: Label
var tier_label: Label
var new_label: Label
var level_label: Label
var _secondary: Array[Control] = []


## The recovered weapon `id` of crate tier `tier`; `pickable` on a boss crate (two panels, tap one).
func build_new(id: StringName, tier: int, def: WeaponDef, pickable: bool) -> void:
	weapon_id = id
	custom_minimum_size.y = RunUi.TOUCH
	selectable = pickable
	rim_color = UiTheme.rim(&"warden_cyan", RunUi.hc())
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	var shape: TextureRect = RunUi.icon(StringName("weapon_%s" % String(id)), 150.0)
	shape.custom_minimum_size = Vector2(150.0, 76.0)
	shape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shape)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 4)
	row.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	col.add_child(head)
	tier_label = RunUi.label(Strings.tf("salvage.tier", [tier]), UiTheme.FONT_BODY, &"accent", true)
	head.add_child(tier_label)
	name_label = RunUi.label(WeaponStats.name_of(id), UiTheme.FONT_BODY, &"body", true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	new_label = RunUi.label(Strings.t("salvage.new"), RunUi.MIN_TEXT + 2, &"friendly", true)
	head.add_child(new_label)
	desc_label = RunUi.wrap(RunUi.label(RunUi.opt("weapon.%s.desc" % String(id)), RunUi.MIN_TEXT), 2)
	col.add_child(desc_label)
	stats_label = RunUi.wrap(RunUi.label(WeaponStats.line(def, 1) if def != null else "", RunUi.MIN_TEXT, &"accent", true), 2)
	col.add_child(stats_label)
	_secondary.append(desc_label)
	RunUi.ignore_mouse_except_buttons(self)
	restyle()


## A carried slot. `empty` = nothing in it (the plate says TAKE).
func build_slot(slot_index: int, id: StringName, level: int, def: WeaponDef, empty: bool) -> void:
	slot = slot_index
	weapon_id = id
	custom_minimum_size.y = RunUi.TOUCH
	rim_color = UiTheme.rim(&"gunmetal", RunUi.hc()).lightened(0.3)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	col.add_child(head)
	slot_label = RunUi.label(str(slot_index + 1), UiTheme.FONT_BODY, &"accent", true)
	head.add_child(slot_label)
	if empty:
		name_label = RunUi.label(Strings.t("salvage.empty"), UiTheme.FONT_BODY, &"dim", true)
	else:
		name_label = RunUi.label(WeaponStats.short_name(id), UiTheme.FONT_BODY, &"body", true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	if not empty:
		level_label = RunUi.label(Strings.tf("salvage.level", [level]), RunUi.MIN_TEXT + 2, &"accent", true)
		head.add_child(level_label)
		stats_label = RunUi.wrap(RunUi.label(WeaponStats.line(def, level) if def != null else "", RunUi.MIN_TEXT, &"dim"), 2)
		col.add_child(stats_label)
		_secondary.append(stats_label)
	var plate: PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override(&"panel", RunUi.chip_box(rim_color))
	plate.custom_minimum_size.y = 52.0
	plate_label = RunUi.center(RunUi.label(Strings.t("salvage.take" if empty else "salvage.replace"), UiTheme.FONT_BODY - 4, &"body", true))
	plate.add_child(plate_label)
	col.add_child(plate)
	RunUi.ignore_mouse_except_buttons(self)
	restyle()


## A wide one-line action (LEVEL UP: ..., SCRAP IT +N) with an icon.
func build_action(text: String, icon_id: StringName, color: Color) -> void:
	rim_color = color
	custom_minimum_size.y = RunUi.TOUCH
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	add_child(row)
	row.add_child(RunUi.icon(icon_id, 56.0))
	name_label = RunUi.wrap(RunUi.label(text, UiTheme.FONT_BODY, &"body", true), 2)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	RunUi.ignore_mouse_except_buttons(self)
	restyle()


## The secondary lines (rules text, carried stats) are left out on a near-square screen.
func set_compact(on: bool) -> void:
	for c: Control in _secondary:
		c.visible = not on
