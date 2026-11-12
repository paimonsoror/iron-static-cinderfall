class_name StatusSystem
extends RefCounted
## Per-enemy statuses (tick step 7): slow, burn, ward regeneration, auras, reclaimer tethers. Writes EnemyExtState.
## Burn damage goes through DamageResolver.hit_ex(F_BURN). Called every tick of a live run: gate on combat inside.
# TODO(V2-C): burn (incendiary_tips). TODO(V4-N): slow, wards, auras, tethers.


static func step(_world: SimWorld) -> void:
	pass


## Slows an enemy by `milli` / 1000 of its speed for `ticks` (the stronger slow wins, never stacks).
static func apply_slow(_world: SimWorld, _enemy_index: int, _ticks: int, _milli: int) -> void:
	pass


## Ignites an enemy: `dps_milli` damage per second x 1000 for `ticks` (refreshes, does not stack).
static func apply_burn(_world: SimWorld, _enemy_index: int, _ticks: int, _dps_milli: int) -> void:
	pass
