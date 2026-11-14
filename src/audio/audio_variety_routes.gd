class_name AudioVarietyRoutes
extends RefCounted
## The signals the variety milestone added to `Events` (VARIETY_SPEC 13.4) turned into sounds. It belongs to an
## AudioEventRouter, which merges `wiring()` into its own table and drives `advance`, `reset` and `bind`. Read-only: it
## never touches the sim. Every handler is public so tests can call it. What the other side does (events, bosses, elites,
## wards) is AudioThreatRoutes' (`threat`); `weapon_swapped` and the shots are the router's (they share its weapon state).
##
##  - area_blast: a strike impact, a mortar shell, a missile, a drum and a core vent each have their sound, the freight car
##    and a spitter bolt none (their own sounds play elsewhere); every other blast is collected for the frame and becomes
##    `blast_small` (up to 3) or one `blast_big` (4 or more), see AudioBlastMerge;
##  - chain_arc: the crackle of each jump; delayed_hit: a strike in the air warns (`warn_harm`), a spitter's bolt is spat;
##  - the interface: draft_offered (the first offer opens the draft, a later one is a reroll), directive_picked (a corrupted
##    directive has its own stamp), route_offered / route_picked, salvage_offered (the crate opens), the end of the salvage
##    await (the crate is resolved: the stamp), unlock_purchased, act_started (act 2 and 3; act 1 is the run start and has
##    the wave horn);
##  - the crate on the field: crate_dropped lands, crate_secured is banked, crate_lost is gone; weapon_vented vents;
##  - the combat drone follows the act and the threat budget of the wave in it (`intensity_for_act`).

# Mirrors of enums the audio layer may not read (HazardState.K_* in the sim, RunApi.AWAIT_*); a test pins each one.
const KIND_STRIKE: int = 1
const KIND_SHELL: int = 2
const KIND_MISSILE: int = 3
const KIND_BOLT: int = 4
const KIND_DRUM: int = 5
const KIND_VENT: int = 7
const KIND_FREIGHT: int = 8
const AWAIT_NONE: int = 0
const AWAIT_SALVAGE: int = 1

const WARN_HARM: StringName = &"warn_harm"
const REROLL_SOUND: StringName = &"draft_reroll"
const RESOLVE_SOUND: StringName = &"draft_pick"  ## a crate is resolved: the stamp of every committed choice

## The sound of an area_blast kind that does not join the merge of small blasts.
const AREA_BLAST_SOUNDS: Dictionary = {
	KIND_STRIKE: &"strike_impact", KIND_SHELL: &"mortar_blast", KIND_MISSILE: &"hornet_pop", KIND_DRUM: &"drum_blast",
	KIND_VENT: &"core_vent",
}
## area_blast kinds with no blast sound: the freight car has `freight_pass`, a bolt's impact is heard as a core hit.
const SILENT_BLASTS: Array[int] = [KIND_FREIGHT, KIND_BOLT]
## delayed_hit kinds that make a sound while the round is in the air.
const DELAYED_HIT_SOUNDS: Dictionary = {KIND_STRIKE: WARN_HARM, KIND_BOLT: &"spitter_shot"}
## The corrupted directives (CONTENT 3.6), mirrored: the audio layer cannot read the content. A test pins the shipped data.
const CORRUPTED_DIRECTIVES: Array[StringName] = [
	&"glass_cannon", &"open_gate", &"overclocked_core", &"chorus_handshake", &"unstable_munitions", &"borrowed_time",
	&"static_pact", &"single_point", &"the_tally",
]

## The drone follows the act and the place of the wave in it (5 waves an act, 15 in a run): from, to. The place is the
## threat budget of the wave (CONTENT 1.1, mirrored; a test pins `data/run.json`): the weakest normal wave of the act is
## the "from" level, the strongest the "to" level, and the boss wave is the top of its act.
const WAVES_PER_ACT: int = 5
const ACT_INTENSITY: Array[Vector2] = [Vector2(0.20, 0.40), Vector2(0.45, 0.65), Vector2(0.70, 0.90)]
const WAVE_BUDGETS: PackedInt32Array = [24, 34, 42, 66, 50, 80, 98, 118, 138, 100, 185, 210, 235, 265, 175]

var act: int = 0  ## 1..3 once `act_started` arrived in this run; 0 = a run without acts (the legacy five waves)
var draft_open: bool = false  ## a draft is on screen: the next offer is a reroll
var threat: AudioThreatRoutes = AudioThreatRoutes.new()

var _dir: AudioDirector = null
var _merge: AudioBlastMerge = AudioBlastMerge.new()
var _await: int = AWAIT_NONE  ## the last await the sim reported


## Signal name to handler, for the router to connect.
func wiring() -> Dictionary[StringName, Callable]:
	var table: Dictionary[StringName, Callable] = {
		&"act_started": on_act_started,
		&"await_changed": on_await_changed,
		&"draft_offered": on_draft_offered,
		&"directive_picked": on_directive_picked,
		&"route_offered": on_route_offered,
		&"route_picked": on_route_picked,
		&"salvage_offered": on_salvage_offered,
		&"unlock_purchased": on_unlock_purchased,
		&"crate_dropped": on_crate_dropped,
		&"crate_secured": on_crate_secured,
		&"crate_lost": on_crate_lost,
		&"weapon_vented": on_weapon_vented,
		&"area_blast": on_area_blast,
		&"chain_arc": on_chain_arc,
		&"delayed_hit": on_delayed_hit,
		&"burster_armed": on_burster_armed,
		&"weapon_charging": on_weapon_charging,
	}
	var more: Dictionary[StringName, Callable] = threat.wiring()
	for sig: StringName in more:
		table[sig] = more[sig]
	return table


func bind(director: AudioDirector) -> void:
	_dir = director
	threat.bind(director)


## One frame: the small blasts collected since the last frame start now, and so do the sounds that were waiting.
func advance(dt: float) -> void:
	for sound: StringName in _merge.take():
		_play(sound)
	threat.advance(dt)


## New run or a menu: forget the act, the open draft, the await and the blasts waiting for the frame.
func reset() -> void:
	act = 0
	draft_open = false
	_await = AWAIT_NONE
	_merge.clear()
	threat.reset()


## The drone level of wave `index` (1-based, over the whole run) inside act 1..3.
static func intensity_for_act(act_number: int, index: int) -> float:
	var span: Vector2 = ACT_INTENSITY[clampi(act_number, 1, ACT_INTENSITY.size()) - 1]
	return lerpf(span.x, span.y, budget_position(act_number, index))


## Where wave `index` stands in act `act_number` by threat budget, 0..1: the weakest normal wave of the act is 0, the
## strongest 1, and the boss wave (the last of the five, its budget is lower because the boss is the rest) is 1.
static func budget_position(act_number: int, index: int) -> float:
	var first: int = (clampi(act_number, 1, ACT_INTENSITY.size()) - 1) * WAVES_PER_ACT
	var in_act: int = clampi(index - first - 1, 0, WAVES_PER_ACT - 1)
	if in_act == WAVES_PER_ACT - 1:
		return 1.0
	var low: int = _budget(first)
	var high: int = _budget(first + WAVES_PER_ACT - 2)
	if high <= low:
		return float(in_act) / float(WAVES_PER_ACT - 2)
	return clampf(float(_budget(first + in_act) - low) / float(high - low), 0.0, 1.0)


static func _budget(wave_index: int) -> int:
	return WAVE_BUDGETS[clampi(wave_index, 0, WAVE_BUDGETS.size() - 1)]


## An act of the run begins. Act 1 begins with the run, whose wave horn is the start sound.
func on_act_started(act_number: int) -> void:
	act = act_number
	if act_number >= 2:
		_play(&"act_start")


# --- the interface -------------------------------------------------------------------------------------------------

## The first offer opens the draft; an offer while it is open is a reroll.
func on_draft_offered(_ids: Array[StringName]) -> void:
	_play(REROLL_SOUND if draft_open else &"draft_open")
	draft_open = true


func on_directive_picked(id: StringName, _stacks: int) -> void:
	draft_open = false
	_play(&"draft_pick_corrupted" if CORRUPTED_DIRECTIVES.has(id) else &"draft_pick")


## A draft that closes without a pick (SKIP) ends with the wait for an answer; a salvage that is over (the crate was
## taken or scrapped) is the stamp of a resolved crate.
func on_await_changed(kind: int) -> void:
	var was: int = _await
	_await = kind
	if kind == AWAIT_NONE:
		draft_open = false
	if was == AWAIT_SALVAGE and kind != AWAIT_SALVAGE:
		_play(RESOLVE_SOUND)


func on_route_offered() -> void:
	_play(&"draft_open")


func on_route_picked(_option: int) -> void:
	_play(&"route_pick")


func on_salvage_offered() -> void:
	_play(&"salvage_open")


func on_unlock_purchased(_id: StringName) -> void:
	_play(&"unlock_buy")


# --- the crate and the weapons -------------------------------------------------------------------------------------

func on_crate_dropped(_x: float, _z: float) -> void:
	_play(&"crate_land")


func on_crate_secured() -> void:
	_play(&"crate_secured")


func on_crate_lost() -> void:
	_play(&"crate_lost")


## The wind-up of a charged weapon (the rail lance, 1 s) starts. No `Events` signal announces it yet (the shot is fired when
## the charge ends), so this is not in `wiring()`: whoever adds `Events.weapon_charging(slot)` connects it there.
func on_weapon_charging(_slot: int) -> void:
	_play(&"rail_charge")


## A heat weapon vents: its held loop (the torch) ends with the vent.
func on_weapon_vented(slot: int) -> void:
	if _dir != null:
		_dir.release(slot)
	_play(&"weapon_vent")


# --- blasts, arcs, strikes -----------------------------------------------------------------------------------------

func on_area_blast(kind: int, _x: float, _z: float, _radius: float) -> void:
	if SILENT_BLASTS.has(kind):
		return
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


## A burster reaches its slot and arms for 1.2 s (`Events.burster_armed`, which GameEventRelay makes from the arrival of a
## fused enemy at its slot).
func on_burster_armed(_enemy_id: int) -> void:
	_play(&"burster_arm")


func _play(id: StringName) -> void:
	if _dir != null:
		_dir.play(id)
