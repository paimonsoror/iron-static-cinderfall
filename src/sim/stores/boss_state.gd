class_name BossState
extends RefCounted
## The living boss and its script state (VARIETY_SPEC 6, 13.2). Written by BossSystem and its boss files only; hashed.
# TODO(V4-L): the stub holds the neutral state.

const FIELDS: PackedStringArray = [
	"boss_id", "boss_type", "variant", "phase", "phase_count", "timers", "telegraph_attack", "telegraph_left", "flags",
	"exposed_left", "parts_alive",
]

var boss_id: int = 0  ## enemy id of the living boss, 0 = none
var boss_type: int = -1  ## Ids.ENEMIES index
var variant: int = 0  ## Node 9 variant index
var phase: int = 0
var phase_count: int = 1
var timers: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])  ## script timers, meaning per boss file
var telegraph_attack: int = -1  ## the attack being telegraphed, or -1
var telegraph_left: int = 0
var flags: int = 0
var exposed_left: int = 0  ## Aegis Array damage window
var parts_alive: int = 0  ## pylons


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
