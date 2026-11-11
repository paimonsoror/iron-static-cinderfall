class_name HudCombatStrip
extends PanelContainer
## The "COMBAT CONTINUES" strip above the open drawer during a wave, so nobody thinks the game is paused.

const HEIGHT: float = 56.0

var label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, HEIGHT)
	add_theme_stylebox_override(&"panel", HudStyle.panel(
		HudStyle.alpha(HudStyle.color(&"obsidian"), 0.92), HudStyle.color(&"core_amber"), 10, 2))
	label = HudStyle.make_label(Strings.t("hud.strip"), HudStyle.FONT_SMALL, HudStyle.color(&"core_amber"))
	HudStyle.center(label)
	HudStyle.bold(label)
	add_child(label)
