class_name EventState
extends RefCounted
## Chaos events (VARIETY_SPEC 7, 13.2): the charges of player-triggered events, the events that are warning or
## running, and the tool-denying timers they set. Written by EventSystem (and its event files) only; hashed.
# TODO(V2-C): charges and the Deadfall Strike slot. TODO(V4-V): the world events.

const PH_WARN: int = 0
const PH_ACTIVE: int = 1
const FIELDS: PackedStringArray = [
	"charges", "used_this_wave", "a_event", "a_phase", "a_ticks_left", "a_x", "a_z", "plan_cursor", "ability_lock_ticks",
	"turret_offline_ticks", "turret_rate_milli", "turret_rate_ticks", "scrap_mult_milli", "scrap_mult_ticks", "cancelled",
	"last_world_event",
]

var charges: PackedInt32Array = PackedInt32Array()  ## per event index
var used_this_wave: PackedInt32Array = PackedInt32Array()  ## per event index
var a_event: PackedInt32Array = PackedInt32Array()  ## the events that are warning or running, oldest first
var a_phase: PackedInt32Array = PackedInt32Array()  ## PH_WARN or PH_ACTIVE
var a_ticks_left: PackedInt32Array = PackedInt32Array()
var a_x: PackedFloat64Array = PackedFloat64Array()
var a_z: PackedFloat64Array = PackedFloat64Array()
var plan_cursor: int = 0  ## next PlannedEvent of the current wave
var ability_lock_ticks: int = 0  ## static front
var turret_offline_ticks: int = 0  ## brownout, low power, stomp
var turret_rate_milli: int = 1000  ## core surge
var turret_rate_ticks: int = 0
var scrap_mult_milli: int = 1000  ## relay window
var scrap_mult_ticks: int = 0
var cancelled: int = 0  ## events cancelled by the mercy rule
var last_world_event: int = -1  ## rule 7.3.7: never twice in a row


func _init(event_count: int = 0) -> void:
	charges.resize(event_count)
	used_this_wave.resize(event_count)


func charges_of(event_index: int) -> int:
	if event_index < 0 or event_index >= charges.size():
		return 0
	return charges[event_index]


func active_count() -> int:
	return a_event.size()


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
