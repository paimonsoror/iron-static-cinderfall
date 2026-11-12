class_name WaveSlotDef
extends RefCounted
## One wave of the run plan (data/run.json `waves[]`, CONTENT 1.1): the budget the plan spends, not the spawn list.

enum Kind { OPENER, NORMAL, BOSS }

const KIND_NAMES: PackedStringArray = ["opener", "normal", "boss"]

var index: int  ## 1-based wave number
var act: int  ## 1..3
var kind: int = Kind.NORMAL
var budget: float
var window_ticks: int
var peak_bodied: int
var peak_minis: int
var event_slots: int
var fixed_pack: StringName = &""  ## the pack id of the opener, else empty
var fixed_pack_index: int = -1
