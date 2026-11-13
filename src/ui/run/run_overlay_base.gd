class_name RunOverlayBase
extends Control
## The frame the four intermission overlays share (VARIETY_SPEC 11, GDD 10.5): a dimming scrim over the frozen battlefield,
## the display safe area, the High Contrast theme, and three bands: `header` (information only, top), `controls` (the
## choices) and `footer` (the buttons), the last two stuck to the bottom so every control is in the lower part of the screen
## (the one-handed rule). Every choice is two taps: a selection never commits, CONFIRM does. The overlay reads and writes
## only through the RunApi (every command takes a fresh next_command_id) and listens to Events for refusals and re-offers.
## Subclasses fill the bands in `_populate()` and update them in `refresh()`.

const SCRIM_ALPHA: float = 0.84
const COMPACT_HEIGHT: float = 1500.0  ## below this the screen drops its optional rows (a near-square window)
const NOTICE_SECONDS: float = 3.0
const POLL_SECONDS: float = 0.25

var header: VBoxContainer
var controls: VBoxContainer
var footer: VBoxContainer
var confirm_button: Button
var notice_label: Label
var info_label: Label
var act_label_node: Label
var wave_label: Label
var core_label: Label
var scrap_label: Label
var modal: Control  ## the open detail panel or build list, or null
var hint_lines: Array[RunHintLine] = []  ## the first-run hints this screen showed (at most one per key, once per profile)

var _api: RunApi
var _content: ContentSet
var _scrim: TextureRect
var _margin: MarginContainer
var _column: VBoxContainer
var _safe: Vector4 = Vector4.ZERO
var _notice_left: float = 0.0
var _poll: float = 0.0
var _built: bool = false
var _bindings: Array = []  ## [Signal, Callable] pairs, disconnected on exit


func _init() -> void:
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_tree() -> void:
	if _api != null and _bindings.is_empty():
		_bind_events()
	var root: Window = get_tree().root
	if not root.size_changed.is_connected(_apply_os_safe_area):
		root.size_changed.connect(_apply_os_safe_area)


func _exit_tree() -> void:
	_unbind_all()
	var root: Window = get_tree().root
	if root.size_changed.is_connected(_apply_os_safe_area):
		root.size_changed.disconnect(_apply_os_safe_area)


func _process(delta: float) -> void:
	if _api == null:
		return
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			notice_label.visible = false
	_poll += delta
	if _poll >= POLL_SECONDS:
		_poll = 0.0
		refresh_info()
		refresh()


## Safe-area insets (left, top, right, bottom) in viewport units.
func set_safe_margins(margins: Vector4) -> void:
	_safe = margins
	if _margin != null:
		_apply_margins()


func safe_margins() -> Vector4:
	return _safe


## True on a near-square window: optional rows are left out so the choices still fit.
func is_compact() -> bool:
	return size.y < COMPACT_HEIGHT


# --- for the subclasses ---


func _open(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	_unbind_all()
	_build_frame()
	_populate()
	_bind_events()
	_relayout()
	refresh_info()
	refresh()
	_apply_os_safe_area()


## Fills `header`, `controls` and `footer`. Called again when High Contrast is switched.
func _populate() -> void:
	pass


## Re-reads the queries into the labels and button states (cheap; 4 Hz and on signals).
func refresh() -> void:
	pass


## The compact or tall layout of the choice cards; called on every resize.
func _relayout() -> void:
	pass


func _bind_events() -> void:
	_bind(Events.scrap_changed, func(_value: int) -> void: refresh_info())
	_bind(Events.core_changed, func(_cur: float, _max_hp: float) -> void: refresh_info())
	_bind(Events.command_rejected, _on_rejected)
	_bind(Events.settings_changed, _on_setting_changed)


func _bind(sig: Signal, handler: Callable) -> void:
	sig.connect(handler)
	_bindings.append([sig, handler])


func _unbind_all() -> void:
	for pair: Array in _bindings:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	_bindings.clear()


## The info band: `left` (bold, amber), then CORE % and Scrap. Information only.
func _add_info_band(left: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	info_label = RunUi.label(left, UiTheme.FONT_BODY, &"accent", true)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(info_label)
	core_label = RunUi.label("-", UiTheme.FONT_BODY, &"body", true)
	row.add_child(core_label)
	row.add_child(RunUi.icon(&"scrap", 44.0))
	scrap_label = RunUi.label("-", UiTheme.FONT_BODY, &"accent", true)
	row.add_child(scrap_label)
	header.add_child(row)


## The act banner of the route and boss screens: "ACT II  THE GANTRY LINE" and "WAVE 7 OF 15", then the visible plating
## tier with CORE and Scrap. Information only.
func _add_act_band(act: int, wave_number: int) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	act_label_node = RunUi.label("%s  %s" % [RunUi.act_label(act), RunUi.act_name(_content, act)], UiTheme.FONT_BODY, &"accent", true)
	act_label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_label_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(act_label_node)
	wave_label = RunUi.label(Strings.tf("route.wave_of", [wave_number, _api.wave_count()]), UiTheme.FONT_BODY, &"body", true)
	line.add_child(wave_label)
	header.add_child(line)
	var second: HBoxContainer = HBoxContainer.new()
	second.add_theme_constant_override(&"separation", 18)
	info_label = RunUi.label(RunUi.plating_line(_content, act), RunUi.MIN_TEXT, &"dim")
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	second.add_child(info_label)
	core_label = RunUi.label("-", UiTheme.FONT_BODY - 4, &"body", true)
	second.add_child(core_label)
	second.add_child(RunUi.icon(&"scrap", 40.0))
	scrap_label = RunUi.label("-", UiTheme.FONT_BODY - 4, &"accent", true)
	second.add_child(scrap_label)
	header.add_child(second)


func refresh_info() -> void:
	if core_label == null:
		return
	core_label.text = Strings.tf("hud.core_pct", [UiKit.percent(_api.core_hp(), _api.core_max_hp())])
	scrap_label.text = UiKit.group(_api.scrap())


## One first-run hint line in the header (GDD 10.4): the hint of `key` ("hint.draft") when this profile has not seen it. The
## choice screens cover the combat HUD's hint banner, so they show their own. A hint counts as seen when it is on screen: a
## near-square window has no room for a second line, so it shows one at a time and the other waits for a later screen. Null
## when the hint was seen before, is already on this screen or has no text.
func add_hint(key: String) -> RunHintLine:
	if not RunHintLine.due(key):
		return null
	for existing: RunHintLine in hint_lines:
		if existing.key == key:
			return null
	var line: RunHintLine = RunHintLine.new(key)
	header.add_child(line)
	hint_lines.append(line)
	_sync_hints()
	return line


## Shows the hint lines that have room (all on a tall screen, the first on a compact one) and remembers them as seen.
func _sync_hints() -> void:
	var compact: bool = is_compact()
	var shown: int = 0
	for line: RunHintLine in hint_lines:
		var show: bool = not compact or shown == 0
		line.visible = show
		if show:
			shown += 1
			Save.mark_hint_seen(line.key)
	_relayout()  # a screen that is short of room gives the hint's space back to its choices


## A command id for one tap; the API call is the caller's.
func _next_id() -> int:
	return _api.next_command_id()


func _tap_sound() -> void:
	Sfx.play(&"ui_tap")


## A refused choice (nothing was sent): the deny sound, a short shake and the reason in the notice line.
func deny(target: Control, reason_text: String = "") -> void:
	Sfx.play(&"ui_deny")
	if reason_text != "":
		_show_notice(reason_text)
	if target == null or not is_inside_tree() or HudStyle.reduced_flash():
		return
	target.pivot_offset = target.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(target, "rotation", 0.03, 0.04)
	tw.tween_property(target, "rotation", -0.03, 0.08)
	tw.tween_property(target, "rotation", 0.0, 0.04)


## Opens a full-rect modal (a detail panel or the build list) above everything and frees it on its `closed` signal.
func open_modal(node: Control) -> void:
	close_modal()
	modal = node
	add_child(node)
	if node.has_signal(&"closed"):
		node.connect(&"closed", close_modal)


func close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null


# --- frame ---


func _build_frame() -> void:
	if _built:
		return
	_built = true
	theme = UiTheme.shared(RunUi.hc())
	_scrim = TextureRect.new()
	_scrim.texture = _scrim_texture()
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_scrim)
	add_child(_scrim)
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_margin)
	add_child(_margin)
	_column = VBoxContainer.new()
	_margin.add_child(_column)
	header = VBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	_column.add_child(header)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(spacer)
	controls = VBoxContainer.new()
	_column.add_child(controls)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 12)
	_column.add_child(footer)
	_apply_margins()
	_density()
	resized.connect(_density)
	resized.connect(_relayout)
	resized.connect(_sync_hints)


## The dimming layer: fully opaque where the HUD bands sit (so not a trace of the combat HUD shows through the header, the
## gaps between the cards or the footer) and lighter in the middle, where the frozen battlefield shows. High Contrast dims
## the middle more.
func _scrim_texture() -> GradientTexture2D:
	var tone: Color = UiTheme.color(&"obsidian").lerp(Color.BLACK, 0.35)
	var strong: float = 1.0
	var mid: float = SCRIM_ALPHA + (0.08 if RunUi.hc() else 0.0) - 0.04
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.17, 0.31, 0.45, 0.55, 1.0])
	g.colors = PackedColorArray([
		UiTheme.alpha(tone, strong), UiTheme.alpha(tone, strong), UiTheme.alpha(tone, mid),
		UiTheme.alpha(tone, mid), UiTheme.alpha(tone, strong), UiTheme.alpha(tone, strong),
	])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 256
	return tex


## The gaps between the bands and the choices shrink on a near-square screen (the choices must still fit).
func _density() -> void:
	var gap: int = 12 if is_compact() and size.y > 2.0 else int(RunUi.GAP)
	_column.add_theme_constant_override(&"separation", gap)
	controls.add_theme_constant_override(&"separation", gap)


func _apply_margins() -> void:
	_margin.add_theme_constant_override(&"margin_left", roundi(RunUi.EDGE + _safe.x))
	_margin.add_theme_constant_override(&"margin_top", roundi(RunUi.EDGE + _safe.y))
	_margin.add_theme_constant_override(&"margin_right", roundi(RunUi.EDGE + _safe.z))
	_margin.add_theme_constant_override(&"margin_bottom", roundi(RunUi.EDGE + _safe.w))


## Mobile only, and only in the real window (a capture SubViewport has no OS safe area).
func _apply_os_safe_area() -> void:
	if not is_inside_tree() or not OS.has_feature("mobile") or get_viewport() != get_tree().root:
		return
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	set_safe_margins(SafeArea.margins(win, safe, get_viewport_rect().size))


func _show_notice(text: String) -> void:
	if notice_label == null:
		notice_label = RunUi.label("", RunUi.MIN_TEXT, &"danger", true)
		header.add_child(notice_label)
	notice_label.text = text
	notice_label.visible = true
	_notice_left = NOTICE_SECONDS


func _on_rejected(_command_id: int, reason: int) -> void:
	var text: String = ""
	if reason > 0 and reason < Reason.KEYS.size():
		text = RunUi.opt(Reason.KEYS[reason])
	deny(confirm_button, text)


## High Contrast switched: new theme, new rims, the bands rebuilt from the queries.
func _on_setting_changed(key: StringName) -> void:
	if key != &"high_contrast" or not _built:
		return
	theme = UiTheme.shared(RunUi.hc())
	_scrim.texture = _scrim_texture()
	for band: Control in [header, controls, footer]:
		for child: Node in band.get_children():
			band.remove_child(child)
			child.queue_free()
	notice_label = null
	hint_lines.clear()
	_populate()
	_relayout()
	refresh_info()
	refresh()
