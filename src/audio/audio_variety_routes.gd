class_name AudioVarietyRoutes
extends RefCounted
## The signals the variety milestone added to `Events` (VARIETY_SPEC 13.4) turned into sounds. It belongs to an
## AudioEventRouter, which merges `wiring()` into its own table and drives `advance`, `reset` and `bind`. Read-only: it
## never touches the sim. Every handler is public so tests can call it.
##
## Slice routes (task V2-G); task V4-A adds rows to the tables, not new logic:
##  - area_blast: a strike impact, a drum and a core vent each have their sound; every other blast is collected for the
##    frame and becomes `blast_small` (up to 3) or one `blast_big` (4 or more), see AudioBlastMerge;
##  - chain_arc: the crackle of each jump; delayed_hit: a strike in the air warns (`warn_harm`);
##  - event_warned: the Deadfall Strike call, or the harm warning of a harmful event (helpful events wait for `warn_help`);
##  - draft_offered / directive_picked / route_offered / route_picked / crate_secured: the interface sounds.
## `weapon_swapped` and the shots are the router's (they share its weapon state).

# Mirrors of enums the audio layer may not read (HazardState.K_* in the sim, RunApi.AWAIT_*); a test pins each one.
const KIND_STRIKE: int = 1
const KIND_DRUM: int = 5
const KIND_VENT: int = 7
const AWAIT_NONE: int = 0

const WARN_HARM: StringName = &"warn_harm"
const STRIKE_EVENT: StringName = &"deadfall_strike"
const REROLL_SOUND: StringName = &"ui_drawer"  ## until V4-A adds `draft_reroll`

## The sound of an area_blast kind that does not join the merge of small blasts.
const AREA_BLAST_SOUNDS: Dictionary = {KIND_STRIKE: &"strike_impact", KIND_DRUM: &"blast_big", KIND_VENT: &"blast_big"}
## delayed_hit kinds that warn while the round is in the air.
const DELAYED_HIT_SOUNDS: Dictionary = {KIND_STRIKE: WARN_HARM}
## event_warned: the sound of a named event; the harmful ones fall back to WARN_HARM, the helpful ones are silent for now.
const EVENT_SOUNDS: Dictionary = {STRIKE_EVENT: &"strike_call"}
const HARMFUL_EVENTS: Array[StringName] = [&"static_front", &"floor_breach", &"recount", &"runaway_freight"]

## The drone follows the act and the place of the wave in it (5 waves an act, 15 in a run): from, to.
const WAVES_PER_ACT: int = 5
const ACT_INTENSITY: Array[Vector2] = [Vector2(0.20, 0.40), Vector2(0.45, 0.65), Vector2(0.70, 0.90)]

var act: int = 0  ## 1..3 once `act_started` arrived in this run; 0 = a run without acts (the legacy five waves)
var draft_open: bool = false  ## a draft is on screen: the next offer is a reroll

var _dir: AudioDirector = null
var _merge: AudioBlastMerge = AudioBlastMerge.new()


## Signal name to handler, for the router to connect.
func wiring() -> Dictionary[StringName, Callable]:
	return {
		&"act_started": on_act_started,
		&"await_changed": on_await_changed,
		&"draft_offered": on_draft_offered,
		&"directive_picked": on_directive_picked,
		&"route_offered": on_route_offered,
		&"route_picked": on_route_picked,
		&"crate_secured": on_crate_secured,
		&"area_blast": on_area_blast,
		&"chain_arc": on_chain_arc,
		&"delayed_hit": on_delayed_hit,
		&"event_warned": on_event_warned,
	}


func bind(director: AudioDirector) -> void:
	_dir = director


## One frame: the small blasts collected since the last frame start now.
func advance(_dt: float) -> void:
	for sound: StringName in _merge.take():
		_play(sound)


## New run or a menu: forget the act, the open draft and the blasts waiting for the frame.
func reset() -> void:
	act = 0
	draft_open = false
	_merge.clear()


## The drone level of wave `index` (1-based, over the whole run) inside act 1..3.
static func intensity_for_act(act_number: int, index: int) -> float:
	var span: Vector2 = ACT_INTENSITY[clampi(act_number, 1, ACT_INTENSITY.size()) - 1]
	var in_act: int = clampi(index - WAVES_PER_ACT * (act_number - 1), 1, WAVES_PER_ACT)
	return lerpf(span.x, span.y, float(in_act - 1) / float(WAVES_PER_ACT - 1))


func on_act_started(act_number: int) -> void:
	act = act_number


# --- the interface -------------------------------------------------------------------------------------------------

## The first offer opens the draft; an offer while it is open is a reroll.
func on_draft_offered(_ids: Array[StringName]) -> void:
	_play(REROLL_SOUND if draft_open else &"draft_open")
	draft_open = true


func on_directive_picked(_id: StringName, _stacks: int) -> void:
	draft_open = false
	_play(&"draft_pick")


## A draft that closes without a pick (SKIP) ends with the wait for an answer.
func on_await_changed(kind: int) -> void:
	if kind == AWAIT_NONE:
		draft_open = false


func on_route_offered() -> void:
	_play(&"draft_open")


func on_route_picked(_option: int) -> void:
	_play(&"route_pick")


func on_crate_secured() -> void:
	_play(&"crate_secured")


# --- blasts, arcs, strikes -----------------------------------------------------------------------------------------

func on_area_blast(kind: int, _x: float, _z: float, _radius: float) -> void:
	var sound: StringName = AREA_BLAST_SOUNDS.get(kind, &"")
	if sound == &"":
		_merge.add()
	else:
		_play(sound)


func on_chain_arc(_from_id: int, _to_id: int) -> void:
	_play(&"arc_chain")


func on_delayed_hit(kind: int, _x: float, _z: float, _ticks: int) -> void:
	var sound: StringName = DELAYED_HIT_SOUNDS.get(kind, &"")
	if sound != &"":
		_play(sound)


func on_event_warned(id: StringName, _ticks: int, _x: float, _z: float) -> void:
	var sound: StringName = EVENT_SOUNDS.get(id, &"")
	if sound == &"" and HARMFUL_EVENTS.has(id):
		sound = WARN_HARM
	if sound != &"":
		_play(sound)


## A burster reaches its slot and arms for 1.2 s. NOT connected: no `Events` signal says so (ENEMY_REACHED_SLOT is one of
## the sim events GameEventRelay drops), so the owner of the bus decides; the sound exists and this is its door.
func on_burster_armed(_enemy_id: int) -> void:
	_play(&"burster_arm")


func _play(id: StringName) -> void:
	if _dir != null:
		_dir.play(id)
