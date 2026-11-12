class_name EnemyPool
extends RefCounted
## Every pooled enemy view, allocated once in `setup` (ARCH 8: skitter 50, hollow warden 24, rusher 32, siege hulk 2).
## Maps enemy id to its actor. When a kind is exhausted the OLDEST visual of that kind is recycled; the sim is never
## affected (ARCH 13).

const SIZES: Array[int] = [50, 24, 32, 2]

var by_id: Dictionary[int, EnemyActor] = {}
var dying: Array[EnemyActor] = []

var _kinds: Array[KindPool] = []


class KindPool:
	extends RefCounted
	var free: Array[EnemyActor] = []
	var used: Array[EnemyActor] = []  ## oldest first


func setup(parent: Node3D, content: ContentSet, look: int = -1, tier: int = VisualQuality.Tier.HIGH) -> void:
	var use_look: int = LookDevStyle.current() if look < 0 else look
	for k: int in SIZES.size():
		var kp: KindPool = KindPool.new()
		var def: EnemyDef = content.enemies[k]
		var mesh_res: ArrayMesh = ActorMeshes.enemy_look(Ids.ENEMIES[k], use_look)
		for n: int in SIZES[k]:
			var actor: EnemyActor = EnemyActor.new()
			actor.setup(parent, k, mesh_res, "%s_%02d" % [String(Ids.ENEMIES[k]), n])
			actor.apply_look(use_look, tier, mesh_res)
			actor.shadow_radius = def.radius * 1.55
			actor.hit_height = def.visual_height_m * 0.55
			actor.bar_height = def.visual_height_m + 0.3
			kp.free.append(actor)
		_kinds.append(kp)


## Takes an actor of `kind` for `enemy_id`; recycles the oldest of that kind when none is free.
func acquire(kind: int, enemy_id: int, x: float, z: float, yaw: float) -> EnemyActor:
	var kp: KindPool = _kinds[kind]
	var actor: EnemyActor
	if kp.free.is_empty():
		var oldest: EnemyActor = kp.used.pop_front()
		by_id.erase(oldest.enemy_id)
		dying.erase(oldest)
		oldest.release()
		actor = oldest
	else:
		actor = kp.free.pop_back()
	actor.acquire(enemy_id, x, z, yaw)
	kp.used.append(actor)
	by_id[enemy_id] = actor
	return actor


## Releases the actor of `enemy_id` back to its pool. False when the id is unknown.
func release_id(enemy_id: int) -> bool:
	if not by_id.has(enemy_id):
		return false
	var actor: EnemyActor = by_id[enemy_id]
	by_id.erase(enemy_id)
	_give_back(actor)
	return true


## Keeps the actor (still visible, no longer addressable by id) while it plays its collapse.
func begin_dying(enemy_id: int) -> bool:
	if not by_id.has(enemy_id):
		return false
	var actor: EnemyActor = by_id[enemy_id]
	by_id.erase(enemy_id)
	actor.begin_dying()
	dying.append(actor)
	return true


## Advances the collapses and releases the finished ones.
func update_dying(delta: float) -> void:
	var i: int = dying.size() - 1
	while i >= 0:
		var actor: EnemyActor = dying[i]
		if actor.update_dying(delta):
			dying.remove_at(i)
			_give_back(actor)
		i -= 1


func release_all() -> void:
	by_id.clear()
	dying.clear()
	for kp: KindPool in _kinds:
		while not kp.used.is_empty():
			var actor: EnemyActor = kp.used.pop_back()
			actor.release()
			kp.free.append(actor)


## Dresses every pooled view (free ones included) for a look and quality tier: one shared mesh per kind, shared materials.
func set_look(look: int, tier: int) -> void:
	for k: int in _kinds.size():
		var mesh_res: ArrayMesh = ActorMeshes.enemy_look(Ids.ENEMIES[k], look)
		for actor: EnemyActor in _kinds[k].free:
			actor.apply_look(look, tier, mesh_res)
		for actor: EnemyActor in _kinds[k].used:
			actor.apply_look(look, tier, mesh_res)


## High Contrast look for every pooled view, free ones included (they carry it on into their next life).
func set_contrast(on: bool) -> void:
	for kp: KindPool in _kinds:
		for actor: EnemyActor in kp.free:
			actor.set_contrast(on)
		for actor: EnemyActor in kp.used:
			actor.set_contrast(on)


## Visible (acquired) actors, dying ones included.
func visible_count() -> int:
	var n: int = 0
	for kp: KindPool in _kinds:
		n += kp.used.size()
	return n


func has_free(kind: int) -> bool:
	var kp: KindPool = _kinds[kind]
	return not kp.free.is_empty()


func free_count(kind: int) -> int:
	var kp: KindPool = _kinds[kind]
	return kp.free.size()


func capacity(kind: int) -> int:
	var kp: KindPool = _kinds[kind]
	return kp.free.size() + kp.used.size()


func _give_back(actor: EnemyActor) -> void:
	var kp: KindPool = _kinds[actor.kind]
	kp.used.erase(actor)
	actor.release()
	kp.free.append(actor)
