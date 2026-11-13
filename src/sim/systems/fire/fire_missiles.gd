class_name FireMissiles
extends RefCounted
## Firing kind M (VARIETY_SPEC 3.3): a salvo of `salvo` missiles, one per chosen target, each a delayed area hit that lands
## `flight_ticks` later at the target's position at launch (HazardSystem.queue_hit, K_MISSILE): `damage` at the centre
## down to `splash_damage` at `area_m`. The targets are the locked target first, then the best-ranked other enemies in
## range (FireTargets.salvo_targets); with fewer enemies than missiles the list repeats from the start, so three
## targets take two missiles each of a salvo of six. One SHOT_FIRED per salvo; the magazine counts salvos.
## The damage of a missile is that of a direct hit on its target, evaluated at launch (weapon level, the damage level and
## the conditional multipliers of DamageResolver.warden_amount); the splash is the same value x `splash_damage` / `damage`.
## ModState.area_mul (overpressure) widens the splash.


static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	if store.index_of(w.target_id) < 0:
		return false
	var range_m: float = ArsenalSystem.range_of(world, def)
	var targets: PackedInt32Array = FireTargets.salvo_targets(world, w.target_id, w.x, w.z, range_m, def.salvo)
	if targets.is_empty():
		return false
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, w.target_id)
	var level: int = world.arsenal.slot_level[slot]
	var radius: float = def.area_m * world.mods.area_mul
	var edge: float = def.splash_damage / def.damage if def.damage > 0.0 else 1.0
	var flags: int = DamageResolver.F_AREA | DamageResolver.weapon_flags(def)
	var due: int = world.tick + def.flight_ticks
	for enemy_id: int in targets:
		var i: int = store.index_of(enemy_id)
		var amount: float = DamageResolver.warden_amount(world, i, def, level)
		var _seq: int = HazardSystem.queue_hit(
			world, due, HazardState.K_MISSILE, store.x[i], store.z[i], radius, amount, edge, flags, source
		)
	return true
