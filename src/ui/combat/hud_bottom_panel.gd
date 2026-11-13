class_name HudBottomPanel
extends Control
## The bottom band: the UPGRADES tab with the affordable count, the magazine and reload readout, and the three
## ability buttons below them (GDD 10.1). Rows are at least 132 px tall; the band grows only on near-square windows.
## In the variety run (`set_variety`) the tab and the readout give way to the weapon bar (VARIETY_SPEC 11.4): a 150 px
## weapon row over the ability row.

signal tab_pressed

const TAB_W: float = 470.0
const ROW_MAX: float = 168.0

var tab_button: Button
var tab_label: Label
var chevron: HudChevron
var ammo: HudAmmoReadout
var abilities: HudAbilityBar
var weapon_bar: HudWeaponBar
var variety: bool = false
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
	weapon_bar = HudWeaponBar.new()
	weapon_bar.visible = false
	add_child(weapon_bar)
	set_tab(0, false)


## The variety run: the weapon bar replaces the tab and the readout.
func set_variety(on: bool, api: RunApi, content: ContentSet) -> void:
	variety = on
	tab_button.visible = not on
	ammo.visible = not on
	weapon_bar.visible = on
	if on:
		weapon_bar.setup(api, content)


## The smallest band the two variety rows fit in: the weapon row, the ability row and three gaps.
static func variety_min_px() -> float:
	return HudWeaponCard.HEIGHT + HudStyle.TOUCH + 3.0 * HudStyle.GAP


## The band that holds the two variety rows at their full size with a gap above, between and below them: more than this is
## an empty strip.
static func variety_fit_px() -> float:
	return HudWeaponCard.HEIGHT + ROW_MAX + 3.0 * HudStyle.GAP


## The band is `band_h` tall and `width` wide; its own position is set by the HUD. `margins` is the safe area.
func place(width: float, band_h: float, margins: Vector4) -> void:
	size = Vector2(width, band_h)
	var gap: float = HudStyle.GAP
	var left: float = HudStyle.EDGE + margins.x
	var inner_w: float = width - 2.0 * HudStyle.EDGE - margins.x - margins.z
	var content_h: float = band_h - margins.w
	if variety:
		var weapon_h: float = HudWeaponCard.HEIGHT
		var low_h: float = clampf(content_h - weapon_h - 3.0 * gap, HudStyle.TOUCH, ROW_MAX)
		var start: float = maxf(0.0, (content_h - (weapon_h + gap + low_h)) * 0.5)
		weapon_bar.position = Vector2(left, start)
		weapon_bar.place(inner_w, weapon_h)
		abilities.position = Vector2(left, start + weapon_h + gap)
		abilities.size = Vector2(inner_w, low_h)
		queue_redraw()
		return
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
