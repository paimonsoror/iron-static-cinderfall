class_name AttackSlots
extends RefCounted
## The 64 attack slots on rings around the core (ARCH 5.2, 6.6). Slots of one ring are consecutive indices.
## An enemy of `slot_span` n holds n adjacent slots of one ring and stands on the middle one
## (`EnemyStore.slot` is that middle slot). Occupancy is the enemy id, 0 = free.

var _occ: PackedInt32Array = PackedInt32Array()
var _ring_first: PackedInt32Array = PackedInt32Array()
var _ring_len: PackedInt32Array = PackedInt32Array()
var pos_x: PackedFloat64Array = PackedFloat64Array()  ## slot world X, indexed by slot
var pos_z: PackedFloat64Array = PackedFloat64Array()  ## slot world Z


## Reads slot positions and ring boundaries from the arena. Called by NavState.setup.
func setup(arena: ArenaDef) -> void:
	var n: int = arena.slot_positions.size()
	_occ.resize(n)
	_occ.fill(0)
	pos_x.resize(n)
	pos_z.resize(n)
	_ring_first.clear()
	_ring_len.clear()
	var last_ring: int = -1
	for k: int in n:
		pos_x[k] = arena.slot_positions[k].x
		pos_z[k] = arena.slot_positions[k].y
		var ring: int = arena.slot_ring[k]
		if ring != last_ring:
			_ring_first.append(k)
			_ring_len.append(0)
			last_ring = ring
		_ring_len[_ring_len.size() - 1] += 1


func slot_count() -> int:
	return _occ.size()


## World (x, z) of a slot.
func slot_position(slot_index: int) -> Vector2:
	return Vector2(pos_x[slot_index], pos_z[slot_index])


## Lowest ring with a free run of `slot_span`; nearest in ring; tie -> lower index. -1 = none.
## Writes `enemies.slot` (the middle slot of the run) and returns it. An enemy that already holds a slot keeps it.
func claim(world: SimWorld, enemy_index: int) -> int:
	var es: EnemyStore = world.enemies
	if es.slot[enemy_index] >= 0:
		return es.slot[enemy_index]
	var span: int = maxi(1, world.content.enemies[es.type[enemy_index]].slot_span)
	var ex: float = es.x[enemy_index]
	var ez: float = es.z[enemy_index]
	var half: int = (span - 1) >> 1
	for ring: int in _ring_first.size():
		var first: int = _ring_first[ring]
		var best_start: int = -1
		var best_d2: float = INF
		for s: int in range(first, first + _ring_len[ring] - span + 1):
			var free: bool = true
			for q: int in span:
				if _occ[s + q] != 0:
					free = false
					break
			if not free:
				continue
			var dx: float = pos_x[s + half] - ex
			var dz: float = pos_z[s + half] - ez
			var d2: float = dx * dx + dz * dz
			if d2 < best_d2:
				best_d2 = d2
				best_start = s
		if best_start >= 0:
			for q: int in span:
				_occ[best_start + q] = es.id[enemy_index]
			es.slot[enemy_index] = best_start + half
			return best_start + half
	return -1


## Frees every slot the enemy holds and clears `enemies.slot`. A no-op for an enemy without a slot.
func release(world: SimWorld, enemy_index: int) -> void:
	var es: EnemyStore = world.enemies
	if es.slot[enemy_index] < 0:
		return
	var enemy_id: int = es.id[enemy_index]
	if enemy_id != 0:
		for k: int in _occ.size():
			if _occ[k] == enemy_id:
				_occ[k] = 0
	es.slot[enemy_index] = -1


## Enemy id in the slot, or 0 (also for an index outside the table).
func occupant(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= _occ.size():
		return 0
	return _occ[slot_index]


func hash_into(h: StateHasher) -> void:
	h.put_ints(_occ)
