class_name DraftBuildButton
extends Button
## The wide BUILD button of the draft screen (VARIETY_SPEC 11.1): the tags held as chips on the first line and every weapon
## carried on the second, so a long weapon list is never cut ("weapons: PISTOL  ARC PROJ.  SCATTER"). Tapping it opens the
## BuildList (the screen connects `pressed`). Information comes from the RunApi only. The static helpers also feed the compact
## one-line version a near-square screen shows instead.

const MAX_CHIPS: int = 4

var chips: Array[Label] = []
var weapons_label: Label


## The tags held, most stacks first (at most MAX_CHIPS).
static func tags_by_stacks(api: RunApi) -> Array[StringName]:
	var tags: Array[StringName] = []
	var stacks: Dictionary = api.build_tags()
	for key: Variant in stacks.keys():
		var tag: StringName = key
		var n: int = stacks[key]
		if n > 0:
			tags.append(tag)
	tags.sort_custom(func(a: StringName, b: StringName) -> bool:
		var sa: int = stacks.get(a, 0)
		var sb: int = stacks.get(b, 0)
		return sa > sb or (sa == sb and String(a) < String(b)))
	return tags.slice(0, MAX_CHIPS)


## "BULLET x2".
static func chip_text(api: RunApi, tag: StringName) -> String:
	var stacks: Dictionary = api.build_tags()
	var n: int = stacks.get(tag, 0)
	return "%s %s" % [RunUi.tag_name(tag), Strings.tf("build.stacks", [n])]


static func chips_line(api: RunApi) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for tag: StringName in tags_by_stacks(api):
		parts.append(chip_text(api, tag))
	return "  ".join(parts)


## The short names of the weapons carried: "PISTOL  ARC PROJ.".
static func weapon_names(api: RunApi) -> String:
	var names: PackedStringArray = PackedStringArray()
	for i: int in api.weapon_slot_count():
		var wid: StringName = api.weapon_slot(i).get("id", &"")
		if wid != &"":
			names.append(RunUi.opt("weapon.%s.short" % String(wid), String(wid).to_upper()))
	return "  ".join(names)


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(RunUi.TOUCH, RunUi.TOUCH)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_font_size_override(&"font_size", RunUi.MIN_TEXT)


func setup(api: RunApi) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	UiKit.fill(column)
	column.offset_left = 18.0
	column.offset_right = -18.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(RunUi.label(Strings.t("draft.build"), RunUi.MIN_TEXT, &"dim", true))
	var tags: Array[StringName] = tags_by_stacks(api)
	for tag: StringName in tags:
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override(&"panel", RunUi.chip_box(UiTheme.rim(&"warden_cyan", RunUi.hc())))
		var text: Label = RunUi.label(chip_text(api, tag), RunUi.MIN_TEXT, &"friendly", true)
		chip.add_child(text)
		chips.append(text)
		top.add_child(chip)
	if tags.is_empty():
		top.add_child(RunUi.label(Strings.t("draft.nothing_yet"), RunUi.MIN_TEXT, &"dim"))
	weapons_label = RunUi.label("%s %s" % [Strings.t("draft.weapons"), weapon_names(api)], RunUi.MIN_TEXT, &"body", true)
	weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapons_label.custom_minimum_size.x = 8.0
	column.add_child(weapons_label)
