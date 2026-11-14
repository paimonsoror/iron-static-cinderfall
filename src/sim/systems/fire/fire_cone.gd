class_name FireCone
extends RefCounted
## Firing kind C (VARIETY_SPEC 3.3): a spread of `pellets` goes to the enemies inside `range_m` and inside the cone of
## `spread_deg` (the full angle) around the line from the Warden to the locked target. An enemy is inside the cone when
## its body touches it (the angle of its centre, less the angle its radius covers, is within half the cone).
## Pellets are dealt nearest first (distance, then the lower id): each enemy takes up to PELLET_CAP of them while other
## targets remain, and once every target has its share the rest go to the nearest enemy. Each pellet is a direct hit of
## `damage` (armor applies per pellet). One SHOT_FIRED per shot.
## Knockback (`knockback_m`): every enemy the shot hit and left alive is shoved that far along the line from the Warden
## to it, if its mass is below KNOCKBACK_MAX_MASS and it is neither attacking the core (MovementSystem holds attackers on
## their slot) nor ANCHORED. The move is MovementSystem.knockback, which fences it like a walk (props, the core cage,
## the yard) and moves a body above MovementSystem.KNOCKBACK_FULL_MASS proportionally less.

const PELLET_CAP: int = 3
const KNOCKBACK_MAX_MASS: float = 3.0


static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var store: EnemyStore = world.enemies
	var target: int = store.index_of(w.target_id)
	if target < 0:
		return false
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, w.target_id)
	var level: int = world.arsenal.slot_level[slot]
	var members: PackedInt32Array = members_in_cone(world, w.x, w.z, store.x[target], store.z[target], def)
	var shares: PackedInt32Array = deal(members.size(), def.pellets)
	for k: int in members.size():
		for _p: int in shares[k]:
			DamageResolver.warden_hit(world, members[k], def, level, 1.0, 0, source)
	if def.knockback_m > 0.0:
		for i: int in members:
			shove(world, i, w.x, w.z, def.knockback_m)
	return true


## Store indices of the living enemies inside the cone from (ox, oz) toward (tx, tz), nearest first (lower id on a tie).
static func members_in_cone(
	world: SimWorld, ox: float, oz: float, tx: float, tz: float, def: WeaponDef
) -> PackedInt32Array:
	var store: EnemyStore = world.enemies
	var range_m: float = ArsenalSystem.range_of(world, def)
	var dir_x: float = tx - ox
	var dir_z: float = tz - oz
	var dir_len: float = sqrt(dir_x * dir_x + dir_z * dir_z)
	if dir_len < 0.0001:
		dir_x = 1.0
		dir_z = 0.0
	else:
		dir_x /= dir_len
		dir_z /= dir_len
	var half: float = deg_to_rad(def.spread_deg) * 0.5
	var found: PackedInt32Array = PackedInt32Array()
	var dists: PackedFloat64Array = PackedFloat64Array()
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var px: float = store.x[i] - ox
		var pz: float = store.z[i] - oz
		var dist: float = sqrt(px * px + pz * pz)
		if dist > range_m:
			continue
		if dist > 0.0001:
			var cos_a: float = clampf((px * dir_x + pz * dir_z) / dist, -1.0, 1.0)
			var slack: float = asin(minf(1.0, world.content.enemies[store.type[i]].radius / dist))
			if acos(cos_a) - slack > half + 0.000001:
				continue
		var at: int = found.size()
		while at > 0 and (dists[at - 1] > dist or (dists[at - 1] == dist and store.id[found[at - 1]] > store.id[i])):
			at -= 1
		found.insert(at, i)
		dists.insert(at, dist)
	return found


## How many of `pellets` each of `count` targets (nearest first) takes: PELLET_CAP each in order, the rest to the nearest.
static func deal(count: int, pellets: int) -> PackedInt32Array:
	var shares: PackedInt32Array = PackedInt32Array()
	shares.resize(count)
	var left: int = pellets
	for k: int in count:
		var take: int = mini(PELLET_CAP, left)
		shares[k] = take
		left -= take
	if count > 0:
		shares[0] += left
	return shares


## Shoves the enemy at store index `i` up to `dist_m` along the line from (ox, oz) to it; see the header for who stays put.
## The move itself is MovementSystem.knockback (the one writer of enemy positions: fenced like a walk, and scaled down
## for a body heavier than MovementSystem.KNOCKBACK_FULL_MASS).
static func shove(world: SimWorld, i: int, ox: float, oz: float, dist_m: float) -> void:
	var store: EnemyStore = world.enemies
	if store.alive[i] == 0 or store.state[i] == EnemyStore.ST_ATTACKING:
		return
	var def: EnemyDef = world.content.enemies[store.type[i]]
	if def.mass >= KNOCKBACK_MAX_MASS:
		return
	var _moved: float = MovementSystem.knockback(world, i, store.x[i] - ox, store.z[i] - oz, dist_m)
