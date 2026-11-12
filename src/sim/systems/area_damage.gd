class_name AreaDamage
extends RefCounted
## Area hits (VARIETY_SPEC 9.5 rule 1, 13.2): victims come from SpatialHash.query and are processed in id order; every
## hit goes through DamageResolver.hit_ex with F_AREA. Never recursion: a death caused here queues its own blast
## through DeathHooks and HazardSystem, which lands on a later tick.
##
## The spatial hash here is a scratch index, not state: it is rebuilt from the store at the start of every query (the
## movement system's own hash leaves out attackers and bosses), so two worlds stepped in turn never see each other.

static var _hash: SpatialHash = SpatialHash.new()
static var _found: PackedInt32Array = PackedInt32Array()


## Damages every living enemy within `radius` of (x, z): full `damage` at the centre, `damage * edge_frac` at the edge.
## `flags` are DamageResolver.F_*; `source` is a DamageSource.Id. Pushes AREA_BLAST(K_BLAST, radius in cm, x, z).
## Returns the number of enemies hit.
static func blast(
	world: SimWorld, x: float, z: float, radius: float, damage: float, edge_frac: float, flags: int, source: int
) -> int:
	world.events.push(SimEventKind.Id.AREA_BLAST, HazardState.K_BLAST, roundi(radius * 100.0), x, z)
	return apply(world, x, z, radius, damage, edge_frac, flags, source)


## `blast` without the event (HazardSystem pushes its own, with the kind of the delayed hit).
static func apply(
	world: SimWorld, x: float, z: float, radius: float, damage: float, edge_frac: float, flags: int, source: int
) -> int:
	if radius <= 0.0:
		return 0
	var store: EnemyStore = world.enemies
	var victims: PackedInt32Array = PackedInt32Array()
	var n: int = query(world, x, z, radius, victims)
	for i: int in victims:
		if store.alive[i] == 0:
			continue
		var dx: float = store.x[i] - x
		var dz: float = store.z[i] - z
		var t: float = minf(1.0, sqrt(dx * dx + dz * dz) / radius)
		DamageResolver.hit_ex(world, i, damage * (1.0 - (1.0 - edge_frac) * t), flags | DamageResolver.F_AREA, source)
	return n


## Fills `out` with the store indices of the living enemies within `radius` of (x, z), sorted by enemy id.
static func query(world: SimWorld, x: float, z: float, radius: float, out: PackedInt32Array) -> int:
	_hash.rebuild(world.enemies)
	_hash.query(x, z, radius, _found)
	out.clear()
	out.append_array(_found)
	return out.size()


## The centre of the densest cluster: the position of the enemy with the most living enemies within `radius` of it,
## among enemies between `min_range` and `max_range` of (from_x, from_z); ties go to the cluster that holds the
## best-ranked enemy (Targeting.compare), then to the centre with the lower id. Returns (x, z), or (from_x, from_z)
## when no enemy is in range. This is the body Targeting.pick_cluster should have (that file is frozen for V2-C).
static func densest_cluster(
	world: SimWorld, from_x: float, from_z: float, min_range: float, max_range: float, radius: float
) -> Vector2:
	var store: EnemyStore = world.enemies
	var min_sq: float = min_range * min_range
	var max_sq: float = max_range * max_range
	var r_sq: float = radius * radius
	var centres: PackedInt32Array = PackedInt32Array()
	var best_count: int = 0
	for c: int in store.high_water:
		if store.alive[c] == 0:
			continue
		var fx: float = store.x[c] - from_x
		var fz: float = store.z[c] - from_z
		var from_sq: float = fx * fx + fz * fz
		if from_sq < min_sq or from_sq > max_sq:
			continue
		var count: int = _count_near(store, store.x[c], store.z[c], r_sq)
		if count > best_count:
			best_count = count
			centres.clear()
		if count == best_count:
			centres.append(c)
	if centres.is_empty():
		return Vector2(from_x, from_z)
	var best_centre: int = centres[0]
	var best_member: int = _best_member(world, best_centre, r_sq, from_x, from_z)
	for k: int in range(1, centres.size()):
		var c: int = centres[k]
		var member: int = _best_member(world, c, r_sq, from_x, from_z)
		var better: bool = false
		if member != best_member:
			better = Targeting.compare(world, member, best_member, from_x, from_z)
		else:
			better = store.id[c] < store.id[best_centre]
		if better:
			best_centre = c
			best_member = member
	return Vector2(store.x[best_centre], store.z[best_centre])


static func _count_near(store: EnemyStore, x: float, z: float, r_sq: float) -> int:
	var count: int = 0
	for j: int in store.high_water:
		if store.alive[j] == 0:
			continue
		var dx: float = store.x[j] - x
		var dz: float = store.z[j] - z
		if dx * dx + dz * dz <= r_sq:
			count += 1
	return count


## The best-ranked living enemy within the cluster around store index `centre`.
static func _best_member(world: SimWorld, centre: int, r_sq: float, from_x: float, from_z: float) -> int:
	var store: EnemyStore = world.enemies
	var best: int = centre
	for j: int in store.high_water:
		if store.alive[j] == 0 or j == centre:
			continue
		var dx: float = store.x[j] - store.x[centre]
		var dz: float = store.z[j] - store.z[centre]
		if dx * dx + dz * dz <= r_sq and Targeting.compare(world, j, best, from_x, from_z):
			best = j
	return best
