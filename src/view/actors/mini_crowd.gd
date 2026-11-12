class_name MiniCrowd
extends RefCounted
## All the MiniSwarms of a battle (one per mini type of the content: mote, shard) and the per-frame loop that feeds them from the
## enemy store (VARIETY_SPEC 5.4, 10.2). The ActorLayer owns one and calls `render` inside its frame; a mini has no pooled actor, no
## `Events` bookkeeping and no node: it is drawn while its store row is alive, interpolated between the previous and the current
## tick like the bodies (never extrapolated), turned to face its walk, hopping, with a blob shadow, and a transform pop for three
## frames when `enemy_damaged` names it. Nothing is allocated after `setup`.

const SHADOW_R: float = 0.32

var _swarm_of: Array[MiniSwarm] = []  ## by type index; null where the type is not a mini
var _pop: PackedByteArray = PackedByteArray()  ## per store index: frames of pop left
var _t: float = 0.0
var _drawn: int = 0


func setup(parent: Node3D, content: ContentSet, bounds: AABB, look: int, tier: int) -> void:
	_swarm_of.clear()
	for k: int in content.enemies.size():
		var def: EnemyDef = content.enemies[k]
		var swarm: MiniSwarm = null
		if def.is_mini():
			swarm = MiniSwarm.new()
			var cap: int = def.alive_cap if def.alive_cap > 0 else maxi(content.mission.swarm_cap, 1)
			swarm.setup(parent, k, Ids.ENEMIES[k], cap, bounds, look, tier)
		_swarm_of.append(swarm)


## Sizes the pop table for a store (called when the layer binds a sim).
func bind(st: EnemyStore) -> void:
	_pop.resize(st.capacity)
	_pop.fill(0)
	_t = 0.0


func clear() -> void:
	_pop.fill(0)
	_drawn = 0
	for swarm: MiniSwarm in _swarm_of:
		if swarm != null:
			swarm.clear()


func apply_look(look: int, tier: int, contrast: bool) -> void:
	for swarm: MiniSwarm in _swarm_of:
		if swarm != null:
			swarm.apply_look(look, tier, contrast)


## True when `type_index` is a mini type this crowd draws.
func is_mini(type_index: int) -> bool:
	return type_index >= 0 and type_index < _swarm_of.size() and _swarm_of[type_index] != null


func swarm_for(type_index: int) -> MiniSwarm:
	if is_mini(type_index):
		return _swarm_of[type_index]
	return null


## Minis drawn in the last frame, every type together.
func drawn_count() -> int:
	return _drawn


## A mini was hit: its transform pops for the next three frames.
func hit(store_index: int) -> void:
	if store_index >= 0 and store_index < _pop.size():
		_pop[store_index] = MiniSwarm.POP_FRAMES


## One frame: every living mini of the store into its swarm.
func render(st: EnemyStore, alpha: float, delta: float, decals: ActorDecals) -> void:
	_t += delta
	for swarm: MiniSwarm in _swarm_of:
		if swarm != null:
			swarm.begin_frame()
	_drawn = 0
	for i: int in st.high_water:
		if st.alive[i] == 0:
			continue
		var kind: int = st.type[i]
		if not is_mini(kind):
			continue
		var a: float = alpha
		var jump_x: float = st.x[i] - st.prev_x[i]
		var jump_z: float = st.z[i] - st.prev_z[i]
		if jump_x * jump_x + jump_z * jump_z > ActorLayer.TELEPORT_M * ActorLayer.TELEPORT_M:
			a = 1.0
		var px: float = lerpf(st.prev_x[i], st.x[i], a)
		var pz: float = lerpf(st.prev_z[i], st.z[i], a)
		var yaw: float = atan2(-st.face_x[i], -st.face_z[i])
		var phase: float = 0.0 if st.stun_ticks[i] > 0 else _t * MiniSwarm.HOP_RATE + float(st.id[i]) * 0.83
		var pop: int = 0
		if i < _pop.size():
			pop = _pop[i]
			if pop > 0:
				_pop[i] = pop - 1
		var swarm_of_kind: MiniSwarm = _swarm_of[kind]
		if swarm_of_kind.add(px, pz, yaw, phase, pop):
			_drawn += 1
			decals.add_shadow(px, pz, SHADOW_R)
	for swarm: MiniSwarm in _swarm_of:
		if swarm != null:
			swarm.end_frame()
