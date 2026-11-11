class_name AudioTestKit
extends RefCounted
## Helpers shared by the audio tests (not a suite itself).

## The 29 sound ids of ARCH 10, copied here on purpose: the test must not trust the code it checks.
const ARCH_IDS: Array[StringName] = [
	&"shot_pistol", &"shot_smg", &"shot_turret", &"reload_start", &"reload_done", &"hit_ceramic", &"hit_armor",
	&"death_small", &"death_heavy", &"death_boss", &"core_hit_light", &"core_hit_heavy", &"boss_stomp", &"emp",
	&"shield_up", &"shield_break", &"overdrive_on", &"overdrive_off", &"ui_tap", &"ui_purchase", &"ui_deny",
	&"ui_drawer", &"wave_start", &"wave_clear", &"intermission_tick", &"core_low", &"boss_stinger", &"victory",
	&"defeat",
]


## A director added to `suite` (its _ready runs) with no Events router and the wall-clock interval off, so a test
## only depends on the per-frame cap and on what it calls. The suite frees it.
static func make_director(suite: GdUnitTestSuite) -> AudioDirector:
	var director: AudioDirector = AudioDirector.new()
	director.auto_route = false
	suite.add_child(director)
	@warning_ignore("return_value_discarded")
	suite.auto_free(director)
	director.sound_on = true
	director.music_on = true
	director.gate.intervals_enabled = false
	return director


## A director plus an AudioEventRouter bound to `source` (a fake Events node). The router is set on the director so
## `advance` drives its timers.
static func make_routed(suite: GdUnitTestSuite, source: Node) -> AudioDirector:
	var director: AudioDirector = make_director(suite)
	director.router = AudioEventRouter.new()
	director.router.bind(source, director)
	return director


## Mono 16-bit samples of an imported WAV as floats in -1..1.
static func samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	var count: int = data.size() >> 1
	var out: PackedFloat32Array = PackedFloat32Array()
	@warning_ignore("return_value_discarded")
	out.resize(count)
	for i: int in count:
		out[i] = float(data.decode_s16(i * 2)) / 32768.0
	return out


static func peak(x: PackedFloat32Array) -> float:
	var p: float = 0.0
	for v: float in x:
		p = maxf(p, absf(v))
	return p


## Step across the loop point (last sample to first) over the mean of the two steps on each side of it: about 1 for
## a continuous signal, much larger for a click.
static func seam_ratio(x: PackedFloat32Array) -> float:
	var n: int = x.size()
	var wrap: float = absf(x[0] - x[n - 1])
	var near: float = (absf(x[n - 1] - x[n - 2]) + absf(x[n - 2] - x[n - 3]) + absf(x[1] - x[0]) + absf(x[2] - x[1])) / 4.0
	return wrap / maxf(near, 0.000001)
