class_name EnemyPool
extends RefCounted
## Every pooled enemy view, allocated once in `setup` (ARCH 8: skitter 50, hollow warden 24, rusher 32, siege hulk 2). The sizes are
## data-driven since V2-F (VARIETY_SPEC 13.6): a type that is not a mini gets `EnemyDef.alive_cap` actors (the legacy content has no
## type cap and keeps `SIZES`); a mini has none, it is drawn by a MiniSwarm. Maps enemy id to its actor. When a kind is exhausted
## the OLDEST visual of that kind is recycled; the sim is never affected (ARCH 13).

## The pool sizes of the four legacy types, used when the content sets no `alive_cap` (the legacy fixture).
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
	for k: int in content.enemies.size():
		var kp: KindPool = KindPool.new()
		var def: EnemyDef = content.enemies[k]
		var mesh_res: ArrayMesh = ActorMeshes.enemy_look(Ids.ENEMIES[k], use_look)
		for n: int in size_for(def, k):
			var actor: EnemyActor = EnemyActor.new()
			actor.setup(parent, k, mesh_res, "%s_%02d" % [String(Ids.ENEMIES[k]), n])
			actor.apply_look(use_look, tier, mesh_res)
			actor.shadow_radius = def.radius * 1.55
			actor.hit_height = def.visual_height_m * 0.55
			actor.bar_height = def.visual_height_m + 0.3
			kp.free.append(actor)
		_kinds.append(kp)


## How many views the type `kind` (its index in `Ids.ENEMIES`) gets: none for a mini, `alive_cap` when the data sets one, else the
## legacy size.
static func size_for(def: EnemyDef, kind: int) -> int:
	if def.is_mini():
		return 0
	if def.alive_cap > 0:
		return def.alive_cap
	return SIZES[kind] if kind < SIZES.size() else 0


## Takes an actor of `kind` for `enemy_id`; recycles the oldest of that kind when none is free. Null for a type that has no views
## (a mini, or a type the content does not have).
func acquire(kind: int, enemy_id: int, x: float, z: float, yaw: float) -> EnemyActor:
	if capacity(kind) == 0:
		return null
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
	if kind < 0 or kind >= _kinds.size():
		return false
	var kp: KindPool = _kinds[kind]
	return not kp.free.is_empty()


func free_count(kind: int) -> int:
	if kind < 0 or kind >= _kinds.size():
		return 0
	var kp: KindPool = _kinds[kind]
	return kp.free.size()


## Views of `kind` (0 for a mini or an unknown type).
func capacity(kind: int) -> int:
	if kind < 0 or kind >= _kinds.size():
		return 0
	var kp: KindPool = _kinds[kind]
	return kp.free.size() + kp.used.size()


## Views of every kind together (the pooled nodes).
func total_capacity() -> int:
	var n: int = 0
	for k: int in _kinds.size():
		n += capacity(k)
	return n


func _give_back(actor: EnemyActor) -> void:
	var kp: KindPool = _kinds[actor.kind]
	kp.used.erase(actor)
	actor.release()
	kp.free.append(actor)
