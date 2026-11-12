class_name FireHitscan
extends RefCounted
## Firing kind H (VARIETY_SPEC 3.3): as today; optional `pierce` hits the next enemy within 2 m behind the last one
## hit on the shooter-target line (each x `pierce_falloff`; -1 = every enemy on the line). An enemy is on the line
## when the line passes through its body circle; the nearest along the line is taken, the lower id on a tie.
# TODO(V4-W): LMG strays (the `aim` stream) and armor shred.

const PIERCE_REACH_M: float = 2.0


## One shot of `def` from weapon slot `slot` at the Warden's current target. True when a shot left the weapon.
## Pushes SHOT_FIRED(source, target id) before the damage.
static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	var target: int = store.index_of(w.target_id)
	if target < 0:
		return false
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, w.target_id)
	var level: int = world.arsenal.slot_level[slot]
	var dx: float = store.x[target] - w.x
	var dz: float = store.z[target] - w.z
	var skip: PackedInt32Array = PackedInt32Array([w.target_id])
	DamageResolver.warden_hit(world, target, def, level, 1.0, 0, source)
	var reach: float = sqrt(dx * dx + dz * dz)
	if def.pierce == 0 or reach < 0.0001:
		return true
	dx /= reach
	dz /= reach
	var scale: float = 1.0
	var passes: int = 0
	while def.pierce < 0 or passes < def.pierce:
		var next: int = _next_on_line(world, w.x, w.z, dx, dz, reach, skip)
		if next < 0:
			break
		reach = (store.x[next] - w.x) * dx + (store.z[next] - w.z) * dz
		skip.append(store.id[next])
		scale *= def.pierce_falloff
		DamageResolver.warden_hit(world, next, def, level, scale, 0, source)
		passes += 1
	return true


## The living enemy not in `skip` whose body the line from (ox, oz) along (dx, dz) crosses between `after` and
## `after` + PIERCE_REACH_M metres: the nearest along the line, the lower id on a tie. -1 = none.
static func _next_on_line(
	world: SimWorld, ox: float, oz: float, dx: float, dz: float, after: float, skip: PackedInt32Array
) -> int:
	var store: EnemyStore = world.enemies
	var best: int = -1
	var best_along: float = 0.0
	for i: int in store.high_water:
		if store.alive[i] == 0 or skip.has(store.id[i]):
			continue
		var px: float = store.x[i] - ox
		var pz: float = store.z[i] - oz
		var along: float = px * dx + pz * dz
		if along < after or along > after + PIERCE_REACH_M:
			continue
		var off: float = absf(px * dz - pz * dx)
		if off > world.content.enemies[store.type[i]].radius:
			continue
		if best < 0 or along < best_along or (along == best_along and store.id[i] < store.id[best]):
			best = i
			best_along = along
	return best
