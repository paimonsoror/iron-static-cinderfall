class_name HudSandbox
extends Control
## CombatHud + FakeRunApi cycling through the states a review needs (ARCH 11), every STEP_SECONDS:
##   0 combat with Scrap, full core, abilities ready
##   1 upgrade drawer open with mixed cards (affordable, too expensive, maxed, locked)
##   2 shield active, EMP cooling down, overdrive ready
##   3 wave 5 boss bar, core nearly gone (low-core warning), shield broken
##   4 reload in progress (empty magazine)
##   5 intermission countdown
## `--hud-step=<n>` pins the sandbox to state n (all earlier changes applied) so a capture shows exactly that state;
## `--high-contrast` builds the high contrast theme. While cycling, cooldowns, active timers and the reload count down
## live (60 per second); a pinned state stays exactly as applied.
## `--state=draft|route|boss_brief|salvage|combat2` (VARIETY_SPEC 13.8) pins the sandbox to a FakeRunPresets state: the
## variety queries of the FakeRunApi are filled, the matching signals are emitted and, for the four intermission
## states, the overlay scene of src/ui/run/ is shown above the HUD.

const STEP_SECONDS: float = 2.5
const STEP_COUNT: int = 6
const OVERLAY_SCENES: Dictionary[String, String] = {
	"draft": "res://src/ui/run/draft_overlay.tscn",
	"route": "res://src/ui/run/route_overlay.tscn",
	"boss_brief": "res://src/ui/run/boss_brief_overlay.tscn",
	"salvage": "res://src/ui/run/salvage_overlay.tscn",
}

var _api: FakeRunApi = FakeRunApi.new()
var _hud: CombatHud
var _t: float = 0.0
var _step: int = 0
var _pinned: bool = false
var _tick_acc: float = 0.0
var _overlay: Control  ## the intermission overlay of the current --state, or null


func _ready() -> void:
	var args: DebugArgs = DebugArgs.from_os()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.build(Content.db.tokens, args.high_contrast)
	var packed: PackedScene = load("res://src/ui/combat/combat_hud.tscn") as PackedScene
	_hud = packed.instantiate() as CombatHud
	add_child(_hud)
	_hud.setup(_api, Content.db, null)
	if args.hud_state != "":
		apply_step(0)
		var _shown: bool = show_state(args.hud_state)
	elif args.hud_step >= 0:
		_pinned = true
		_step = mini(args.hud_step, STEP_COUNT - 1)
		for n: int in _step + 1:
			apply_step(n)
	else:
		apply_step(0)


func _process(delta: float) -> void:
	if _pinned:
		return  # a pinned state stays exactly as applied (timers would run out during a capture)
	_count_down(delta)
	_t += delta
	if _t >= STEP_SECONDS:
		_t = 0.0
		_step = (_step + 1) % STEP_COUNT
		if _step == 0:
			_reset()
		apply_step(_step)


func current_step() -> int:
	return _step


func hud() -> CombatHud:
	return _hud


func api() -> FakeRunApi:
	return _api


## The intermission overlay shown by `show_state`, or null.
func overlay() -> Control:
	return _overlay


## Pins the sandbox to the variety state `state` (FakeRunPresets.STATES). False for an unknown name.
func show_state(state: String) -> bool:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	if not FakeRunPresets.apply(_api, Content.db, state):
		return false
	_pinned = true
	_hud.refresh()
	if OVERLAY_SCENES.has(state):
		var packed: PackedScene = load(OVERLAY_SCENES[state]) as PackedScene
		_overlay = packed.instantiate() as Control
		add_child(_overlay)
		_overlay.call("setup", _api, Content.db)
	return true


## Puts the HUD into state `n`. Cumulative: call 0 .. n in order (the sandbox does; `--hud-step` replays them).
func apply_step(n: int) -> void:
	match n:
		0:
			_api.set_scrap(120)
			_api.set_core(1000.0)
			_api.fake_alive = 14
			Events.wave_started.emit(1)
		1:
			_api.set_scrap(380)
			_api.fake_upgrade_level[&"damage"] = 2
			_api.fake_upgrade_cost[&"damage"] = 260
			_api.fake_upgrade_level[&"fire_rate"] = 5
			_api.fake_upgrade_cost[&"fire_rate"] = -1
			_api.fake_purchase_block[&"fire_rate"] = Reason.Id.MAX_LEVEL
			_api.fake_purchase_block[&"armor_piercing"] = Reason.Id.INSUFFICIENT_SCRAP
			_api.fake_purchase_block[&"smg_unlock"] = Reason.Id.PREREQ_NOT_MET
			Events.upgrade_level_changed.emit(&"damage", 2)
			_hud.open_drawer()
		2:
			_hud.close_drawer()
			_api.set_core(820.0)
			_api.fake_shield_hp = 70.0
			_api.fake_ability_active_left[&"shield"] = 300
			_api.fake_ability_cooldown_left[&"shield"] = 3000
			_api.fake_ability_cooldown_left[&"emp"] = 1400
			Events.ability_activated.emit(&"shield")
		3:
			_api.fake_shield_hp = 0.0
			_api.fake_ability_active_left[&"shield"] = 0
			_api.fake_boss_hp = 1500.0
			_api.fake_wave = 5
			_api.fake_alive = 46
			_api.set_core(100.0)
			Events.wave_started.emit(5)
			Events.boss_spawned.emit(1, &"siege_hulk")
		4:
			_api.fake_magazine = 0
			_api.fake_reload_ticks_left = 70
			Events.reload_started.emit(70)
		5:
			_api.fake_boss_hp = -1.0
			_api.fake_alive = 0
			_api.fake_phase = GameState.Id.INTERMISSION
			_api.fake_phase_ticks_left = 480
			Events.intermission_started.emit(4, 480)
	_hud.refresh()


## The next lap starts from a clean state: nothing bought, no boss, no timers.
func _reset() -> void:
	var fresh: FakeRunApi = FakeRunApi.new()
	for u: StringName in Ids.UPGRADES:
		_api.fake_upgrade_level[u] = fresh.fake_upgrade_level[u]
		_api.fake_upgrade_cost[u] = fresh.fake_upgrade_cost[u]
		_api.fake_purchase_block[u] = fresh.fake_purchase_block[u]
	for a: StringName in Ids.ABILITIES:
		_api.fake_ability_active_left[a] = 0
		_api.fake_ability_cooldown_left[a] = 0
	_api.fake_shield_hp = 0.0
	_api.fake_boss_hp = -1.0
	_api.fake_wave = 1
	_api.fake_magazine = _api.fake_magazine_size
	_api.fake_reload_ticks_left = 0
	_api.fake_phase = GameState.Id.SPAWNING
	_api.fake_phase_ticks_left = 0
	_hud.close_drawer()
	Events.reload_finished.emit()


## Cooldowns, active ability timers and the reload run at 60 ticks per second, like the sim.
func _count_down(delta: float) -> void:
	_tick_acc += delta * 60.0
	var ticks: int = floori(_tick_acc)
	if ticks <= 0:
		return
	_tick_acc -= float(ticks)
	for a: StringName in Ids.ABILITIES:
		var cd: int = _api.fake_ability_cooldown_left[a]
		_api.fake_ability_cooldown_left[a] = maxi(0, cd - ticks)
		var active: int = _api.fake_ability_active_left[a]
		_api.fake_ability_active_left[a] = maxi(0, active - ticks)
	if _api.fake_reload_ticks_left > 0:
		_api.fake_reload_ticks_left = maxi(0, _api.fake_reload_ticks_left - ticks)
		if _api.fake_reload_ticks_left == 0:
			_api.fake_magazine = _api.fake_magazine_size
			Events.reload_finished.emit()
	if _api.fake_phase == GameState.Id.INTERMISSION and _api.fake_phase_ticks_left > 0:
		_api.fake_phase_ticks_left = maxi(0, _api.fake_phase_ticks_left - ticks)
