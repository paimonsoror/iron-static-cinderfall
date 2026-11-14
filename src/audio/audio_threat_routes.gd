class_name AudioThreatRoutes
extends RefCounted
## What the other side does, as sound: the chaos events, the boss telegraphs and phases, the elites and the wards, a borer
## coming up through the floor (VARIETY_SPEC 12.1, groups Enemies, Bosses and Events). It belongs to an AudioVarietyRoutes,
## which merges `wiring()` into the router's table and forwards `bind`, `advance` and `reset`; the router forwards the
## spawn and kill of enemies. Read-only: it never touches the sim. Every handler is public so tests can call it.
##
## The alert sounds (`warn_harm`, `warn_help`, `strike_call`, `freight_horn`, `recount_tick`, the boss telegraphs) are the
## alert class of AudioCatalog: three voices of their own, so a chain of blasts cannot swallow them.
##  - event_warned: the sound of the event, or the harm warning of a harmful one, or the help warning of a helpful one;
##  - event_started / event_ended: the moment the event takes hold (a surge, a breach, a window, the freight car) or lets go;
##  - boss_telegraph: the sound of the living boss (a boss that is not listed warns with `warn_harm`), and for a boss whose
##    blow lands later (the Tremor Rig) the blow itself `ticks` later; the Lance Platform's beam plays when it hits the
##    core (the router), so an EMP that cancels the charge also cancels the shot;
##  - boss_phase: a hit of its own; the last pylon of the Aegis Array falling opens the array (`aegis_exposed`);
##  - elite_spawned, ward_changed (a ward that comes back hums, a ward going down breaks, a ward at its spawn is silent), a borer spawning.

const TICKS_PER_SECOND: float = 60.0  ## the fixed sim rate (ARCH 6.1)

const WARN_HARM: StringName = &"warn_harm"
const WARN_HELP: StringName = &"warn_help"
const STRIKE_EVENT: StringName = &"deadfall_strike"
const PYLON_KIND: StringName = &"ward_pylon"
const AEGIS_KIND: StringName = &"aegis_array"
const BORER_KIND: StringName = &"borer"

## event_warned: the sound of a named event. The other harmful events fall back to WARN_HARM, the helpful ones to WARN_HELP;
## `core_vent` is silent (its blast comes half a second later and has the sound), and so is an event nobody knows.
const WARN_SOUNDS: Dictionary = {
	STRIKE_EVENT: &"strike_call", &"runaway_freight": &"freight_horn", &"freight_call": &"freight_horn", &"recount": &"recount_tick",
}
const HARMFUL_EVENTS: Array[StringName] = [&"static_front", &"floor_breach", &"recount", &"runaway_freight"]
const HELPFUL_EVENTS: Array[StringName] = [&"accord_window", &"supply_drop", &"power_surge"]
## event_started and event_ended.
const START_SOUNDS: Dictionary = {
	&"static_front": &"static_front", &"power_surge": &"surge_up", &"floor_breach": &"breach_crack",
	&"accord_window": &"relay_window", &"runaway_freight": &"freight_pass",
}
const END_SOUNDS: Dictionary = {&"power_surge": &"brownout"}

## boss_telegraph, by the kind of the living boss.
const BOSS_TELEGRAPH_SOUNDS: Dictionary = {
	&"brood_carrier": &"brood_hatch", &"lance_platform": &"lance_charge", &"siege_hulk": &"hulk_charge",
	&"tremor_rig": WARN_HARM, &"aegis_array": WARN_HARM,
}
## The blow that lands `ticks` after the telegraph (the others are heard when they hit: a core hit, a spawn).
const BOSS_BLOW_SOUNDS: Dictionary = {&"tremor_rig": &"tremor_stomp"}

var boss_kind: StringName = &""  ## the kind of the boss that is alive, &"" = none

var _dir: AudioDirector = null
var _pylons: int = 0  ## ward pylons alive (the Aegis Array is open when the last one falls)
var _ward_up: Dictionary[int, bool] = {}  ## enemy id -> its ward stands
var _later: Array[StringName] = []  ## sounds that wait for their moment
var _later_left: PackedFloat32Array = PackedFloat32Array()  ## seconds until each one


## Signal name to handler, for AudioVarietyRoutes to merge into the router's table.
func wiring() -> Dictionary[StringName, Callable]:
	return {
		&"event_warned": on_event_warned,
		&"event_started": on_event_started,
		&"event_ended": on_event_ended,
		&"boss_telegraph": on_boss_telegraph,
		&"boss_phase": on_boss_phase,
		&"elite_spawned": on_elite_spawned,
		&"ward_changed": on_ward_changed,
	}


func bind(director: AudioDirector) -> void:
	_dir = director


## One frame: the sounds that were waiting for their moment start when it comes.
func advance(dt: float) -> void:
	var i: int = 0
	while i < _later.size():
		_later_left[i] -= dt
		if _later_left[i] <= 0.0:
			_play(_later[i])
			_later.remove_at(i)
			_later_left.remove_at(i)
		else:
			i += 1


## New run or a menu: forget the boss, the pylons, the wards and everything that was waiting.
func reset() -> void:
	boss_kind = &""
	_pylons = 0
	_ward_up.clear()
	_later.clear()
	_later_left = PackedFloat32Array()


func pending() -> int:
	return _later.size()


# --- enemies (the router forwards these) ---------------------------------------------------------------------------

func on_enemy_spawned(_id: int, kind: StringName) -> void:
	if kind == PYLON_KIND:
		_pylons += 1
	elif kind == BORER_KIND:
		_play(&"borer_emerge")


func on_boss_spawned(kind: StringName) -> void:
	boss_kind = kind


## The boss that dies takes its pylons with it: they open nothing. The last pylon of a living Aegis Array opens it.
func on_enemy_killed(id: int, kind: StringName) -> void:
	@warning_ignore("return_value_discarded")
	_ward_up.erase(id)
	if kind == boss_kind and kind != &"":
		boss_kind = &""
		_pylons = 0
	elif kind == PYLON_KIND and _pylons > 0:
		_pylons -= 1
		if _pylons == 0 and boss_kind == AEGIS_KIND:
			_play(&"aegis_exposed")


# --- events --------------------------------------------------------------------------------------------------------

func on_event_warned(id: StringName, _ticks: int, _x: float, _z: float) -> void:
	var sound: StringName = WARN_SOUNDS.get(id, &"")
	if sound == &"":
		if HARMFUL_EVENTS.has(id):
			sound = WARN_HARM
		elif HELPFUL_EVENTS.has(id):
			sound = WARN_HELP
	if sound != &"":
		_play(sound)


func on_event_started(id: StringName) -> void:
	var sound: StringName = START_SOUNDS.get(id, &"")
	if sound != &"":
		_play(sound)


func on_event_ended(id: StringName) -> void:
	var sound: StringName = END_SOUNDS.get(id, &"")
	if sound != &"":
		_play(sound)


# --- bosses --------------------------------------------------------------------------------------------------------

func on_boss_telegraph(_attack: int, ticks: int) -> void:
	var sound: StringName = BOSS_TELEGRAPH_SOUNDS.get(boss_kind, WARN_HARM)
	_play(sound)
	var blow: StringName = BOSS_BLOW_SOUNDS.get(boss_kind, &"")
	if blow != &"":
		_later.append(blow)
		@warning_ignore("return_value_discarded")
		_later_left.append(float(maxi(ticks, 0)) / TICKS_PER_SECOND)


## A boss enters a later phase (phase 0 is the start of the fight: the stinger plays then).
func on_boss_phase(phase: int) -> void:
	if phase > 0:
		_play(&"boss_phase")


# --- elites and wards ----------------------------------------------------------------------------------------------

func on_elite_spawned(_id: int, _kind: StringName, _affixes: int) -> void:
	_play(&"elite_spawn")


## A ward that comes back hums, a ward that goes down breaks; a hit that only drains it is silent. The first report of an enemy's ward is
## silent too: a shieldbearer pushes WARD_CHANGED with its full pool on its first tick, so a hum there would sound at every spawn.
func on_ward_changed(id: int, fraction: float) -> void:
	if not _ward_up.has(id):
		_ward_up[id] = fraction > 0.0
		return
	var up: bool = _ward_up[id]
	if fraction > 0.0 and not up:
		_ward_up[id] = true
		_play(&"ward_hum")
	elif fraction <= 0.0 and up:
		_ward_up[id] = false
		_play(&"ward_break")


func _play(id: StringName) -> void:
	if _dir != null:
		_dir.play(id)
