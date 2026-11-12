class_name EnemyExtState
extends RefCounted
## Extra per-enemy state as parallel arrays by store index (VARIETY_SPEC 13.2; EnemyStore itself is frozen, ARCH 6.4).
## Integers only (9.5 rule 4): `*_milli` fields are thousandths. SimWorld.spawn_enemy resets a row; writers are
## StatusSystem (slow, burn, ward, aux), EliteSystem (flags, affix_mask, hp_scale), DamageResolver (ward, shred) and
## CoreAttackSystem (fuse). Everything is hashed.
# TODO(V2-C): burn, fuse and the mini flag for the slice. TODO(V4-N): the rest.

const F_ELITE: int = 1
const F_MINI: int = 2
const F_ARMED: int = 4  ## a burster whose fuse runs
const F_FIRED: int = 8  ## a standoff enemy that has fired (counts as attacking for targeting)
const F_EMERGING: int = 16  ## a borer still under the ground
const FIELDS: PackedStringArray = [
	"flags", "affix_mask", "ward_milli", "ward_regen_cd", "slow_ticks", "slow_milli", "burn_ticks", "burn_milli",
	"shred_milli", "fuse_ticks", "aux_cd", "anchor_point", "hp_scale_milli",
]

var capacity: int = 0
var flags: PackedInt32Array = PackedInt32Array()
var affix_mask: PackedInt32Array = PackedInt32Array()  ## bit i = AffixDef index i
var ward_milli: PackedInt32Array = PackedInt32Array()
var ward_regen_cd: PackedInt32Array = PackedInt32Array()
var slow_ticks: PackedInt32Array = PackedInt32Array()
var slow_milli: PackedInt32Array = PackedInt32Array()
var burn_ticks: PackedInt32Array = PackedInt32Array()
var burn_milli: PackedInt32Array = PackedInt32Array()  ## damage per second x 1000
var shred_milli: PackedInt32Array = PackedInt32Array()
var fuse_ticks: PackedInt32Array = PackedInt32Array()
var aux_cd: PackedInt32Array = PackedInt32Array()  ## a per-type timer (spitter bolt, reclaimer tether, hatch)
var anchor_point: PackedInt32Array = PackedInt32Array()  ## standoff point index, or -1
var hp_scale_milli: PackedInt32Array = PackedInt32Array()  ## act tier x elite x modifier, 1000 = x1


func _init(store_capacity: int = 0) -> void:
	capacity = store_capacity
	for f: String in FIELDS:
		var a: PackedInt32Array = PackedInt32Array()
		a.resize(store_capacity)
		set(f, a)
	anchor_point.fill(-1)
	hp_scale_milli.fill(1000)


## A fresh row for a newly spawned enemy.
func reset(index: int) -> void:
	if index < 0 or index >= capacity:
		return
	flags[index] = 0
	affix_mask[index] = 0
	ward_milli[index] = 0
	ward_regen_cd[index] = 0
	slow_ticks[index] = 0
	slow_milli[index] = 0
	burn_ticks[index] = 0
	burn_milli[index] = 0
	shred_milli[index] = 0
	fuse_ticks[index] = 0
	aux_cd[index] = 0
	anchor_point[index] = -1
	hp_scale_milli[index] = 1000


func has_flag(index: int, flag: int) -> bool:
	return index >= 0 and index < capacity and (flags[index] & flag) != 0


func is_elite(index: int) -> bool:
	return has_flag(index, F_ELITE)


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
