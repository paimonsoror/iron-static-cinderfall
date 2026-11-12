class_name RunUi
extends RefCounted
## Look and small helpers shared by the intermission overlays (draft, route, boss briefing, salvage, build list) and
## the weapon bar of the combat HUD (VARIETY_SPEC 11, GDD 9 and 10.5). Sizes are 1080-wide base pixels. Colors come from
## UiTheme, so High Contrast (thicker, brighter rims, white text, outlines) is one flag read per build.

const MIN_TEXT: int = 30  ## small text never goes below this (GDD 10)
const TOUCH: float = 132.0  ## UiTheme.TOUCH_MIN
const PRIMARY_H: float = 148.0  ## UiTheme.BTN_PRIMARY_H
const EDGE: float = 36.0
const GAP: float = 24.0
const ROMAN: PackedStringArray = ["", "I", "II", "III", "IV", "V"]
const TAGS: PackedStringArray = ["bullet", "blast", "arc", "fortress", "gunline", "hoard", "tempo", "rail"]
## Weapons that carry a tag (VARIETY_SPEC 4.2 "core pieces"): a directive of that tag works with them.
const TAG_WEAPONS: Dictionary[StringName, Array] = {
	&"bullet": [&"smg", &"lmg", &"assault_rifle", &"pistol"],
	&"blast": [&"slag_mortar", &"hornet_rack"],
	&"arc": [&"arc_projector"],
	&"fortress": [&"scattergun"],
	&"rail": [&"rail_lance"],
}


static func hc() -> bool:
	return UiTheme.high_contrast_on()


static func has_key(key: String) -> bool:
	return Content.db != null and Content.db.strings.has(key)


## Strings.t(key) when the table has it, else `fallback` (never a "#key#" marker for optional lines).
static func opt(key: String, fallback: String = "") -> String:
	return Strings.t(key) if has_key(key) else fallback


static func roman(n: int) -> String:
	return ROMAN[n] if n > 0 and n < ROMAN.size() else str(n)


## "ACT II" for act `n`.
static func act_label(n: int) -> String:
	return Strings.tf("act.label", [roman(n)])


## The act's own name ("THE GANTRY LINE"), or "" without the variety content.
static func act_name(content: ContentSet, n: int) -> String:
	if content == null or content.run == null:
		return ""
	var act: ActDef = content.run.act(n)
	return Strings.t(act.name_key) if act != null else ""


## The visible plating of act `n` as +% enemy HP (CONTENT 1.1: 1.35 -> 35).
static func plating_pct(content: ContentSet, n: int) -> int:
	if content == null or content.run == null:
		return 0
	var act: ActDef = content.run.act(n)
	return roundi((act.hp_mult - 1.0) * 100.0) if act != null else 0


## "CHORUS PLATING: TIER 2 (HP +35%)".
static func plating_line(content: ContentSet, n: int) -> String:
	return "%s (%s)" % [Strings.tf("act.tier", [n]), Strings.tf("route.plating_hp", [plating_pct(content, n)])]


static func tag_name(tag: StringName) -> String:
	return Strings.t("tag.%s" % String(tag))


# --- colors and boxes ---


## The rim of a directive rarity: grey, cyan, amber, red (GDD 9).
static func rarity_rim(rarity: int) -> Color:
	var h: bool = hc()
	match rarity:
		DirectiveDef.Rarity.RARE:
			return UiTheme.rim(&"warden_cyan", h)
		DirectiveDef.Rarity.PROTOTYPE:
			return UiTheme.rim(&"core_amber", h)
		DirectiveDef.Rarity.CORRUPTED:
			return UiTheme.rim(&"chorus_red", h)
	return UiTheme.rim(&"gunmetal", h).lightened(0.3)


## A chamfered panel box. `rim_w` 0 = the theme's rim width (5 in High Contrast).
static func box(bg: Color, rim: Color, rim_w: int = 0, chamfer: int = UiTheme.CHAMFER) -> StyleBoxFlat:
	var w: int = rim_w if rim_w > 0 else UiTheme.rim_width(hc())
	var sb: StyleBoxFlat = UiTheme.chamfer_box(bg, rim, chamfer, w)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb


## A small inset plate for a tag chip or a stat cell.
static func chip_box(rim: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var h: bool = hc()
	var sb: StyleBoxFlat = UiTheme.chamfer_box(UiTheme.inset_fill(h), rim if rim.a > 0.0 else UiTheme.rim(&"gunmetal", h), 6, 2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


static func fill() -> Color:
	return UiTheme.panel_fill(hc())


static func text_color(role: StringName) -> Color:
	return UiTheme.text_color(role, hc())


# --- controls ---


## A label of at least MIN_TEXT px in a text role (&"body", &"dim", &"accent", &"friendly", &"danger"). Never takes the mouse.
static func label(text: String, size: int = UiTheme.FONT_BODY, role: StringName = &"body", bold: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", maxi(size, MIN_TEXT))
	l.add_theme_color_override(&"font_color", text_color(role))
	if bold:
		l.add_theme_font_override(&"font", UiTheme.bold_font())
	return l


## Word wrap over `lines` lines (0 = unlimited) with an ellipsis when the text is longer.
static func wrap(l: Label, lines: int = 0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 8.0  # a wrapping label must be told it may be narrow
	if lines > 0:
		l.max_lines_visible = lines
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A square icon of assets/icons (empty when the file is missing), tinted by `tint`.
static func icon(id: StringName, px: float, tint: Color = Color.WHITE) -> TextureRect:
	var r: TextureRect = UiKit.icon(id)
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = tint
	return r


## A button of the run overlays: at least TOUCH_MIN tall, `PRIMARY_H` when primary (amber fill), 38 px text, one tap sound.
static func button(text: String, primary: bool = false, size: int = UiTheme.FONT_BODY) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TOUCH, PRIMARY_H if primary else TOUCH)
	b.add_theme_font_size_override(&"font_size", maxi(size, MIN_TEXT))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.theme_type_variation = UiTheme.BUTTON_PRIMARY if primary else &"Button"
	return b


## Every Control below `root` that is not a Button ignores the mouse (decoration inside a selectable panel).
static func ignore_mouse_except_buttons(root: Node) -> void:
	for child: Node in root.get_children():
		var c: Control = child as Control
		if c != null and not (c is BaseButton):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not (child is BaseButton):
			ignore_mouse_except_buttons(child)


## Names of the carried weapons and held directives a directive of `def` works with (VARIETY_SPEC 11.1).
static func works_with(api: RunApi, content: ContentSet, def: DirectiveDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in api.weapon_slot_count():
		var slot: Dictionary = api.weapon_slot(i)
		var wid: StringName = slot.get("id", &"")
		for tag: StringName in def.tags:
			var ids: Array = TAG_WEAPONS.get(tag, [])
			if ids.has(wid) and not out.has(Strings.t("weapon.%s.name" % String(wid)).to_upper()):
				out.append(Strings.t("weapon.%s.name" % String(wid)).to_upper())
	for other: DirectiveDef in content.directives:
		if other.id == def.id or api.directive_stacks(other.id) <= 0:
			continue
		for tag: StringName in def.tags:
			if other.tags.has(tag):
				out.append(Strings.t(other.name_key))
				break
	return out
