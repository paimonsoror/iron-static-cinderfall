class_name BossBriefOverlay
extends RunOverlayBase
## The boss briefing (VARIETY_SPEC 11.2): the route frame with one wide card: the boss name (and its Node 9 variant), its
## silhouette, the ATTACK line (how it attacks) and the ANSWER line (what stops it), and CONTINUE. An overlay inside
## INTERMISSION while RunApi.awaiting() == AWAIT_BOSS_BRIEF; sends continue_run. CONTINUE is not a choice, so it is one tap.
## The lines come from the brief's `attack_key` / `answer_key`, a variant's `boss.<variant>.attack|answer`, or the
## `boss.<id>.attack|answer` convention, whichever exists in the string table. `setup` is the frozen contract.

var brief: Dictionary = {}
var name_label: Label
var variant_label: Label
var banner_label: Label
var attack_head: Label
var attack_label: Label
var answer_head: Label
var answer_label: Label
var glyph: RunEnemyGlyph
var continue_button: Button
var strip: RouteActStrip


func setup(api: RunApi, content: ContentSet) -> void:
	_open(api, content)


func _populate() -> void:
	brief = _api.boss_brief()
	var wave_number: int = _api.wave() + 1
	var act: int = _api.act()
	if _content.run != null and _content.run.wave_slot(wave_number) != null:
		act = _content.run.wave_slot(wave_number).act
	_add_act_band(act, wave_number)
	strip = RouteActStrip.new()
	strip.setup(_api.wave_count(), wave_number, _content)
	header.add_child(strip)
	var rim: Color = UiTheme.rim(&"chorus_red", RunUi.hc())
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = RunUi.box(RunUi.fill(), rim)
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 24.0
	box.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override(&"panel", box)
	controls.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	panel.add_child(col)
	var name_key: String = brief.get("name_key", "")
	name_label = RunUi.wrap(RunUi.label(Strings.t(name_key), UiTheme.FONT_LARGE, &"body", true), 2)
	col.add_child(name_label)
	var variant: StringName = brief.get("variant", &"")
	if variant != &"" and RunUi.has_key("boss.%s" % String(variant)):
		variant_label = RunUi.label(Strings.t("boss.%s" % String(variant)), UiTheme.FONT_BODY, &"accent", true)
		col.add_child(variant_label)
	var banner_key: String = brief.get("banner_key", "")
	if banner_key != "" and RunUi.has_key(banner_key):
		banner_label = RunUi.wrap(RunUi.label(Strings.t(banner_key), RunUi.MIN_TEXT + 2, &"dim"))
		banner_label.theme_type_variation = &"Mono"
		col.add_child(banner_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	col.add_child(row)
	var holder: CenterContainer = CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var boss_id: StringName = brief.get("id", &"siege_hulk")
	glyph = RunEnemyGlyph.new(boss_id, 220.0)
	holder.add_child(glyph)
	row.add_child(holder)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override(&"separation", 4)
	row.add_child(lines)
	attack_head = RunUi.label(Strings.t("boss_brief.attack"), RunUi.MIN_TEXT + 2, &"danger", true)
	attack_label = RunUi.wrap(RunUi.label(_line("attack"), UiTheme.FONT_BODY))
	answer_head = RunUi.label(Strings.t("boss_brief.answer"), RunUi.MIN_TEXT + 2, &"friendly", true)
	answer_label = RunUi.wrap(RunUi.label(_line("answer"), UiTheme.FONT_BODY))
	for l: Control in [attack_head, attack_label, answer_head, answer_label]:
		lines.add_child(l)
	attack_head.visible = attack_label.text != ""
	attack_label.visible = attack_head.visible
	answer_head.visible = answer_label.text != ""
	answer_label.visible = answer_head.visible
	continue_button = RunUi.button(Strings.t("boss_brief.continue"), true)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.pressed.connect(_on_continue)
	footer.add_child(continue_button)
	confirm_button = continue_button


## The first of the variant's, the brief's and the boss's own line that exists, or "".
func _line(kind: String) -> String:
	var keys: Array[String] = []
	var variant: StringName = brief.get("variant", &"")
	if variant != &"":
		keys.append("boss.%s.%s" % [String(variant), kind])
	var given: String = brief.get("%s_key" % kind, "")
	if given != "":
		keys.append(given)
	var boss_id: StringName = brief.get("id", &"")
	keys.append("boss.%s.%s" % [String(boss_id), kind])
	for key: String in keys:
		if RunUi.has_key(key):
			return Strings.t(key)
	return ""


func _on_continue() -> void:
	_tap_sound()
	_api.continue_run()
