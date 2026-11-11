class_name HudAmmoReadout
extends PanelContainer
## Magazine and reload readout: weapon name, "9/12", and RELOADING with a filling bar (GDD 10.1).

var weapon_label: Label
var mag_label: Label
var status_label: Label
var reload_bar: HudBar


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, HudStyle.TOUCH)
	add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.fill(), HudStyle.color(&"gunmetal")))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	weapon_label = HudStyle.make_label("-", HudStyle.FONT_TINY, HudStyle.color(&"gunmetal").lightened(0.35))
	left.add_child(weapon_label)
	mag_label = HudStyle.make_label("-", 60, HudStyle.color(&"bone_ceramic"))
	HudStyle.mono(mag_label)
	left.add_child(mag_label)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	status_label = HudStyle.make_label("-", HudStyle.FONT_SMALL, HudStyle.color(&"warden_cyan"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	HudStyle.bold(status_label)
	right.add_child(status_label)
	reload_bar = HudBar.new()
	reload_bar.custom_minimum_size = Vector2(0.0, 14.0)
	reload_bar.segments = 8
	reload_bar.set_fill_color(HudStyle.color(&"core_amber"))
	right.add_child(reload_bar)


## `reload_total` is the length of the running reload in ticks (0 when unknown).
func show_ammo(weapon: StringName, mag: int, mag_size: int, reload_left: int, reload_total: int) -> void:
	weapon_label.text = Strings.t("weapon.%s.name" % String(weapon)).to_upper()
	mag_label.text = Strings.tf("hud.ammo.mag", [mag, mag_size])
	if reload_left > 0:
		status_label.text = Strings.t("hud.ammo.reloading")
		status_label.add_theme_color_override(&"font_color", HudStyle.color(&"core_amber"))
		var total: int = maxi(reload_total, reload_left)
		reload_bar.set_state(1.0 - float(reload_left) / float(total), 0.0)
		reload_bar.visible = true
	elif mag <= 0:
		status_label.text = Strings.t("hud.ammo.empty")
		status_label.add_theme_color_override(&"font_color", HudStyle.color(&"chorus_red"))
		reload_bar.visible = false
	else:
		status_label.text = Strings.t("hud.ammo.ready")
		status_label.add_theme_color_override(&"font_color", HudStyle.color(&"warden_cyan"))
		reload_bar.visible = false
