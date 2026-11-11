class_name EnemyStore
extends RefCounted
## Packed arrays of enemy state (ARCH 6.4). Index = store slot; `id` is the stable enemy id.

const ST_MOVING: int = 0
const ST_SEEK_SLOT: int = 1
const ST_ATTACKING: int = 2

var capacity: int  ## enemy_cap + 8
var high_water: int = 0  ## iterate indices 0 .. high_water-1 and test alive[i]
var alive: PackedByteArray = PackedByteArray()
var id: PackedInt32Array = PackedInt32Array()  ## stable id, 0 = empty
var type: PackedByteArray = PackedByteArray()  ## Ids.EN_*
var x: PackedFloat64Array = PackedFloat64Array()
var z: PackedFloat64Array = PackedFloat64Array()
var prev_x: PackedFloat64Array = PackedFloat64Array()  ## position at the previous tick (interpolation)
var prev_z: PackedFloat64Array = PackedFloat64Array()
var face_x: PackedFloat64Array = PackedFloat64Array()  ## unit facing vector
var face_z: PackedFloat64Array = PackedFloat64Array()
var hp: PackedFloat64Array = PackedFloat64Array()
var max_hp: PackedFloat64Array = PackedFloat64Array()
var state: PackedByteArray = PackedByteArray()
var slot: PackedInt32Array = PackedInt32Array()  ## attack slot index or -1
var stun_ticks: PackedInt32Array = PackedInt32Array()  ## > 0 = stunned (no move, no attack, attack timer frozen)
var stun_immune_ticks: PackedInt32Array = PackedInt32Array()
var attack_cd: PackedInt32Array = PackedInt32Array()  ## ticks until the next core hit while ST_ATTACKING
var path_dist: PackedFloat64Array = PackedFloat64Array()  ## meters still to travel to the core ring (for ETA)
var spawn_tick: PackedInt32Array = PackedInt32Array()


func _init(cap: int) -> void:
	capacity = cap
	alive.resize(cap)
	id.resize(cap)
	type.resize(cap)
	x.resize(cap)
	z.resize(cap)
	prev_x.resize(cap)
	prev_z.resize(cap)
	face_x.resize(cap)
	face_z.resize(cap)
	hp.resize(cap)
	max_hp.resize(cap)
	state.resize(cap)
	slot.resize(cap)
	stun_ticks.resize(cap)
	stun_immune_ticks.resize(cap)
	attack_cd.resize(cap)
	path_dist.resize(cap)
	spawn_tick.resize(cap)
	for i: int in cap:
		slot[i] = -1


## Lowest free index with every field reset, or -1 when full.
func alloc() -> int:
	for i: int in capacity:
		if alive[i] == 0:
			_reset(i)
			alive[i] = 1
			if i + 1 > high_water:
				high_water = i + 1
			return i
	return -1


func free_index(i: int) -> void:
	if i < 0 or i >= capacity:
		return
	_reset(i)


## Store index of a live enemy id, or -1.
func index_of(enemy_id: int) -> int:
	if enemy_id <= 0:
		return -1
	for i: int in high_water:
		if alive[i] == 1 and id[i] == enemy_id:
			return i
	return -1


func alive_count() -> int:
	var n: int = 0
	for i: int in high_water:
		n += alive[i]
	return n


func hash_into(h: StateHasher) -> void:
	h.put_int(capacity)
	h.put_int(high_water)
	h.put_bytes(alive)
	h.put_ints(id)
	h.put_bytes(type)
	h.put_floats(x)
	h.put_floats(z)
	h.put_floats(prev_x)
	h.put_floats(prev_z)
	h.put_floats(face_x)
	h.put_floats(face_z)
	h.put_floats(hp)
	h.put_floats(max_hp)
	h.put_bytes(state)
	h.put_ints(slot)
	h.put_ints(stun_ticks)
	h.put_ints(stun_immune_ticks)
	h.put_ints(attack_cd)
	h.put_floats(path_dist)
	h.put_ints(spawn_tick)


func _reset(i: int) -> void:
	alive[i] = 0
	id[i] = 0
	type[i] = 0
	x[i] = 0.0
	z[i] = 0.0
	prev_x[i] = 0.0
	prev_z[i] = 0.0
	face_x[i] = 0.0
	face_z[i] = 0.0
	hp[i] = 0.0
	max_hp[i] = 0.0
	state[i] = ST_MOVING
	slot[i] = -1
	stun_ticks[i] = 0
	stun_immune_ticks[i] = 0
	attack_cd[i] = 0
	path_dist[i] = 0.0
	spawn_tick[i] = 0
