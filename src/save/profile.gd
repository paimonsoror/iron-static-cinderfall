class_name Profile
extends RefCounted
## The player profile (ARCH 7.5, profile v2). Plain data; ProfileCodec turns it into JSON.

const SCHEMA_VERSION: int = 2
const MAX_AWARDED: int = 64  ## awarded_run_ids keeps the newest 64
const MAX_HINTS: int = 128
const MAX_UNLOCKS: int = 256
const MAX_CLAIMED: int = 256
const MAX_CODEX: int = 256
const MAX_WEAPONS: int = 64  ## victory_weapons
const MAX_TALLY: int = 64  ## entries of boss_kills and victories_by_kit
const DEFAULT_KIT: StringName = &"k_standard"
const MAX_ID_LENGTH: int = 128  ## longer run ids or hint keys are not ids; they are dropped on load
const MAX_FILE_CHARS: int = 1000000  ## a real profile is under 5 KB; a larger file is treated as damaged
const MAX_COUNT: int = 2147483647  ## counters never exceed this (JSON numbers are doubles; stay far below 2^53)
const BOOL_SETTINGS: Array[StringName] = [
	&"sound_on", &"music_on", &"haptics_on", &"reduced_flash", &"high_contrast", &"swap_assist",
]
const QUALITY_MAX: int = 2  ## quality is 0..2 (VisualQuality tiers)
const FPS_CAPS: Array[int] = [30, 60]
## The waves of the legacy five-wave run: a v1 profile with a mission completed has cleared this many (the migration).
const V1_BEST_WAVE: int = 5

var data: int = 0  ## Recovered Data in hand (the Archive spends it)
var missions_completed: int = 0
var best_core_hp: int = 0
var runs_played: int = 0
var awarded_run_ids: PackedStringArray = PackedStringArray()  ## newest last, capped at 64
var hints_seen: PackedStringArray = PackedStringArray()
var settings: Dictionary[StringName, Variant] = {}
# --- profile v2 (ARCH 7.5; VARIETY_SPEC 13.3) ---
var data_lifetime: int = 0  ## all Data ever earned; never spent down
var unlocks: PackedStringArray = PackedStringArray()  ## unlock ids; unknown ids are kept (a newer build's file)
var claimed: PackedStringArray = PackedStringArray()  ## milestone ids already paid
var kit: StringName = DEFAULT_KIT  ## the kit picked for the next run
var codex_seen: PackedStringArray = PackedStringArray()
var best_wave: int = 0  ## most waves cleared in any run
var boss_kills: Dictionary[String, int] = {}  ## boss id -> kills over all runs
var victories_by_kit: Dictionary[String, int] = {}  ## kit id -> victories
var victory_weapons: PackedStringArray = PackedStringArray()  ## primary weapons (ids) of victories, each once
var daily: Dictionary[String, Variant] = {}  ## {date, best_wave, won, rewarded} of the Daily Run of `date` (UTC)


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
		&"swap_assist": false,
	}
	p.daily = empty_daily()
	return p


static func empty_daily() -> Dictionary[String, Variant]:
	return {"date": "", "best_wave": 0, "won": false, "rewarded": false}


## True for "YYYY-MM-DD" (the shape of a Daily Run date; the calendar is not checked).
static func is_date(text: String) -> bool:
	if text.length() != 10 or text[4] != "-" or text[7] != "-":
		return false
	for i: int in [0, 1, 2, 3, 5, 6, 8, 9]:
		if not text[i].is_valid_int():
			return false
	return true


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
