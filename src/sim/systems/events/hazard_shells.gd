class_name HazardShells
extends RefCounted
## What a slag mortar shell leaves where it lands: the ground pool of the mortar (VARIETY_SPEC 3.3, CONTENT 2). HazardSystem
## calls `landed` for every K_SHELL hit the moment it lands (the landing hook the weapon file FireShell waited for). Only the
## Warden's shells (WARDEN, WARDEN_OFFHAND) leave a pool. The pool has the numbers of the mortar in the Warden's slots
## (its weapon level counts), else those of the plain data entry; ModState.area_mul widens it. The blast of the shell itself
## is the hit, so the fuel drums it touches are lit by HazardSystem as for any blast.


## The shell of `source` has landed at (x, z).
static func landed(world: SimWorld, x: float, z: float, source: int) -> void:
	if source != DamageSource.Id.WARDEN and source != DamageSource.Id.WARDEN_OFFHAND:
		return
	if Ids.WP_SLAG_MORTAR >= world.content.weapons.size():
		return
	var def: WeaponDef = world.content.weapons[Ids.WP_SLAG_MORTAR]
	var slot: int = ArsenalSystem.slot_of(world, Ids.WP_SLAG_MORTAR)
	if slot >= 0:
		def = ArsenalSystem.effective_of(world, slot)
	if def.pool_ticks <= 0:
		return
	var _pool: int = HazardSystem.add_pool(
		world, x, z, def.pool_radius_m * world.mods.area_mul, def.pool_ticks, def.pool_dps, def.pool_slow
	)

