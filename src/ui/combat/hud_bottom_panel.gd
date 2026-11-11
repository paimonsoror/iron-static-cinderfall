class_name HudBottomPanel
extends Control
## The bottom band: the UPGRADES tab with the affordable count, the magazine and reload readout, and the three
## ability buttons below them (GDD 10.1). Rows are at least 132 px tall; the band grows only on near-square windows.

signal tab_pressed

const TAB_W: float = 470.0
const ROW_MAX: float = 168.0

var tab_button: Button
var tab_label: Label
var chevron: HudChevron
var ammo: HudAmmoReadout
var abilities: HudAbilityBar
var _tab_look: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_button = Button.new()
	tab_button.custom_minimum_size = Vector2(HudStyle.TOUCH * 2.0, HudStyle.TOUCH)
	tab_button.pressed.connect(func() -> void: tab_pressed.emit())
	add_child(tab_button)
	var center: CenterContainer = CenterContainer.new()
	tab_button.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	center.add_child(row)
	tab_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"bone_ceramic"))
	HudStyle.bold(tab_label)
	row.add_child(tab_label)
	chevron = HudChevron.new()
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	HudStyle.ignore_mouse(tab_button)
	ammo = HudAmmoReadout.new()
	add_child(ammo)
	abilities = HudAbilityBar.new()
	add_child(abilities)
	set_tab(0, false)


## The band is `band_h` tall and `width` wide; its own position is set by the HUD. `margins` is the safe area.
func place(width: float, band_h: float, margins: Vector4) -> void:
	size = Vector2(width, band_h)
	var gap: float = HudStyle.GAP
	var left: float = HudStyle.EDGE + margins.x
	var inner_w: float = width - 2.0 * HudStyle.EDGE - margins.x - margins.z
	var content_h: float = band_h - margins.w
	var row_h: float = clampf((content_h - 3.0 * gap) / 2.0, HudStyle.TOUCH, ROW_MAX)
	var top: float = maxf(0.0, (content_h - (2.0 * row_h + gap)) * 0.5)
	tab_button.position = Vector2(left, top)
	tab_button.size = Vector2(TAB_W, row_h)
	ammo.position = Vector2(left + TAB_W + gap, top)
	ammo.size = Vector2(inner_w - TAB_W - gap, row_h)
	abilities.position = Vector2(left, top + row_h + gap)
	abilities.size = Vector2(inner_w, row_h)
	queue_redraw()


## `count` is how many upgrades can be bought now; `open` is whether the drawer is shown.
func set_tab(count: int, open: bool) -> void:
	tab_label.text = Strings.tf("hud.tab", [count])
	chevron.set_up(not open)
	tab_button.tooltip_text = Strings.t("hud.tab.hint_open" if open else "hud.tab.hint_closed")
	var look: int = 1 if count > 0 else 0
	if look == _tab_look:
		return
	_tab_look = look
	var amber: Color = HudStyle.color(&"core_amber")
	var cyan: Color = HudStyle.color(&"warden_cyan")
	if count > 0:
		HudStyle.style_button(tab_button, HudStyle.fill().lerp(amber, 0.18), amber)
		tab_label.add_theme_color_override(&"font_color", amber)
		chevron.color = amber
	else:
		HudStyle.style_button(tab_button, HudStyle.fill(), cyan)
		tab_label.add_theme_color_override(&"font_color", HudStyle.color(&"bone_ceramic"))
		chevron.color = cyan
	chevron.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), HudStyle.alpha(HudStyle.color(&"obsidian"), 0.96))
	draw_rect(Rect2(0.0, 0.0, size.x, 4.0), HudStyle.alpha(HudStyle.color(&"warden_cyan"), 0.55))
