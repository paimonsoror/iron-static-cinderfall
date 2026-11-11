class_name ActorLayer
extends Node3D
## Enemies, the Warden and the turrets (ARCH 8). One pooled Node3D per enemy (EnemyPool, allocated once in `setup`,
## no allocation afterwards), interpolated between prev and current sim positions by `alpha` (never extrapolated),
## facing from the sim, procedural motion per archetype, hit flash by material swap, blob shadows and world health
## bars as transform-only MultiMeshes. Reads the sim; every change of the actor set comes from `Events`
## (`enemy_spawned`, `enemy_killed`, `enemy_damaged`) with the store as the safety net.

## A heavy footfall (Siege Hulk): world position of the feet and a weight (1 = hulk). VfxLayer turns it into dust.
signal footfall(world_pos: Vector3, weight: float)

var warden: WardenView
var turrets: Array[TurretView] = []

var _sim: SimWorld
var _pool: EnemyPool
var _decals: ActorDecals
var _quality: int = VisualQuality.Tier.HIGH
var _high_contrast: bool = false  ## set by set_high_contrast; W2-E applies it to optics and rims
var _frame: int = 0


func setup(content: ContentSet) -> void:
	_pool = EnemyPool.new()
	_pool.setup(self, content)
	_decals = ActorDecals.new()
	_decals.setup(self, content.arena)
	warden = WardenView.new()
	warden.setup()
	add_child(warden)
	for p: int in content.arena.turret_pads.size():
		var t: TurretView = TurretView.new()
		t.setup(p)
		add_child(t)
		turrets.append(t)


## Resets the pools, adopts every enemy already alive in the store and starts listening to Events.
func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	var st: EnemyStore = sim.enemies
	for i: int in st.high_water:
		if st.alive[i] == 1:
			_adopt(i)
	warden.bind(sim)
	for t: TurretView in turrets:
		t.bind(sim)
	render(1.0, 0.0)


## Hides everything and stops reading the sim.
func unbind() -> void:
	if Events.enemy_spawned.is_connected(_on_enemy_spawned):
		Events.enemy_spawned.disconnect(_on_enemy_spawned)
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	if Events.enemy_damaged.is_connected(_on_enemy_damaged):
		Events.enemy_damaged.disconnect(_on_enemy_damaged)
	_sim = null
	if _pool != null:
		_pool.release_all()
		_decals.clear()
		warden.unbind()
		for t: TurretView in turrets:
			t.unbind()


func _exit_tree() -> void:
	unbind()


func render(alpha: float, delta: float) -> void:
	if _sim == null:
		return
	var a: float = clampf(alpha, 0.0, 1.0)
	_frame += 1
	var animate_all: bool = _quality != VisualQuality.Tier.LOW
	_decals.begin_frame()
	var st: EnemyStore = _sim.enemies
	var seen: int = 0
	for i: int in st.high_water:
		if st.alive[i] == 0:
			continue
		var eid: int = st.id[i]
		if not _pool.by_id.has(eid):
			# an event was missed: the store is the truth. A full pool is never raided here (that would thrash).
			if not _pool.has_free(st.type[i]):
				continue
			_adopt(i)
		var actor: EnemyActor = _pool.by_id[eid]
		seen += 1
		var px: float = lerpf(st.prev_x[i], st.x[i], a)
		var pz: float = lerpf(st.prev_z[i], st.z[i], a)
		var mode: int = ActorMotion.Mode.MOVE
		if st.stun_ticks[i] > 0:
			mode = ActorMotion.Mode.STUN
		elif st.state[i] == EnemyStore.ST_ATTACKING:
			mode = ActorMotion.Mode.ATTACK
		# LOW tier re-poses each mesh every other frame (positions still move every frame)
		var animate: bool = animate_all or (eid + _frame) % 2 == 0
		if actor.update(delta, px, pz, st.face_x[i], st.face_z[i], mode, animate):
			footfall.emit(Vector3(px, 0.0, pz), 1.0)
		_decals.add_shadow(px, pz, actor.shadow_radius)
		if actor.kind == Ids.EN_HOLLOW and st.hp[i] < st.max_hp[i] - 0.001:
			var frac: float = st.hp[i] / maxf(st.max_hp[i], 0.001)
			_decals.add_bar(Vector3(px, actor.bar_height, pz), frac)
	if seen != _pool.by_id.size():
		_release_stale()
	_pool.update_dying(delta)
	for d: EnemyActor in _pool.dying:
		var k: float = 1.0 - d.dying_progress() * 0.6
		_decals.add_shadow(d.root.position.x, d.root.position.z, d.shadow_radius * k)
	_render_friends(a, delta)
	_decals.end_frame()


func set_quality(tier: int) -> void:
	_quality = VisualQuality.from_setting(tier)


func quality() -> int:
	return _quality


## High-contrast setting (GDD 10.3): brighter enemy optics and a rim. Coordinator stub so that Game can wire the
## setting in Wave 2; the body is W2-E's.  # TODO(W2-E)
func set_high_contrast(on: bool) -> void:
	_high_contrast = on


## World position of a live enemy's feet, or Vector3.INF if unknown.
func enemy_world_position(enemy_id: int) -> Vector3:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		return actor.world_position()
	return Vector3.INF


## World position of a good hit point (torso) of a live enemy, or Vector3.INF if unknown.
func enemy_hit_position(enemy_id: int) -> Vector3:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		return actor.world_position() + Vector3(0.0, actor.hit_height, 0.0)
	return Vector3.INF


func warden_muzzle_position() -> Vector3:
	return warden.muzzle_position()


## Muzzle of a deployed turret, or Vector3.INF when the pad is empty.
func turret_muzzle_position(pad: int) -> Vector3:
	if pad < 0 or pad >= turrets.size() or not turrets[pad].is_deployed():
		return Vector3.INF
	return turrets[pad].muzzle_position()


## Visible enemy views (dying ones included).
func visible_enemy_count() -> int:
	if _pool == null:
		return 0
	return _pool.visible_count()


func enemy_pool() -> EnemyPool:
	return _pool


func decals() -> ActorDecals:
	return _decals


func is_flashing(enemy_id: int) -> bool:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		return actor.is_flashing()
	return false


func _render_friends(a: float, delta: float) -> void:
	warden.render(a, delta)
	_decals.add_shadow(warden.position.x, warden.position.z, 0.95)
	for t: TurretView in turrets:
		t.render(a, delta)
		if t.is_deployed():
			_decals.add_shadow(t.position.x, t.position.z, 0.5 + 0.4 * t.deploy_progress())


func _adopt(store_index: int) -> void:
	var st: EnemyStore = _sim.enemies
	var yaw: float = atan2(-st.face_x[store_index], -st.face_z[store_index])
	var _actor: EnemyActor = _pool.acquire(
		st.type[store_index], st.id[store_index], st.x[store_index], st.z[store_index], yaw
	)


## Releases views whose enemy is no longer in the store (a missed `enemy_killed`).
func _release_stale() -> void:
	var st: EnemyStore = _sim.enemies
	for k: int in _pool.by_id.keys():
		if st.index_of(k) < 0:
			var _gone: bool = _pool.release_id(k)


func _on_enemy_spawned(enemy_id: int, kind: StringName) -> void:
	if _sim == null or Ids.enemy_index(kind) < 0 or _pool.by_id.has(enemy_id):
		return
	var i: int = _sim.enemies.index_of(enemy_id)
	if i >= 0:
		_adopt(i)


func _on_enemy_killed(enemy_id: int, _source: int) -> void:
	if _pool == null or not _pool.by_id.has(enemy_id):
		return
	var actor: EnemyActor = _pool.by_id[enemy_id]
	if actor.kind == Ids.EN_HULK:
		var _started: bool = _pool.begin_dying(enemy_id)
	else:
		var _released: bool = _pool.release_id(enemy_id)


func _on_enemy_damaged(enemy_id: int, _amount: float, _source: int) -> void:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		actor.flash()
