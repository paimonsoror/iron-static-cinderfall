class_name EventDef
extends RefCounted
## A chaos event (data/events.json, CONTENT 6). The index is the position in the file (SimCommand CALL_EVENT arg).

enum Who { PLAYER, WORLD }

const WHO_NAMES: PackedStringArray = ["player", "world"]

var id: StringName
var index: int
var who: int = Who.WORLD
var name_key: String
var warn_ticks: int
var duration_ticks: int
var weights: PackedFloat32Array = PackedFloat32Array()  ## per act; all zero for player-triggered events
var boss_safe: bool = false
var harmful: bool = false
var params: Dictionary[StringName, float] = {}


func param(key: StringName, fallback: float = 0.0) -> float:
	return params.get(key, fallback)
