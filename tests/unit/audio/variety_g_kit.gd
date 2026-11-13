class_name VarietyGKit
extends RefCounted
## Helpers of the V2-G audio tests (not a suite).

## The 14 sounds of the slice, copied on purpose: the test must not trust the code it checks.
const SLICE_IDS: Array[StringName] = [
	&"shot_arc", &"arc_chain", &"weapon_swap",
	&"burster_arm", &"blast_small", &"blast_big", &"mote_burn",
	&"warn_harm", &"strike_call", &"strike_impact", &"crate_secured",
	&"draft_open", &"draft_pick", &"route_pick",
]

## The 60 new ids of VARIETY_SPEC 12.1 (the slice is 14 of them; task V4-A makes the other 46).
const SPEC_IDS: Array[StringName] = [
	&"shot_scattergun", &"shot_rifle", &"shot_hornet", &"hornet_pop", &"shot_lmg", &"lmg_spin", &"shot_mortar",
	&"mortar_blast", &"torch_loop", &"shot_arc", &"arc_chain", &"rail_charge", &"shot_rail", &"weapon_vent", &"weapon_swap",
	&"burster_arm", &"blast_small", &"blast_big", &"spitter_shot", &"bolt_impact", &"splitter_split", &"ward_hum",
	&"ward_break", &"jammer_pop", &"borer_emerge", &"mote_burn", &"elite_spawn",
	&"brood_hatch", &"lance_charge", &"lance_fire", &"aegis_exposed", &"tremor_stomp", &"hulk_charge", &"boss_phase",
	&"warn_harm", &"warn_help", &"strike_call", &"strike_impact", &"core_vent", &"freight_horn", &"freight_pass",
	&"static_front", &"surge_up", &"brownout", &"breach_crack", &"recount_tick", &"relay_window", &"crate_land",
	&"crate_secured", &"crate_lost", &"drum_blast",
	&"draft_open", &"draft_pick", &"draft_pick_corrupted", &"draft_reroll", &"route_pick", &"salvage_open", &"unlock_buy",
	&"act_start", &"resume_link",
]

## The voice class of every new id, copied on purpose (ids not listed here are CLASS_OTHER). The five lists cover the
## classes the pool limits; a test compares them with AudioCatalog.CLASSES.
const WEAPON_IDS: Array[StringName] = [
	&"shot_scattergun", &"shot_rifle", &"shot_hornet", &"hornet_pop", &"shot_lmg", &"lmg_spin", &"shot_mortar", &"torch_loop",
	&"shot_arc", &"arc_chain", &"rail_charge", &"shot_rail", &"weapon_vent", &"weapon_swap",
]
const BLAST_IDS: Array[StringName] = [
	&"mortar_blast", &"blast_small", &"blast_big", &"strike_impact", &"tremor_stomp", &"core_vent", &"drum_blast",
]
const ALERT_IDS: Array[StringName] = [
	&"warn_harm", &"warn_help", &"strike_call", &"brood_hatch", &"lance_charge", &"aegis_exposed", &"hulk_charge",
	&"freight_horn", &"recount_tick",
]
const UI_IDS: Array[StringName] = [
	&"crate_secured", &"draft_open", &"draft_pick", &"draft_pick_corrupted", &"draft_reroll", &"route_pick", &"salvage_open",
	&"unlock_buy", &"resume_link",
]
## The two sounds a held voice loops.
const LOOP_IDS: Array[StringName] = [&"lmg_spin", &"torch_loop"]
## Longer than 1.5 s on purpose.
const LONG_IDS: Array[StringName] = [&"lance_charge", &"static_front"]


## RMS of an imported WAV in dBFS.
static func rms_db(stream: AudioStreamWAV) -> float:
	var x: PackedFloat32Array = AudioTestKit.samples(stream)
	var sum: float = 0.0
	for v: float in x:
		sum += v * v
	return 20.0 * log(sqrt(sum / float(x.size()))) / log(10.0)


## The loudness the mix gives a sound: its file level plus the gain of its catalog row.
static func effective_db(id: StringName) -> float:
	return rms_db(AudioCatalog.load_sfx(id) as AudioStreamWAV) + AudioCatalog.volume_db(id)


## Sounds of the 16-voice pool at the top priority that are no alert: a pool full of them can only be entered by an alert.
const STINGER_IDS: Array[StringName] = [&"victory", &"defeat", &"boss_stinger", &"wave_start", &"wave_clear"]


## Starts each id `rounds` times with the per-frame cap lifted (every call is the first of its frame), so a test can fill
## the pool inside one frame. Returns how many starts succeeded.
static func flood(dir: AudioDirector, ids: Array[StringName], rounds: int) -> int:
	var started: int = 0
	for i: int in rounds:
		for id: StringName in ids:
			dir.gate.clear()
			if dir.try_play(id):
				started += 1
	return started


## Fills `count` voices with the stingers (priority 2, class OTHER): three per id, in the order of STINGER_IDS.
static func fill_with_stingers(dir: AudioDirector, count: int) -> void:
	var left: int = count
	for id: StringName in STINGER_IDS:
		for i: int in 3:
			if left <= 0:
				return
			dir.gate.clear()
			@warning_ignore("return_value_discarded")
			dir.try_play(id)
			left -= 1


## Stops everything a test started and lets the audio server drop its playbacks (no stream is still in use when the run
## ends): the settle pattern of test_game_audio_debug.gd.
static func settle(suite: GdUnitTestSuite, dir: AudioDirector) -> void:
	dir.release_all_held()
	dir.pool.stop_all()
	dir.stop_ambience()
	dir.advance(2.0)
	await suite.get_tree().create_timer(0.3).timeout


static func count_id(dir: AudioDirector, id: StringName) -> int:
	var n: int = 0
	for played: StringName in dir.recent_ids:
		if played == id:
			n += 1
	return n
