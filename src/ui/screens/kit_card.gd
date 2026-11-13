class_name KitCard
extends RunSelectable
## One kit of the briefing's kit selector (GDD 8.5): a 330 x 150 plate with the kit's name and its state, SELECTED (cyan rim,
## the word, a lifted plate), TAP TO SELECT, or LOCKED with a dim fill for a kit the Archive has not sold yet. The kit's rules
## are read under the list, for the card in focus. State is word plus rim, never colour alone.

const WIDTH: float = 330.0
const HEIGHT: float = 150.0

var kit: KitDef
var owned: bool = true
var name_label: Label
var state_label: Label


func build(def: KitDef, content: ContentSet, is_owned: bool) -> void:
	kit = def
	owned = is_owned
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	add_child(col)
	name_label = RunUi.wrap(RunUi.label(MetaProfile.kit_name(content, def.id), UiTheme.FONT_BODY - 4, &"body", true), 2)
	col.add_child(name_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	state_label = RunUi.label("", RunUi.MIN_TEXT, &"dim", true)
	state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(state_label)
	RunUi.ignore_mouse_except_buttons(self)
	selectable = true
	show_state(false)


## The rules of the kit, or the Archive hint for a locked one.
func rules_text() -> String:
	if not owned:
		return "%s: %s" % [Strings.t("kit.locked_hint"), RunUi.opt(kit.name_key.trim_suffix(".name") + ".desc")]
	return RunUi.opt(kit.name_key.trim_suffix(".name") + ".desc")


func show_state(is_selected: bool) -> void:
	var rim: Color = UiTheme.rim(&"gunmetal", RunUi.hc()).lightened(0.3)
	var role: StringName = &"dim"
	var text: String = Strings.t("kit.pick")
	if not owned:
		text = Strings.t("kit.locked")
	elif is_selected:
		rim = UiTheme.rim(&"warden_cyan", RunUi.hc())
		role = &"friendly"
		text = Strings.t("kit.selected")
	rim_color = rim
	state_label.text = text
	state_label.add_theme_color_override(&"font_color", RunUi.text_color(role))
	set_selected(is_selected and owned)
	set_dimmed(not owned)
