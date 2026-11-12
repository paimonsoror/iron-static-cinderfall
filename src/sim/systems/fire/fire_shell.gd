class_name FireShell
extends RefCounted
## Firing kind S (VARIETY_SPEC 3.3): the target point is the centre of the densest cluster between `min_range_m` and the
## range (Targeting.pick_cluster with the blast radius, ties by the best-ranked enemy in it); the shell lands
## `flight_ticks` later as a delayed area hit of `damage` at the centre down to `damage` x `edge_frac` at the edge
## (HazardSystem.queue_hit, K_SHELL) and leaves a ground pool. The lock does not matter: with no enemy between the
## minimum range and the maximum range the weapon holds fire (false: no shot is paid for).
## The damage is that of a direct hit on the enemy at the cluster centre, evaluated at launch (weapon level, the damage
## level and the conditional multipliers of DamageResolver.warden_amount). A shell is the Warden's: kills count for it.
## Pool: the pool starts at launch and lives `flight_ticks` + `pool_ticks`, so it burns for exactly `pool_ticks` after the
## shell lands. (HazardSystem starts pools only through add_pool and has no hook for a landing; its first pulse can
## fall inside the flight. See the V4-W report, "needs owner".)
## ModState.area_mul (overpressure) widens the blast and the pool.


static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var radius: float = def.area_m * world.mods.area_mul
	var range_m: float = ArsenalSystem.range_of(world, def)
	var at: Vector2 = Targeting.pick_cluster(world, w.x, w.z, def.min_range_m, range_m, radius)
	if at == Vector2(w.x, w.z):  # pick_cluster answers the shooter's own position (as a Vector2) when nothing is in the band
		return false
	var found: PackedInt32Array = PackedInt32Array()
	var anchor: int = -1
	if AreaDamage.query(world, at.x, at.y, 0.05, found) > 0:
		anchor = found[0]
	if anchor < 0:
		return false
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, world.enemies.id[anchor])
	var level: int = world.arsenal.slot_level[slot]
	var amount: float = DamageResolver.warden_amount(world, anchor, def, level)
	HazardSystem.queue_hit(
		world, world.tick + def.flight_ticks, HazardState.K_SHELL, at.x, at.y, radius, amount, def.edge_frac,
		DamageResolver.F_AREA | DamageResolver.weapon_flags(def), source
	)
	if def.pool_ticks > 0:
		var pool_radius: float = def.pool_radius_m * world.mods.area_mul
		var _pool: int = HazardSystem.add_pool(
			world, at.x, at.y, pool_radius, def.flight_ticks + def.pool_ticks, def.pool_dps, def.pool_slow
		)
	w.aim_x = at.x
	w.aim_z = at.y
	return true
