class_name GroupDraft
extends RefCounted
## One group of a wave while WaveBuilder works on it (counts change under the composition rules of VARIETY_SPEC 5.3
## before the group becomes a SpawnGroupDef).

## Interval bounds of CONTENT 1.3 (0.08 s and 4.0 s at 60 ticks per second).
const MIN_INTERVAL_TICKS: int = 5
const MAX_INTERVAL_TICKS: int = 240

var enemy_index: int = 0
var count: int = 1
var cost: float = 1.0  ## threat points of one body
var start_frac: float = 0.0  ## fraction of the wave window
var tempo: float = 1.0  ## multiplies the even spacing (below 1 = bunched early)
var region: StringName = &"right"
var min_start_tick: int = 0  ## the group may not start earlier than this (rules 4 and 6 of 5.3)


func spent() -> float:
	return float(count) * cost


## The spawn group: start = start fraction of the window (not before `min_start_tick`), interval = the window left after
## the start, times the tempo, spread over the count.
func to_def(window_ticks: int) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = enemy_index
	g.count = count
	g.start_tick = maxi(min_start_tick, roundi(start_frac * float(window_ticks)))
	var spacing: float = float(window_ticks) * (1.0 - start_frac) * tempo / float(maxi(1, count))
	g.interval_ticks = clampi(roundi(spacing), MIN_INTERVAL_TICKS, MAX_INTERVAL_TICKS)
	g.region_id = region
	return g
