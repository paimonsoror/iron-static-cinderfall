class_name CombatState
extends RefCounted
## State owned by the combat systems (ARCH 6.6): per-source tallies the balance harness reads.
## Indexed by DamageSource.Id (WARDEN, TURRET_0, TURRET_1, WARDEN_OFFHAND, CORE, STRIKE, HAZARD). Written by WeaponSystem, TurretSystem,
## DamageResolver and CoreAttackSystem only; everything here is hashed.

const SOURCES: int = 7  ## == DamageSource.COUNT (3 before the variety milestone)

var shots_by_source: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var damage_by_source: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])  ## hp actually removed
var kills_by_source: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
var core_hits: int = 0  ## enemy hits on the core, shield-absorbed or not


func hash_into(h: StateHasher) -> void:
	h.put_ints(shots_by_source)
	h.put_floats(damage_by_source)
	h.put_ints(kills_by_source)
	h.put_int(core_hits)
