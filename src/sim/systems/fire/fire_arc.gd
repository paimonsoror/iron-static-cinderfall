class_name FireArc
extends RefCounted
## Firing kind A (VARIETY_SPEC 3.3): the target takes full damage, then up to `chains` jumps, each to the nearest
## not-yet-hit enemy within `chain_range_m` (x ModState.area_mul) of the last one hit, lowest id on ties; jump k deals
## the damage x `chain_falloff`^k. The chain continues from where a victim stood even when the hit killed it.
## Pushes SHOT_FIRED, then CHAIN_ARC(from id, to id) before each hit: (0, target) for the bolt from the Warden and one
## per jump. The jumps are F_AREA hits: they run no on-hit hooks.


static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	var current: int = store.index_of(w.target_id)
	if current < 0:
		return false
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, w.target_id)
	var level: int = world.arsenal.slot_level[slot]
	var reach: float = def.chain_range_m * world.mods.area_mul
	var hit_ids: PackedInt32Array = PackedInt32Array()
	var from_id: int = 0
	var scale: float = 1.0
	var flags: int = 0
	for jump: int in def.chains + 1:
		var at_x: float = store.x[current]
		var at_z: float = store.z[current]
		var to_id: int = store.id[current]
		hit_ids.append(to_id)
		world.events.push(SimEventKind.Id.CHAIN_ARC, from_id, to_id)
		DamageResolver.warden_hit(world, current, def, level, scale, flags, source)
		if jump == def.chains:
			break
		current = _nearest(store, at_x, at_z, reach, hit_ids)
		if current < 0:
			break
		from_id = to_id
		scale *= def.chain_falloff
		flags = DamageResolver.F_AREA
	return true


## The living enemy not in `hit_ids` nearest to (x, z) within `reach`, the lower id on a tie. -1 = none.
static func _nearest(store: EnemyStore, x: float, z: float, reach: float, hit_ids: PackedInt32Array) -> int:
	var best: int = -1
	var best_sq: float = reach * reach
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var dx: float = store.x[i] - x
		var dz: float = store.z[i] - z
		var d_sq: float = dx * dx + dz * dz
		if d_sq > best_sq or hit_ids.has(store.id[i]):
			continue
		if best < 0 or d_sq < best_sq or store.id[i] < store.id[best]:
			best = i
			best_sq = d_sq
	return best
