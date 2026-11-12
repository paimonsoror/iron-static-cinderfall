class_name RouteCard
extends RunSelectable
## One option of the route screen (VARIETY_SPEC 11.2): the risk tag (STANDARD or HOT, word and icon), the pack name, the
## glyphs of its three most numerous enemy types with their counts, the hostile and elite counts, the modifier and the
## reward. It shows exactly what the plan will spawn; the data is the RunApi.route_option() dictionary.

var option: Dictionary = {}
var index: int = 0
var risk_label: Label
var name_label: Label
var hostiles_label: Label
var elites_label: Label
var modifier_label: Label
var modifier_desc: Label
var reward_label: Label
var glyphs: Array[RunEnemyGlyph] = []
var glyph_counts: Array[Label] = []


func build(option_index: int, data: Dictionary) -> void:
	index = option_index
	option = data
	var hot: bool = data.get("hot", false)
	rim_color = UiTheme.rim(&"chorus_red" if hot else &"warden_cyan", RunUi.hc())
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	add_child(col)
	col.add_child(_risk_row(hot))
	var pack_key: String = data.get("name_key", "")
	name_label = RunUi.wrap(RunUi.label(Strings.t(pack_key), UiTheme.FONT_LARGE - 8, &"body", true), 2)
	col.add_child(name_label)
	var counts: Dictionary = data.get("counts", {})
	col.add_child(_glyph_row(counts))
	var total: int = data.get("total", 0)
	hostiles_label = RunUi.label(Strings.tf("route.hostiles", [total]), UiTheme.FONT_BODY, &"body", true)
	col.add_child(hostiles_label)
	var elites: int = data.get("elites", 0)
	elites_label = RunUi.label(_elites_text(elites), UiTheme.FONT_BODY, &"accent" if elites > 0 else &"dim", true)
	col.add_child(elites_label)
	col.add_child(_modifier_block(data))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_reward_block(data))
	RunUi.ignore_mouse_except_buttons(self)
	restyle()


## "STANDARD" or "HOT" (the word the CONFIRM button names).
func risk_word() -> String:
	return Strings.t("route.hot" if option.get("hot", false) else "route.standard")


## The enemy ids of `counts` by number, most first (ties by id), at most `n`.
static func top_enemies(counts: Dictionary, n: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in counts.keys():
		var id: StringName = key
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ca: int = counts[a]
		var cb: int = counts[b]
		return ca > cb or (ca == cb and String(a) < String(b)))
	return ids.slice(0, n)


## The reward line: "+200 SCRAP", "SALVAGE CRATE", ...
static func reward_text(data: Dictionary) -> String:
	var key: String = data.get("reward_key", "")
	if key == "":
		return ""
	var text: String = Strings.t(key)
	if text.replace("%%", "").contains("%"):
		var amount: int = data.get("reward_amount", 0)
		return Strings.tf(key, [amount])
	return text


static func _elites_text(n: int) -> String:
	if n <= 0:
		return Strings.t("route.elites_none")
	return Strings.t("route.elite_one") if n == 1 else Strings.tf("route.elites", [n])


func _risk_row(hot: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.add_child(RunUi.icon(&"ticker_warn" if hot else &"ticker_help", 40.0))
	risk_label = RunUi.label(risk_word(), UiTheme.FONT_BODY - 4, &"danger" if hot else &"friendly", true)
	row.add_child(risk_label)
	return row


func _glyph_row(counts: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	for id: StringName in top_enemies(counts, 3):
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 0)
		var glyph: RunEnemyGlyph = RunEnemyGlyph.new(id, 124.0)
		glyphs.append(glyph)
		cell.add_child(glyph)
		var n: int = counts[id]
		var count: Label = RunUi.center(RunUi.label(Strings.tf("route.glyph_count", [n]), RunUi.MIN_TEXT, &"dim", true))
		count.tooltip_text = Strings.t("enemy.%s.name" % String(id))
		glyph_counts.append(count)
		cell.add_child(count)
		row.add_child(cell)
	return row


func _modifier_block(data: Dictionary) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	var key: String = data.get("modifier_key", "")
	if key == "":
		modifier_label = RunUi.label(Strings.t("modifier.none"), RunUi.MIN_TEXT + 2, &"dim")
		col.add_child(modifier_label)
		return col
	modifier_label = RunUi.label(Strings.t(key), UiTheme.FONT_BODY - 4, &"danger", true)
	col.add_child(RunUi.wrap(modifier_label, 2))
	var desc: String = RunUi.opt(key.trim_suffix(".name") + ".desc")
	if desc != "":
		modifier_desc = RunUi.wrap(RunUi.label(desc, RunUi.MIN_TEXT, &"body"), 3)
		col.add_child(modifier_desc)
	return col


func _reward_block(data: Dictionary) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.add_child(RunUi.label(Strings.t("route.reward"), RunUi.MIN_TEXT, &"dim", true))
	reward_label = RunUi.wrap(RunUi.label(reward_text(data), UiTheme.FONT_BODY, &"accent", true), 2)
	col.add_child(reward_label)
	return col
