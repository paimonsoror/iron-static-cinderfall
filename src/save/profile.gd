class_name Profile
extends RefCounted
## The player profile (ARCH 7.5). Plain data; ProfileCodec turns it into JSON.

const SCHEMA_VERSION: int = 1

var data: int = 0
var missions_completed: int = 0
var best_core_hp: int = 0
var runs_played: int = 0
var awarded_run_ids: PackedStringArray = PackedStringArray()  ## newest last, capped at 64
var hints_seen: PackedStringArray = PackedStringArray()
var settings: Dictionary[StringName, Variant] = {}


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
