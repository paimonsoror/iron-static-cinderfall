class_name HudVarietyLink
extends RefCounted
## The variety half of the CombatHud (VARIETY_SPEC 11.4, GDD 10.1), kept out of combat_hud.gd (400-line cap). `active` is
## true when the content is the variety content (a generated run): the weapon bar and the call buttons replace the UPGRADES
## tab and the magazine readout, the threat ticker sits under the top bar, the bottom band is 26% of the height, the top bar
## shows ACT and W n/15, the boss bar shows its name and phase pips, and the act start gets a banner. With the legacy content
## (the 5-wave fixture) `active` is false and the HUD is exactly the old one. The drawer stays built but hidden.

const BOTTOM_FRACTION: float = 0.26

var active: bool = false
var _hud: CombatHud
var _api: RunApi
var _content: ContentSet
var _boss_kind: StringName = &"siege_hulk"


func _init(hud: CombatHud) -> void:
	_hud = hud


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	active = content != null and content.is_variety()
	_hud.bottom.set_variety(active, api, content)
	_hud.top_bar.set_variety(active)
	_hud.banners.ticker.visible = active


## The bottom band: 26% of the height (and never thinner than the two rows), the safe-area margin on top of it.
func bottom_band(base: float, view_h: float, margin_bottom: float) -> float:
	if not active:
		return base
	return maxf(maxf(base, view_h * BOTTOM_FRACTION + margin_bottom), HudBottomPanel.variety_min_px() + margin_bottom)


## Everything the variety HUD shows from the RunApi (10 Hz and on its signals).
func refresh() -> void:
	if not active or _api == null:
		return
	_hud.top_bar.set_act_wave(_api.act(), _api.wave(), _api.wave_count())
	_hud.bottom.weapon_bar.refresh()
	_hud.banners.ticker.refresh(_api.active_events(), _content, _api.crate_status())
	_hud.banners.boss_bar.pips.set_phase(_api.boss_phase(), _api.boss_phase_count())
	var def: BossDef = _content.boss(_boss_kind)
	_hud.banners.boss_bar.title_text = Strings.t(def.name_key) if def != null else ""


## Counts the ticker's notices down.
func process(delta: float) -> void:
	if active and _hud.banners.ticker.tick(delta):
		_hud.banners.ticker.refresh(_api.active_events(), _content, _api.crate_status())


## Connects the variety signals through `bind` (CombatHud._bind: signal, handler).
func bind_events(bind: Callable) -> void:
	if not active:
		return
	bind.call(Events.weapon_swapped, refresh.unbind(2))
	bind.call(Events.weapon_vented, refresh.unbind(1))
	bind.call(Events.charges_changed, refresh.unbind(2))
	bind.call(Events.event_warned, refresh.unbind(4))
	bind.call(Events.event_started, refresh.unbind(1))
	bind.call(Events.event_ended, refresh.unbind(1))
	bind.call(Events.boss_phase, refresh.unbind(1))
	bind.call(Events.await_changed, refresh.unbind(1))
	bind.call(Events.crate_dropped, refresh.unbind(2))
	bind.call(Events.crate_secured, refresh)
	bind.call(Events.crate_lost, refresh)
	bind.call(Events.act_started, on_act_started)
	bind.call(Events.elite_spawned, on_elite)


## The wave banner of a generated run: WAVE n over what the chosen route sends ("POWDER TRAIN // VOLATILE SWARM"), from
## RunApi.wave_route. The whisper lines of the legacy banner describe the five scripted waves ("armored frames on the
## gantry line") and would be wrong here. False on the legacy content (the HUD then shows its old banner).
func show_wave(index: int) -> bool:
	if not active:
		return false
	var route: Dictionary = _api.wave_route()
	var words: PackedStringArray = PackedStringArray()
	for key_name: String in ["name_key", "modifier_key"]:
		var key: String = route.get(key_name, "")
		if key != "" and RunUi.has_key(key):
			words.append(Strings.t(key))
	_hud.banners.show_text(Strings.tf("hud.banner.wave", [index]), " // ".join(words), 3.2)
	return true


## ACT II: THE GANTRY LINE over the plating tier ("CHORUS PLATING: TIER 2").
func on_act_started(act: int) -> void:
	_hud.banners.show_text(
		Strings.tf("hud.act_banner.title", [RunUi.roman(act), RunUi.act_name(_content, act)]), Strings.tf("act.tier", [act]), 4.0)


## "ELITE: PLATED SWIFT RUSHER" on the ticker.
func on_elite(_id: int, kind: StringName, affixes: int) -> void:
	var words: PackedStringArray = PackedStringArray()
	for def: AffixDef in _content.affixes:
		if ((affixes >> def.index) & 1) == 1:
			words.append(Strings.t(def.name_key))
	words.append(Strings.t("enemy.%s.name" % String(kind)).to_upper())
	_hud.banners.ticker.push_notice(Strings.tf("hud.ticker.elite", [" ".join(words)]))
	_hud.banners.ticker.refresh(_api.active_events(), _content, _api.crate_status())


## The boss banner of the variety run (NODE n // NAME over its CHORUS log line). False when the boss has no BossDef.
func on_boss_spawned(kind: StringName) -> bool:
	_boss_kind = kind
	var def: BossDef = _content.boss(kind) if _content != null else null
	if not active or def == null:
		return false
	_hud.banners.show_text(Strings.t(def.name_key), Strings.t(def.banner_key), 4.0)
	refresh()
	return true
