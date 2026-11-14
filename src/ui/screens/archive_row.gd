class_name ArchiveRow
extends RunSelectable
## One unlock of the Archive (VARIETY_SPEC 11.6): a 500 x 200 plate with the name, a silhouette or mark, the rules in a line
## or two, and its state: OWNED, the price (amber), the price dimmed while the Data falls short, LOCKED while its tier is
## closed, UNLOCKING while its UNDO window runs. State is word plus rim, never colour alone. A tap selects the row; the screen's
## UNLOCK button buys it.

const MIN_W: float = 500.0  ## the width on a 1080 screen (two columns); it is not a minimum: the row shrinks with its column
const MIN_H: float = 200.0

var def: UnlockDef
var state: int = ArchiveModel.State.POOR
var name_label: Label
var state_label: Label
var desc_label: Label


func build(unlock: UnlockDef, content: ContentSet) -> void:
	def = unlock
	custom_minimum_size = Vector2(0.0, MIN_H)  # a minimum width here made two columns wider than a phone (the state line is long)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	add_child(row)
	var mark: TextureRect = RunUi.icon(StringName(mark_icon(unlock, content)), 64.0)
	mark.custom_minimum_size = Vector2(96.0, 64.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 4)
	row.add_child(col)
	name_label = RunUi.wrap(RunUi.label(ArchiveModel.display_name(unlock), UiTheme.FONT_BODY, &"body", true), 2)
	col.add_child(name_label)
	state_label = RunUi.wrap(RunUi.label("", RunUi.MIN_TEXT + 2, &"accent", true), 2)  # "80 DATA  (NEED 40 MORE)" wraps in a narrow column
	col.add_child(state_label)
	desc_label = RunUi.wrap(RunUi.label(ArchiveModel.description(unlock), RunUi.MIN_TEXT, &"dim"), 2)
	col.add_child(desc_label)
	RunUi.ignore_mouse_except_buttons(self)
	set_state(ArchiveModel.State.POOR, 0)


## The icon id of a row: the weapon silhouette of an armory row, the tag glyph of a directive pack, one of the six kit marks (assets/icons/kit_*.svg) for a kit, the core ring for a kit that has none.
static func mark_icon(unlock: UnlockDef, content: ContentSet) -> String:
	match unlock.branch:
		UnlockDef.Branch.ARMORY:
			if not unlock.grants.is_empty():
				return "weapon_%s" % String(unlock.grants[0])
		UnlockDef.Branch.DIRECTIVES:
			for granted: StringName in unlock.grants:
				var directive: DirectiveDef = content.directive(granted) if content != null else null
				if directive != null and not directive.tags.is_empty():
					return "tag_%s" % String(directive.tags[0])
		UnlockDef.Branch.KITS:
			if not unlock.grants.is_empty():
				var kit_mark: String = "kit_%s" % String(unlock.grants[0]).trim_prefix("k_")
				if ResourceLoader.exists("res://assets/icons/%s.svg" % kit_mark):
					return kit_mark
			return "cat_core"
	return "ticker_help"


## `missing` is the Data a POOR row still lacks.
func set_state(new_state: int, missing: int) -> void:
	state = new_state
	var rim: Color = UiTheme.rim(&"gunmetal", RunUi.hc()).lightened(0.3)
	var role: StringName = &"accent"
	var text: String = ""
	match state:
		ArchiveModel.State.OWNED:
			rim = UiTheme.rim(&"warden_cyan", RunUi.hc())
			role = &"friendly"
			text = Strings.t("archive.owned")
		ArchiveModel.State.AVAILABLE:
			rim = UiTheme.rim(&"core_amber", RunUi.hc())
			text = Strings.tf("archive.cost", [UiKit.group(def.cost)])
		ArchiveModel.State.PENDING:
			rim = UiTheme.rim(&"core_amber", RunUi.hc())
			role = &"friendly"
			text = Strings.t("archive.unlocking")
		ArchiveModel.State.TIER_LOCKED:
			role = &"dim"
			text = Strings.tf("archive.locked_cost", [UiKit.group(def.cost)])
		_:
			role = &"dim"
			text = Strings.tf("archive.cost_short", [UiKit.group(def.cost), UiKit.group(maxi(missing, 0))])
	rim_color = rim
	state_label.text = text
	state_label.add_theme_color_override(&"font_color", RunUi.text_color(role))
	restyle()
