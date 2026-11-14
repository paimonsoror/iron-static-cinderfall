class_name CombatHud
extends Control
## The whole combat interface, driven only by RunApi and Events (ARCH 7.2, 9; GDD 10.1).
##
## Zones: a top band (pause, core bar, wave, Scrap), a bottom band (the weapon bar or the magazine readout, three
## ability buttons) and, between them, floating banners and the breather panel. Each tap mints one
## RunApi.next_command_id() and issues one command; everything else is shown. Text comes from Strings, numbers update on
## signals and at 10 Hz. (The upgrade drawer of the 5-wave shop, its tab hookup and the "combat continues" strip went in
## V5-A: the generated run has no shop.)

signal pause_requested

const REFRESH_PERIOD: float = 0.1
const TOP_MIN: float = 148.0  ## a 132 px button plus padding: the band never gets thinner than this
const BOTTOM_MIN: float = 300.0  ## two 132 px rows plus three gaps
const LOW_CORE: float = 0.25

var top_bar: HudTopBar
var bottom: HudBottomPanel
var intermission: HudIntermissionPanel
var banners: HudBanners
var variety: HudVarietyLink  ## the generated run's weapon bar, ticker and act line (inactive on the legacy content)

var _api: RunApi
var _content: ContentSet
var _built: bool = false
var _margins: Vector4 = Vector4.ZERO  ## safe area: left, top, right, bottom
var _poll: float = 0.0
var _boss_kind: StringName = &"siege_hulk"
var _reload_total: int = 0
var _inter_wave: int = 0
var _deploy_shown: bool = false
var _bindings: Array = []  ## [Signal, Callable] pairs, disconnected on exit


func _ready() -> void:
	_ensure_built()
	var root: Window = get_tree().root
	if not root.size_changed.is_connected(_apply_os_safe_area):
		root.size_changed.connect(_apply_os_safe_area)
	_apply_os_safe_area()


func _enter_tree() -> void:
	if _api != null and _bindings.is_empty():
		_bind_events()


func _exit_tree() -> void:
	_unbind_all()
	var root: Window = get_tree().root
	if root.size_changed.is_connected(_apply_os_safe_area):
		root.size_changed.disconnect(_apply_os_safe_area)


func setup(api: RunApi, content: ContentSet, view: BattleView) -> void:
	_ensure_built()
	_unbind_all()
	_api = api
	_content = content
	bottom.abilities.setup(api)
	variety.setup(api, content, view)
	_bind_events()
	refresh()
	_relayout()


func _process(delta: float) -> void:
	if _api == null:
		return
	variety.process(delta)
	_poll += delta
	if _poll >= REFRESH_PERIOD:
		_poll = 0.0
		refresh()


## Re-reads every query. The HUD does this at 10 Hz and the signal handlers call the matching part.
func refresh() -> void:
	if _api == null or not _built:
		return
	_apply_core(_api.core_hp(), _api.core_max_hp())
	top_bar.set_wave(_api.wave(), _api.wave_count())
	top_bar.set_scrap(_api.scrap())
	bottom.abilities.refresh()
	_refresh_ammo()
	banners.set_boss(_boss_kind, _api.boss_hp(), _api.boss_max_hp())
	_refresh_phase()
	variety.refresh()


## Height of the band the HUD reserves at the top (the camera fits below it).
func top_band_px() -> float:
	if _content == null:
		return 0.0
	var band: float = HudLayout.top_band_px(_view_size(), _margins, _content.tokens)
	return maxf(band, TOP_MIN + _margins.y)


func bottom_band_px() -> float:
	if _content == null:
		return 0.0
	var band: float = HudLayout.bottom_band_px(_view_size(), _margins, _content.tokens)
	return variety.bottom_band(maxf(band, BOTTOM_MIN + _margins.w), _view_size().y, _margins.w)


## Safe-area insets (left, top, right, bottom) in viewport units; the top bar and bottom band move by them.
func set_safe_margins(margins: Vector4) -> void:
	_margins = margins
	_relayout()


# --- build and layout ---


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banners = HudBanners.new()
	add_child(banners)
	intermission = HudIntermissionPanel.new()
	intermission.visible = false
	intermission.continue_pressed.connect(_on_continue)
	add_child(intermission)
	bottom = HudBottomPanel.new()
	add_child(bottom)
	top_bar = HudTopBar.new()
	top_bar.pause_pressed.connect(_on_pause)
	add_child(top_bar)
	resized.connect(_relayout)
	variety = HudVarietyLink.new(self)


func _view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return get_viewport_rect().size


func _relayout() -> void:
	if not _built or _content == null:
		return
	var w: float = size.x
	var h: float = size.y
	if w < 2.0 or h < 2.0:
		return
	var top_h: float = top_band_px()
	var bot_h: float = bottom_band_px()
	var base_y: float = h - bot_h
	top_bar.place(w, top_h, _margins)
	bottom.position = Vector2(0.0, base_y)
	bottom.place(w, bot_h, _margins)
	var left: float = HudStyle.EDGE + _margins.x
	var inner_w: float = w - 2.0 * HudStyle.EDGE - _margins.x - _margins.z
	var stack_top: float = base_y
	if intermission.visible:
		intermission.size = Vector2(inner_w, HudIntermissionPanel.HEIGHT)
		intermission.position = Vector2(left, stack_top - HudIntermissionPanel.HEIGHT - HudStyle.GAP)
		stack_top = intermission.position.y
	banners.place(Rect2(0.0, top_h, w, maxf(base_y - top_h, 0.0)), _margins, base_y - stack_top)


## Mobile only, and only in the real window (a capture SubViewport has no OS safe area).
func _apply_os_safe_area() -> void:
	if not is_inside_tree() or not OS.has_feature("mobile") or get_viewport() != get_tree().root:
		return
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	set_safe_margins(SafeArea.margins(win, safe, get_viewport_rect().size))


# --- refresh helpers ---


func _apply_core(hp: float, max_hp: float) -> void:
	top_bar.set_core(hp, max_hp, _api.shield_hp())
	var frac: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	banners.set_low_core(hp > 0.0 and frac < LOW_CORE, HudStyle.pct(hp, max_hp))


func _refresh_ammo() -> void:
	var left: int = _api.reload_ticks_left()
	if left <= 0:
		_reload_total = 0
	var total: int = _reload_total
	if left > 0 and total <= 0 and _content != null:
		var def: WeaponDef = _content.weapon(_api.weapon_id())
		total = def.reload_ticks if def != null else left
	bottom.ammo.show_ammo(_api.weapon_id(), _api.magazine(), _api.magazine_size(), left, total)


func _refresh_phase() -> void:
	var phase: int = _api.phase()
	var changed: bool = false
	var inter: bool = phase == GameState.Id.INTERMISSION
	if variety.active and _api.awaiting() != RunApi.AWAIT_NONE:
		inter = false  # a choice screen covers the intermission; the panel is the breather's countdown only
	if inter != intermission.visible:
		intermission.visible = inter
		changed = true
	if inter:
		var cleared: int = _inter_wave if _inter_wave > 0 else _api.wave()
		intermission.show_countdown(cleared, _api.phase_ticks_left())
	if phase == GameState.Id.PREPARING:
		_deploy_shown = true
		var secs: int = HudStyle.secs(_api.phase_ticks_left())
		banners.show_text(Strings.tf("hud.deploying", [secs]), Strings.t("hud.deploying.whisper"), 0.0)
	elif _deploy_shown:
		_deploy_shown = false
		banners.hide_banner()
	if changed:
		_relayout()


# --- events ---


func _bind_events() -> void:
	_bind(Events.scrap_changed, _on_scrap_changed)
	_bind(Events.core_changed, _on_core_changed)
	_bind(Events.shield_changed, func(_cur: float, _mx: float) -> void: _apply_core(_api.core_hp(), _api.core_max_hp()))
	_bind(Events.wave_started, _on_wave_started)
	_bind(Events.intermission_started, _on_intermission_started)
	_bind(Events.boss_spawned, _on_boss_spawned)
	_bind(Events.ability_activated, bottom.abilities.on_activated)
	_bind(Events.ability_rejected, bottom.abilities.on_rejected)
	_bind(Events.reload_started, _on_reload_started)
	_bind(Events.reload_finished, _refresh_ammo)
	_bind(Events.weapon_changed, func(_id: StringName) -> void: _refresh_ammo())
	_bind(Events.hint_requested, _on_hint_requested)
	_bind(Events.state_changed, func(_prev: int, _cur: int) -> void: refresh())
	_bind(Events.run_started, _on_run_started)
	variety.bind_events(_bind)


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


func _on_scrap_changed(value: int) -> void:
	top_bar.set_scrap(value)


func _on_core_changed(current: float, max_value: float) -> void:
	_apply_core(current, max_value)


func _on_wave_started(index: int) -> void:
	_deploy_shown = false
	_inter_wave = 0
	if not variety.show_wave(index):
		banners.show_wave(index)
	refresh()


func _on_intermission_started(wave_cleared: int, _ticks: int) -> void:
	_inter_wave = wave_cleared
	refresh()


func _on_boss_spawned(_id: int, kind: StringName) -> void:
	_boss_kind = kind
	if not variety.on_boss_spawned(kind):
		banners.show_boss_banner(kind)
	banners.set_boss(kind, _api.boss_hp(), _api.boss_max_hp())


func _on_reload_started(ticks: int) -> void:
	_reload_total = ticks
	_refresh_ammo()


func _on_hint_requested(key: String) -> void:
	banners.show_hint(Strings.t(key))


func _on_run_started(_run_id: String, _run_seed: int) -> void:
	_inter_wave = 0
	_boss_kind = &"siege_hulk"
	banners.hide_banner()
	banners.hide_hint()
	refresh()


func _on_continue() -> void:
	Sfx.play(&"ui_tap")
	_api.skip_intermission()


func _on_pause() -> void:
	Sfx.play(&"ui_tap")
	pause_requested.emit()
