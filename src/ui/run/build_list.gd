class_name BuildList
extends Control
## The build: every directive held with its stack count and every weapon carried with its level (ARCH 9, VARIETY_SPEC 11.1
## "tap = BUILD list"). A modal opened from the draft screen's build button (and later from the pause overlay); CLOSE emits
## `closed`. It only reads the RunApi.

signal closed

var close_button: Button
var directive_rows: Array[Label] = []
var weapon_rows: Array[Label] = []
var _api: RunApi
var _content: ContentSet


func _init() -> void:
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	theme = UiTheme.shared(RunUi.hc())
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	UiKit.fill(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(margin)
	for side: String in ["left", "right", "bottom", "top"]:
		margin.add_theme_constant_override("margin_" + side, int(RunUi.EDGE))
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", int(RunUi.GAP))
	margin.add_child(column)
	column.add_child(RunUi.label(Strings.t("build.title"), UiTheme.FONT_LARGE, &"body", true))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(list)
	_fill_weapons(list)
	_fill_directives(list)
	close_button = RunUi.button(Strings.t("ui.close"), true)
	close_button.pressed.connect(func() -> void: closed.emit())
	column.add_child(close_button)


func _fill_weapons(list: VBoxContainer) -> void:
	list.add_child(RunUi.label(Strings.t("build.weapons"), RunUi.MIN_TEXT + 4, &"dim", true))
	for i: int in _api.weapon_slot_count():
		var slot: Dictionary = _api.weapon_slot(i)
		var wid: StringName = slot.get("id", &"")
		if wid == &"":
			continue
		var level: int = slot.get("level", 1)
		var text: String = "%s  %s" % [Strings.t("weapon.%s.name" % String(wid)).to_upper(), Strings.tf("salvage.level", [level])]
		var l: Label = RunUi.label(text, UiTheme.FONT_BODY, &"body", true)
		weapon_rows.append(l)
		list.add_child(l)


func _fill_directives(list: VBoxContainer) -> void:
	list.add_child(RunUi.label(Strings.t("build.directives"), RunUi.MIN_TEXT + 4, &"dim", true))
	for def: DirectiveDef in _content.directives:
		var held: int = _api.directive_stacks(def.id)
		if held <= 0:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var role: StringName = &"danger" if def.rarity == DirectiveDef.Rarity.CORRUPTED else &"body"
		var name_l: Label = RunUi.label(Strings.t(def.name_key), UiTheme.FONT_BODY, role, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var count: Label = RunUi.label(Strings.tf("build.stacks", [held]), UiTheme.FONT_BODY, &"accent", true)
		row.add_child(count)
		directive_rows.append(name_l)
		list.add_child(row)
	if directive_rows.is_empty():
		list.add_child(RunUi.label(Strings.t("build.none"), UiTheme.FONT_BODY, &"dim"))
