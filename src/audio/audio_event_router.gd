class_name AudioEventRouter
extends RefCounted
## Turns `Events` signals (ARCH 7.1) into sound requests on an AudioDirector. Read-only: it never touches the sim.
## `bind(Events, director)` connects; `unbind()` disconnects. The handlers are public so tests can call them.
##
## Enemy kind per id comes from `enemy_spawned` / `boss_spawned` (the kill and damage signals carry only the id).
## `enemy_died_at` is not used: `enemy_killed` already marks each death, and both fire for one death.
## `ability_rejected` is not used: the HUD plays `ui_deny` itself for a rejected tap.
## The signals of the variety milestone are AudioVarietyRoutes' (`variety`); the router keeps the weapon state, so it
## also takes `weapon_swapped` and the shots (a sound per weapon, or a held loop for the weapons that have one).

const TICKS_PER_SECOND: float = 60.0  ## the fixed sim rate (ARCH 6.1), used to turn intermission ticks into seconds
const LOW_CORE_RATIO: float = 0.25  ## GDD 10.1: below 25 % the core is in danger (warning line and heartbeat)
const HEARTBEAT_SECONDS: float = 1.1
const FULL_INTENSITY_WAVE: int = 5  ## the drone reaches full level at the last wave
const INTERMISSION_INTENSITY: float = 0.1
const TICK_SECONDS: Array[int] = [3, 2, 1]  ## intermission_tick plays at these remaining seconds (GDD 11)

## Enemy kinds whose armor is above 0 (GDD 6, CONTENT 4): they get the duller hit sound.
const ARMORED_KINDS: Array[StringName] = [
	&"hollow_warden", &"rusher", &"siege_hulk", &"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"borer",
	&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig",
]
const HEAVY_CORE_KINDS: Array[StringName] = [
	&"hollow_warden", &"rusher", &"siege_hulk", &"burster", &"splitter", &"shieldbearer", &"jammer", &"borer",
	&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig",
]
const LIGHT_CORE_KINDS: Array[StringName] = [&"skitter", &"spitter", &"reclaimer"]
## Minis are consumed by their one hit on the cage: that hit is the burn-out, not a core strike.
const MINI_KINDS: Array[StringName] = [&"mote", &"shard"]
const UNKNOWN_KIND_HEAVY_DAMAGE: float = 20.0
## One entry per enemy of Ids.ENEMIES. The 14 variety kinds use the existing death sounds until V4-A adds their own.
const DEATH_SOUNDS: Dictionary = {
	&"skitter": &"death_small",
	&"rusher": &"death_small",
	&"hollow_warden": &"death_heavy",
	&"siege_hulk": &"death_boss",
	&"mote": &"death_small",
	&"shard": &"death_small",
	&"burster": &"death_small",
	&"spitter": &"death_small",
	&"splitter": &"death_heavy",
	&"shieldbearer": &"death_heavy",
	&"reclaimer": &"death_heavy",
	&"jammer": &"death_small",
	&"borer": &"death_small",
	&"ward_pylon": &"death_heavy",
	&"brood_carrier": &"death_boss",
	&"lance_platform": &"death_boss",
	&"aegis_array": &"death_boss",
	&"tremor_rig": &"death_boss",
}
## The shot sound of a weapon of the Warden; a weapon not listed (yet) uses the pistol's.
const SHOT_SOUNDS: Dictionary = {&"pistol": &"shot_pistol", &"smg": &"shot_smg", &"arc_projector": &"shot_arc"}
## Weapons whose sound is a held loop (`Sfx.hold`) while they fire, by weapon id: V4-A adds lmg and cutting_torch.
const HELD_BY_WEAPON: Dictionary = {}
const HELD_TAIL_SECONDS: float = 0.18  ## a held weapon loop is released this long after its last shot
const ABILITY_START_SOUNDS: Dictionary = {&"emp": &"emp", &"shield": &"shield_up", &"overdrive": &"overdrive_on"}
const ABILITY_END_SOUNDS: Dictionary = {&"shield": &"shield_break", &"overdrive": &"overdrive_off"}
const BOSS_KIND: StringName = &"siege_hulk"
const SMG_ID: StringName = &"smg"

var weapon_id: StringName = &"pistol"
var core_low: bool = false  ## true while the core is below LOW_CORE_RATIO
var intermission_left: float = -1.0  ## seconds, -1 when no intermission is running
var active_slot: int = 0  ## the Warden's active weapon slot (0 or 1), from `weapon_swapped`
var offhand_id: StringName = &""  ## the weapon the last swap put away
var held_sounds: Dictionary = {}  ## weapon id -> held loop id (HELD_BY_WEAPON; tests change it)
var variety: AudioVarietyRoutes = AudioVarietyRoutes.new()

var _hold_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])  ## seconds until a slot's held loop is released
var _bus: Node = null
var _dir: AudioDirector = null
var _kinds: Dictionary[int, StringName] = {}
var _wiring: Dictionary[StringName, Callable] = {}
var _beat_left: float = 0.0


func _init() -> void:
	held_sounds.merge(HELD_BY_WEAPON)
	_wiring = {
		&"run_started": on_run_started,
		&"run_finished": on_run_finished,
		&"state_changed": on_state_changed,
		&"wave_started": on_wave_started,
		&"wave_cleared": on_wave_cleared,
		&"intermission_started": on_intermission_started,
		&"enemy_spawned": on_enemy_spawned,
		&"boss_spawned": on_boss_spawned,
		&"enemy_damaged": on_enemy_damaged,
		&"enemy_killed": on_enemy_killed,
		&"shot_fired": on_shot_fired,
		&"weapon_changed": on_weapon_changed,
		&"core_hit": on_core_hit,
		&"core_changed": on_core_changed,
		&"ability_activated": on_ability_activated,
		&"ability_ended": on_ability_ended,
		&"reload_started": on_reload_started,
		&"reload_finished": on_reload_finished,
		&"weapon_swapped": on_weapon_swapped,
	}
	var more: Dictionary[StringName, Callable] = variety.wiring()
	for sig: StringName in more:
		_wiring[sig] = more[sig]


## Signal names this router listens to.
func signal_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for sig: StringName in _wiring:
		names.append(sig)
	return names


## The handler connected for `sig` (an invalid Callable for a name the router does not use).
func handler_for(sig: StringName) -> Callable:
	var handler: Callable = _wiring.get(sig, Callable())
	return handler


## Connects every signal `source` has (a partial fake source is fine). Rebinding first unbinds.
func bind(source: Node, director: AudioDirector) -> void:
	unbind()
	_bus = source
	_dir = director
	variety.bind(director)
	for sig: StringName in _wiring:
		if source.has_signal(sig):
			@warning_ignore("return_value_discarded")
			source.connect(sig, _wiring[sig])


func unbind() -> void:
	if _bus != null and is_instance_valid(_bus):
		for sig: StringName in _wiring:
			if _bus.has_signal(sig) and _bus.is_connected(sig, _wiring[sig]):
				_bus.disconnect(sig, _wiring[sig])
	_bus = null


func is_bound() -> bool:
	return _bus != null


## Drives the two timed sounds (heartbeat, intermission ticks) with real seconds. The director calls it every
## frame and stops calling it while paused, so both freeze with the sim.
func advance(dt: float) -> void:
	variety.advance(dt)
	for slot: int in _hold_left.size():
		if _hold_left[slot] > 0.0:
			_hold_left[slot] -= dt
			if _hold_left[slot] <= 0.0 and _dir != null:
				_dir.release(slot)
	if core_low:
		_beat_left -= dt
		if _beat_left <= 0.0:
			_beat_left += HEARTBEAT_SECONDS
			_play(&"core_low")
	if intermission_left >= 0.0:
		var before: float = intermission_left
		intermission_left -= dt
		for s: int in TICK_SECONDS:
			if before > float(s) and intermission_left <= float(s):
				_play(&"intermission_tick")
		if intermission_left <= 0.0:
			intermission_left = -1.0


## The drone level for a wave: 0.2 at wave 1 up to 1.0 at the last wave.
static func intensity_for_wave(index: int) -> float:
	return clampf(float(index) / float(FULL_INTENSITY_WAVE), 0.0, 1.0)


# --- run flow --------------------------------------------------------------------------------------------------

func on_run_started(_run_id: String, _run_seed: int) -> void:
	reset()
	if _dir != null:
		_dir.set_intensity(0.0)
		_dir.start_ambience()


func on_run_finished(result: int, _run_id: String) -> void:
	_stop_timers()
	if _dir != null:
		_dir.stop_ambience()
		_dir.set_intensity(0.0)
	if result == RunResult.Id.VICTORY:
		_play(&"victory")
	elif result == RunResult.Id.DEFEAT:
		_play(&"defeat")


## Pausing mirrors the application state, so audio freezes with the game even if nobody calls pause_all. Leaving a
## run for a menu stops the beds.
func on_state_changed(previous: int, current: int) -> void:
	if _dir == null:
		return
	if current == GameState.Id.PAUSED:
		_dir.pause_all()
	elif previous == GameState.Id.PAUSED:
		_dir.resume_all()
	if current == GameState.Id.BOOT or current == GameState.Id.MENU or current == GameState.Id.BRIEFING:
		_stop_timers()
		_dir.stop_ambience()
		_dir.set_intensity(0.0)


func on_wave_started(index: int) -> void:
	intermission_left = -1.0
	_play(&"wave_start")
	if _dir != null:
		var level: float = intensity_for_wave(index)
		if variety.act > 0:
			level = AudioVarietyRoutes.intensity_for_act(variety.act, index)
		_dir.set_intensity(level)


func on_wave_cleared(_index: int) -> void:
	_play(&"wave_clear")


func on_intermission_started(_wave_cleared_count: int, ticks: int) -> void:
	intermission_left = float(ticks) / TICKS_PER_SECOND
	if _dir != null:
		_dir.set_intensity(INTERMISSION_INTENSITY)


func on_boss_spawned(id: int, kind: StringName) -> void:
	_kinds[id] = kind
	_play(&"boss_stinger")
	if _dir != null:
		_dir.set_intensity(1.0)


# --- enemies and weapons -----------------------------------------------------------------------------------------

func on_enemy_spawned(id: int, kind: StringName) -> void:
	_kinds[id] = kind


## Armored kinds (armor > 0) ring duller than the bare ceramic of a Skitter.
func on_enemy_damaged(id: int, amount: float, _source: int) -> void:
	if amount <= 0.0:
		return
	var kind: StringName = _kinds.get(id, &"")
	_play(&"hit_armor" if ARMORED_KINDS.has(kind) else &"hit_ceramic")


func on_enemy_killed(id: int, _source: int) -> void:
	var kind: StringName = _kinds.get(id, &"")
	@warning_ignore("return_value_discarded")
	_kinds.erase(id)
	var sound: StringName = DEATH_SOUNDS.get(kind, &"death_small")
	_play(sound)


func on_weapon_changed(id: StringName) -> void:
	if id != weapon_id:
		_release_held()
	weapon_id = id


## The Warden fires its active weapon, the off-hand gun the weapon put away, a turret its own sound; a strike, a hazard
## or the core fires no shot.
func on_shot_fired(source: int, _target_id: int) -> void:
	if source == DamageSource.Id.WARDEN:
		_fire(weapon_id, active_slot)
	elif source == DamageSource.Id.WARDEN_OFFHAND:
		_fire(offhand_id, 1 - active_slot)
	elif source != DamageSource.Id.CORE and source != DamageSource.Id.STRIKE and source != DamageSource.Id.HAZARD:
		_play(&"shot_turret")


## The slot now in the hands: the weapon put away becomes the off-hand gun, a held loop of the old one ends.
func on_weapon_swapped(slot: int, id: StringName) -> void:
	if id != weapon_id:
		offhand_id = weapon_id
	active_slot = clampi(slot, 0, 1)
	weapon_id = id
	_release_held()
	_play(&"weapon_swap")


func on_reload_started(_ticks: int) -> void:
	_release_held()
	_play(&"reload_start")


func on_reload_finished() -> void:
	_play(&"reload_done")


# --- core and abilities -----------------------------------------------------------------------------------------

## The Hulk's strike adds the stomp under the heavy hit.
func on_core_hit(_enemy_id: int, kind: StringName, hp_damage: float, absorbed: float) -> void:
	if MINI_KINDS.has(kind):
		_play(&"mote_burn")
		return
	if kind == BOSS_KIND:
		_play(&"boss_stomp")
	var heavy: bool = HEAVY_CORE_KINDS.has(kind)
	if not heavy and not LIGHT_CORE_KINDS.has(kind):
		heavy = hp_damage + absorbed >= UNKNOWN_KIND_HEAVY_DAMAGE  # a kind this table does not know: judge by size
	_play(&"core_hit_heavy" if heavy else &"core_hit_light")


## Crossing below LOW_CORE_RATIO starts the heartbeat (one beat now, then every HEARTBEAT_SECONDS); recovering or a
## dead core (the defeat sound takes over) stops it.
func on_core_changed(current: float, max_value: float) -> void:
	var low: bool = current > 0.0 and current < LOW_CORE_RATIO * max_value
	if low and not core_low:
		_beat_left = HEARTBEAT_SECONDS
		_play(&"core_low")
	core_low = low


func on_ability_activated(id: StringName) -> void:
	if ABILITY_START_SOUNDS.has(id):
		var sound: StringName = ABILITY_START_SOUNDS[id]
		_play(sound)


func on_ability_ended(id: StringName) -> void:
	if ABILITY_END_SOUNDS.has(id):
		var sound: StringName = ABILITY_END_SOUNDS[id]
		_play(sound)


## New run: forget enemies, weapon and timers.
func reset() -> void:
	_kinds.clear()
	weapon_id = &"pistol"
	active_slot = 0
	offhand_id = &""
	variety.reset()
	_stop_timers()


func _stop_timers() -> void:
	core_low = false
	_beat_left = 0.0
	intermission_left = -1.0
	_release_held()


## One shot of `weapon`: its sound, or (a weapon with a held loop) the loop on `slot`, kept alive by every shot.
func _fire(weapon: StringName, slot: int) -> void:
	var loop_id: StringName = held_sounds.get(weapon, &"")
	if loop_id != &"" and _dir != null:
		_dir.hold(loop_id, slot)
		_hold_left[slot] = HELD_TAIL_SECONDS
		return
	var shot: StringName = SHOT_SOUNDS.get(weapon, &"shot_pistol")
	_play(shot)


func _release_held() -> void:
	for slot: int in _hold_left.size():
		_hold_left[slot] = 0.0
		if _dir != null:
			_dir.release(slot)


func _play(id: StringName) -> void:
	if _dir != null:
		_dir.play(id)
