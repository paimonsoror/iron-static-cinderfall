class_name HudBanners
extends Control
## Everything that floats over the battlefield and never takes a tap: a stack under the top band (boss bar,
## low-core warning), the wave banner with its whisper line, and the one-line hint above the drawer.

var boss_bar: HudBossBar
var ticker: HudThreatTicker
var edge_arrows: HudEdgeArrows  ## chevrons at the field's edge toward an incoming RECOUNT or breach (the variety run)
var warn_panel: PanelContainer
var warn_label: Label
var banner_box: PanelContainer
var banner_title: Label
var banner_whisper: Label
var hint_panel: PanelContainer
var hint_label: Label
const TITLE_MIN: int = 48  ## the banner title never shrinks below this (body text is 38)
const WHISPER_MIN: int = 30  ## ... nor the whisper line (small text is never under 30)

var _stack: VBoxContainer
var _inner_w: float = 1032.0
var _bottom_reserved: float = 0.0
var _banner_tween: Tween
var _hint_tween: Tween
var _warn_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_arrows = HudEdgeArrows.new()
	add_child(edge_arrows)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override(&"separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.minimum_size_changed.connect(fit_arrows)  # a boss bar or a ticker line appearing moves the arrows' zone
	add_child(_stack)
	boss_bar = HudBossBar.new()
	_stack.add_child(boss_bar)
	ticker = HudThreatTicker.new()  # the variety run's threat ticker; hidden in the legacy HUD
	ticker.visible = false
	_stack.add_child(ticker)
	_build_warning()
	_build_banner()
	_build_hint()


func _build_warning() -> void:
	var red: Color = HudStyle.color(&"chorus_red")
	warn_panel = PanelContainer.new()
	warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_panel.visible = false
	warn_panel.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.alpha(HudStyle.color(&"obsidian"), 0.88), red, 10, 3))
	_stack.add_child(warn_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	warn_panel.add_child(row)
	row.add_child(HudStyle.icon(&"core", 44.0))
	warn_label = HudStyle.make_label("-", HudStyle.FONT_BODY, red.lightened(0.3))
	HudStyle.bold(warn_label)
	row.add_child(warn_label)


func _build_banner() -> void:
	banner_box = PanelContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.visible = false
	banner_box.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.alpha(HudStyle.color(&"obsidian"), 0.6), Color.TRANSPARENT, 18, 0))
	add_child(banner_box)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	banner_box.add_child(col)
	banner_title = HudStyle.make_label("-", HudStyle.FONT_TITLE, HudStyle.color(&"bone_ceramic"))
	HudStyle.center(banner_title)
	HudStyle.bold(banner_title)
	HudStyle.outline(banner_title, 8)
	banner_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # never wider than the box (see _fit_banner)
	col.add_child(banner_title)
	banner_whisper = HudStyle.make_label("-", 34, HudStyle.color(&"warden_cyan"))
	HudStyle.center(banner_whisper)
	HudStyle.mono(banner_whisper)
	HudStyle.outline(banner_whisper, 6)
	# one line, never autowrap: an autowrap label measured before its first layout asks for one word per line
	banner_whisper.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(banner_whisper)


func _build_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	hint_panel.add_theme_stylebox_override(&"panel", HudStyle.panel(HudStyle.alpha(HudStyle.color(&"obsidian"), 0.92), HudStyle.color(&"warden_cyan"), 12, 3))
	add_child(hint_panel)
	hint_label = HudStyle.make_label("-", HudStyle.FONT_BODY, HudStyle.color(&"bone_ceramic"))
	HudStyle.center(hint_label)
	HudStyle.bold(hint_label)
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_panel.add_child(hint_label)


## Fills `zone` (the battlefield between the bands). `bottom_reserved` is the height of the drawer stack the
## hint line must stay above. `margins` is the safe area (left, top, right, bottom).
func place(zone: Rect2, margins: Vector4, bottom_reserved: float) -> void:
	position = zone.position
	size = zone.size
	_bottom_reserved = bottom_reserved
	var inner_w: float = zone.size.x - 2.0 * HudStyle.EDGE - margins.x - margins.z
	_inner_w = inner_w
	_fit_banner()
	var left: float = HudStyle.EDGE + margins.x
	_stack.position = Vector2(left, 10.0)
	_stack.size = Vector2(inner_w, 0.0)
	var stack_bottom: float = _stack.position.y + _stack.get_combined_minimum_size().y
	banner_box.custom_minimum_size = Vector2(inner_w, 0.0)
	banner_box.size = Vector2(inner_w, 0.0)
	banner_box.position = Vector2(left, maxf(zone.size.y * 0.16, stack_bottom + 16.0))
	hint_panel.custom_minimum_size = Vector2(inner_w, 0.0)
	hint_panel.size = Vector2(inner_w, 0.0)
	hint_panel.position = Vector2(left, maxf(0.0, zone.size.y - bottom_reserved - hint_panel.get_combined_minimum_size().y - 16.0))
	fit_arrows()


## The edge arrows fill the battlefield below the stacked bars (boss bar, ticker lines), so an arrow never sits under them.
func fit_arrows() -> void:
	var top: float = minf(_stack.position.y + _stack.get_combined_minimum_size().y + 8.0, size.y)
	edge_arrows.position = Vector2(0.0, top)
	edge_arrows.size = Vector2(size.x, maxf(size.y - top, 0.0))
	edge_arrows.avoid = Rect2()
	if banner_box.visible:
		var need: Vector2 = banner_box.get_combined_minimum_size()
		edge_arrows.avoid = Rect2(banner_box.position - edge_arrows.position, Vector2(maxf(banner_box.size.x, need.x), need.y))
	edge_arrows.replace(position + edge_arrows.position)


func set_boss(kind: StringName, hp: float, max_hp: float) -> void:
	boss_bar.show_boss(kind, hp, max_hp)


## Shows the wave banner and its whisper line (one per wave, GDD 2.3, 7).
func show_wave(index: int) -> void:
	show_text(Strings.tf("hud.banner.wave", [index]), Strings.t("hud.whisper.%d" % clampi(index, 1, 5)), 3.2)


func show_boss_banner(kind: StringName) -> void:
	var boss_name: String = Strings.t("enemy.%s.name" % String(kind)).to_upper()
	show_text(Strings.tf("hud.banner.boss", [boss_name]), Strings.t("hud.whisper.boss"), 4.0)


## `hold` seconds on screen, or until hide_banner() when it is 0 or less.
func show_text(title: String, whisper: String, hold: float) -> void:
	banner_title.text = title
	banner_whisper.text = whisper
	_fit_banner()
	banner_box.visible = true
	fit_arrows()
	_kill(_banner_tween)
	banner_box.modulate.a = 1.0
	if hold <= 0.0 or not is_inside_tree():
		return
	banner_box.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner_box, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(hide_banner)


## A long title ("NODE 5 // LANCE PLATFORM") or whisper would make the banner wider than the screen: the type steps down until the
## line fits the width (never below TITLE_MIN / WHISPER_MIN), and a line that still does not fit is trimmed with an ellipsis.
func _fit_banner() -> void:
	_fit(banner_title, HudStyle.FONT_TITLE, TITLE_MIN, 4)
	_fit(banner_whisper, 34, WHISPER_MIN, 2)


func _fit(label: Label, base_px: int, min_px: int, step: int) -> void:
	var font: Font = label.get_theme_font(&"font")
	var room: float = _inner_w - 56.0  # the panel margins and the outline
	var px: int = base_px
	while px > min_px and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > room:
		px -= step
	label.add_theme_font_size_override(&"font_size", maxi(px, min_px))


func hide_banner() -> void:
	_kill(_banner_tween)
	banner_box.visible = false
	fit_arrows()


## One line above the drawer for a few seconds (Events.hint_requested).
func show_hint(text_line: String) -> void:
	hint_label.text = text_line
	hint_panel.visible = true
	hint_panel.size = Vector2(hint_panel.size.x, 0.0)
	hint_panel.position.y = maxf(0.0, size.y - _bottom_reserved - hint_panel.get_combined_minimum_size().y - 16.0)
	_kill(_hint_tween)
	hint_panel.modulate.a = 1.0
	if not is_inside_tree():
		return
	hint_panel.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_panel, "modulate:a", 1.0, 0.15)
	_hint_tween.tween_interval(4.0)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(hide_hint)


func hide_hint() -> void:
	_kill(_hint_tween)
	hint_panel.visible = false


## The core below 25%: a red line with the percentage that pulses (a steady line under Reduced Flash).
func set_low_core(active: bool, pct: int) -> void:
	warn_label.text = Strings.tf("hud.warn.core", [pct])
	if active == warn_panel.visible:
		return
	warn_panel.visible = active
	_kill(_warn_tween)
	warn_panel.modulate.a = 1.0
	if active and is_inside_tree() and not HudStyle.reduced_flash():
		_warn_tween = create_tween().set_loops()
		_warn_tween.tween_property(warn_panel, "modulate:a", 0.55, 0.5)
		_warn_tween.tween_property(warn_panel, "modulate:a", 1.0, 0.5)


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
