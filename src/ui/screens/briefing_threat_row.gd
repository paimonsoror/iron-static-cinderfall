class_name BriefingThreatRow
extends PanelContainer
## One line of the briefing's threat list: the drawn silhouette, the machine's name and what it does, and its rank
## as amber chevrons (armory_style.png rows).

const GLYPH_PX: float = 132.0

var glyph: UiEnemyGlyph
var name_label: Label
var desc_label: Label
var chevrons: UiChevrons


func _init(enemy: EnemyDef = null, rank: int = 1, ranks: int = 4) -> void:
	theme_type_variation = UiTheme.PANEL_INSET
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	var id: StringName = &"skitter"
	var name_text: String = ""
	if enemy != null:
		id = enemy.id
		name_text = Strings.t(enemy.name_key).to_upper()
	glyph = UiEnemyGlyph.new(id, GLYPH_PX)
	if not RunEnemyGlyph.LEGACY.has(id):  # a type of the variety roster: its silhouette is drawn by RunEnemyGlyph
		glyph.hide_art = true
		var art: RunEnemyGlyph = RunEnemyGlyph.new(id, GLYPH_PX)
		UiKit.fill(art)
		glyph.add_child(art)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	name_label = UiKit.label_text(name_text, UiTheme.LABEL_HEADING, UiTheme.FONT_BODY + 6)
	text.add_child(name_label)
	# the briefing line of the machine; a boss has its ATTACK line (approved text); a type with neither shows none (no "#key#")
	desc_label = UiKit.label_text(RunUi.opt("lore.threat.%s" % String(id), RunUi.opt("boss.%s.attack" % String(id))), UiTheme.LABEL_CAPTION)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.visible = desc_label.text != ""
	text.add_child(desc_label)
	chevrons = UiChevrons.new(rank, ranks)
	chevrons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevrons)
