class_name ArchiveDetail
extends PanelContainer
## The detail panel at the foot of the Archive (VARIETY_SPEC 11.6): the selected row's name and tier, a stat line (a weapon's
## numbers, the directives of a pack), its rules text, and the line that says why it cannot be bought yet. The UNLOCK button
## that belongs to it is the screen's; this panel only describes.

var name_label: Label
var meta_label: Label
var text_label: Label
var why_label: Label


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_INSET
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	name_label = UiKit.label_text("", UiTheme.LABEL_HEADING, UiTheme.FONT_BODY + 4)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	meta_label = UiKit.label_text("", UiTheme.LABEL_ACCENT, RunUi.MIN_TEXT + 2)
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(meta_label)
	text_label = UiKit.label_text("", &"", RunUi.MIN_TEXT + 2)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text_label)
	why_label = UiKit.label_text("", UiTheme.LABEL_DANGER, RunUi.MIN_TEXT)
	why_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(why_label)


## Describes `def` (null clears the panel) with its current `state` (ArchiveModel.State), the Data a POOR row lacks and the
## unlocks a closed tier still needs.
func show_row(def: UnlockDef, content: ContentSet, state: int, missing: int, unlocks_needed: int) -> void:
	if def == null:
		name_label.text = ""
		meta_label.text = ""
		text_label.text = Strings.t("archive.pick")
		why_label.text = ""
		_hide_empty()
		return
	name_label.text = ArchiveModel.display_name(def)
	meta_label.text = _meta(def, content)
	text_label.text = _body(def, content)
	match state:
		ArchiveModel.State.TIER_LOCKED:
			why_label.text = Strings.tf("archive.gate_needed", [unlocks_needed])
		ArchiveModel.State.POOR:
			why_label.text = Strings.tf("archive.need_data", [UiKit.group(maxi(missing, 0))])
		_:
			why_label.text = ""
	_hide_empty()


## An empty line takes no room (and is no empty label on screen).
func _hide_empty() -> void:
	for label: Label in [name_label, meta_label, text_label, why_label]:
		label.visible = label.text != ""


## "T4  DMG 20  4.0/s  MAG 150" for a weapon, "TIER 2  DIRECTIVES" otherwise.
static func _meta(def: UnlockDef, content: ContentSet) -> String:
	var tier: String = Strings.tf("archive.tier", [def.tier])
	if def.branch == UnlockDef.Branch.ARMORY and not def.grants.is_empty():
		var weapon: WeaponDef = content.weapon(def.grants[0]) if content != null else null
		if weapon != null:
			return "%s  %s  %s" % [tier, Strings.tf("salvage.tier", [weapon.tier]), WeaponStats.line(weapon, 1)]
	return "%s  %s" % [tier, Strings.t("archive.tab.%s" % UnlockDef.BRANCH_NAMES[def.branch])]


## The rules text, and for a directive pack the names of the directives it adds to the pool.
static func _body(def: UnlockDef, content: ContentSet) -> String:
	var text: String = ArchiveModel.description(def)
	if def.branch == UnlockDef.Branch.DIRECTIVES and content != null:
		var names: PackedStringArray = PackedStringArray()
		for granted: StringName in def.grants:
			var directive: DirectiveDef = content.directive(granted)
			if directive != null:
				names.append(Strings.t(directive.name_key))
		if not names.is_empty():
			text = "%s\n%s" % [text, ", ".join(names)] if text != "" else ", ".join(names)
	return text
