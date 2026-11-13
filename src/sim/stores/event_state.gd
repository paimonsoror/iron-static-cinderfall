class_name EventState
extends RefCounted
## Chaos events (VARIETY_SPEC 7, 13.2): the charges of player-triggered events, the events that are warning or
## running, and the tool-denying timers they set. Written by EventSystem (and its event files) only; hashed.
##
## The active slots (`a_*`, one entry per event that is warning or running, oldest first) carry everything an event
## needs between its warning and its end, so a snapshot taken in the middle of a warning resumes onto the same ticks.
## Timers count down once per tick in EventSystem.step: `ability_lock_ticks` (Static Front: no ability can be
## activated and no cooldown runs), `turret_offline_ticks` (brownout, Low Power, a stomp), `turret_rate_ticks` with
## `turret_rate_milli` (Core Surge), `scrap_mult_ticks` with `scrap_mult_milli` (Relay Window; DeathHooks reads it).
## `plan_cursor` is the next PlannedEvent of the current wave. `cancelled` counts the events the mercy rule and the
## harmful-event limits removed. `last_world_event` is the EventDef index of the world event launched last (-1: none).
## `charges_ready` is 1 once EventSystem.init_world gave the starting charges (a kit grant made before it is kept).

const PH_WARN: int = 0
const PH_ACTIVE: int = 1
const FIELDS: PackedStringArray = [
	"charges", "used_this_wave", "a_event", "a_phase", "a_ticks_left", "a_x", "a_z", "plan_cursor", "ability_lock_ticks",
	"turret_offline_ticks", "turret_rate_milli", "turret_rate_ticks", "scrap_mult_milli", "scrap_mult_ticks", "cancelled",
	"last_world_event", "charges_ready", "brownout_cancelled", "emp_until", "breach_mask", "squat_ids",
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
var charges_ready: int = 0  ## 1 once the starting charges were given
var brownout_cancelled: int = 0  ## a Shield was activated during the surge: no brownout follows
var emp_until: int = 0  ## the tick at which the stun of the last EMP ends (borers that emerge before it are stunned)
var breach_mask: int = 0  ## floor breach: bit k = ArenaDef.breach_points[k] opens
var squat_ids: PackedInt32Array = PackedInt32Array()  ## supply drop: enemy ids standing on the crate


func _init(event_count: int = 0) -> void:
	charges.resize(event_count)
	used_this_wave.resize(event_count)


func charges_of(event_index: int) -> int:
	if event_index < 0 or event_index >= charges.size():
		return 0
	return charges[event_index]


func active_count() -> int:
	return a_event.size()


## True when an event with index `event_index` is warning or running.
func is_active(event_index: int) -> bool:
	return a_event.has(event_index)


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
