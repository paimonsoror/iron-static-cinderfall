class_name HudBossBar
extends PanelContainer
## A wide red bar with the boss name under the top HUD, shown only while the boss lives (GDD 10.1). In the variety run
## `title_text` replaces the name ("NODE 9 // SIEGE HULK") and phase pips show how many phases the boss has gone through.

var name_label: Label
var pct_label: Label
var pips: HudBossPips
var title_text: String = ""
var bar: HudBar


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var red: Color = HudStyle.color(&"chorus_red")
	add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.alpha(HudStyle.color(&"obsidian"), 0.88), red, HudStyle.CHAMFER, 3))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	add_child(col)
	var row: HBoxContainer = HBoxContainer.new()
	col.add_child(row)
	name_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(name_label)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	pips = HudBossPips.new()
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	pct_label = HudStyle.make_label("-", HudStyle.FONT_BODY, red.lightened(0.25))
	HudStyle.mono(pct_label)
	row.add_child(pct_label)
	bar = HudBar.new()
	bar.custom_minimum_size = Vector2(0.0, 22.0)
	bar.segments = 25
	bar.set_fill_color(red)
	col.add_child(bar)


## Visible only while `hp` is not negative (RunApi.boss_hp() is -1.0 without a boss).
func show_boss(kind: StringName, hp: float, max_hp: float) -> void:
	visible = hp >= 0.0
	if not visible:
		return
	name_label.text = title_text if title_text != "" else Strings.t("enemy.%s.name" % String(kind)).to_upper()
	var frac: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	pct_label.text = "%d%%" % HudStyle.pct(hp, max_hp)
	bar.set_state(frac, 0.0)
