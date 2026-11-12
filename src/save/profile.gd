class_name Profile
extends RefCounted
## The player profile (ARCH 7.5). Plain data; ProfileCodec turns it into JSON.

const SCHEMA_VERSION: int = 1
const MAX_AWARDED: int = 64  ## awarded_run_ids keeps the newest 64
const MAX_HINTS: int = 128
const MAX_UNLOCKS: int = 256
const DEFAULT_KIT: StringName = &"k_standard"
const MAX_ID_LENGTH: int = 128  ## longer run ids or hint keys are not ids; they are dropped on load
const MAX_FILE_CHARS: int = 1000000  ## a real profile is under 5 KB; a larger file is treated as damaged
const MAX_COUNT: int = 2147483647  ## counters never exceed this (JSON numbers are doubles; stay far below 2^53)
const BOOL_SETTINGS: Array[StringName] = [&"sound_on", &"music_on", &"haptics_on", &"reduced_flash", &"high_contrast"]
const QUALITY_MAX: int = 2  ## quality is 0..2 (VisualQuality tiers)
const FPS_CAPS: Array[int] = [30, 60]

var data: int = 0
var missions_completed: int = 0
var best_core_hp: int = 0
var runs_played: int = 0
var awarded_run_ids: PackedStringArray = PackedStringArray()  ## newest last, capped at 64
var hints_seen: PackedStringArray = PackedStringArray()
var settings: Dictionary[StringName, Variant] = {}
# --- variety milestone (ARCH 7.5 profile v2, read ahead of the migration of task V4-M) ---
var unlocks: PackedStringArray = PackedStringArray()  ## unlock ids; unknown ids are kept (a newer build's file)
var kit: StringName = DEFAULT_KIT  ## the kit picked for the next run


static func defaults() -> Profile:
	var p: Profile = Profile.new()
	p.settings = {
		&"sound_on": true,
		&"music_on": true,
		&"haptics_on": true,
		&"reduced_flash": false,
		&"high_contrast": false,
		&"quality": 2,
		&"fps_cap": 60,
	}
	return p


## True when `key` is a known setting and `value` has its type and range (bool toggles, quality 0..2, fps_cap 30 or 60).
static func setting_is_valid(key: StringName, value: Variant) -> bool:
	if BOOL_SETTINGS.has(key):
		return typeof(value) == TYPE_BOOL
	if (key == &"quality" or key == &"fps_cap") and typeof(value) == TYPE_INT:
		var n: int = value
		if key == &"quality":
			return n >= 0 and n <= QUALITY_MAX
		return FPS_CAPS.has(n)
	return false
