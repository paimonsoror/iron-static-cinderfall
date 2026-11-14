class_name SimConfig
extends RefCounted

var run_seed: int
var content: ContentSet
var debug_invulnerable_core: bool = false
var debug_damage_mult: float = 1.0
var debug_start_scrap: int = 0
# --- variety milestone (VARIETY_SPEC 13.2). The defaults are the base pool and the standard kit. ---
var kit_index: int = 0  ## ContentSet.kits index
var unlocked: PackedStringArray = PackedStringArray()  ## the profile's unlock ids, sorted; ignored when `daily`
var daily: bool = false  ## the Daily Run: the full pool regardless of `unlocked`
# --- 15-wave integration (V5-A): the debug starts of ARCH 11, applied by DebugStart at tick 0 ---
var debug_start_wave: int = 0  ## > 1: the run begins at this wave with a scripted build (`--wave=<n>`)
var debug_boss: StringName = &""  ## a BossDef or Node 9 variant id: start at its boss wave (`--scenario=boss:<id>`)


static func create(content_set: ContentSet, seed_value: int) -> SimConfig:
	var c: SimConfig = SimConfig.new()
	c.content = content_set
	c.run_seed = seed_value
	return c


## True when a debug switch is on: such a run is paid its Data but leaves no trace in the Archive (GameRewards).
func is_debug() -> bool:
	return (
		debug_invulnerable_core or debug_damage_mult != 1.0 or debug_start_scrap != 0 or debug_start_wave > 1
		or debug_boss != &""
	)


## True when the unlock `unlock_id` counts for this run.
func has_unlock(unlock_id: String) -> bool:
	return daily or unlocked.has(unlock_id)
