class_name ActorLayer
extends Node3D
## Enemies, the Warden, the turrets and the salvage crate (ARCH 8). One pooled Node3D per bodied enemy (EnemyPool, allocated once in
## `setup`, sized by the data, no allocation afterwards), interpolated between prev and current sim positions by `alpha` (never
## extrapolated), facing from the sim, procedural motion per archetype, hit flash by material swap, blob shadows, world health bars
## and elite rings as transform-only MultiMeshes. The minis (mote, shard) are not pooled actors: one MiniSwarm MultiMesh per type is
## filled from the store every frame (`MiniCrowd`). Reads the sim; every change of the actor set comes from `Events`
## (`enemy_spawned`, `enemy_killed`, `enemy_damaged`, `elite_spawned`) with the store as the safety net.

## A heavy footfall (Siege Hulk): world position of the feet and a weight (1 = hulk). VfxLayer turns it into dust.
signal footfall(world_pos: Vector3, weight: float)

## An enemy that moved farther than this in ONE tick was forced to move (stuck recovery): it is drawn at its new place
## at once instead of sliding there. The fastest walker covers 0.06 m per tick.
const TELEPORT_M: float = 1.0
## The types that show a world health bar once damaged (elites show one always).
const MINI_HIT_HEIGHT: float = 0.2
const BAR_KINDS: Array[int] = [Ids.EN_HOLLOW, Ids.EN_SHIELDBEARER, Ids.EN_SPLITTER]

var warden: WardenView
var turrets: Array[TurretView] = []
var boss_marker: BossMarker
var crate: CrateView

var _sim: SimWorld
var _content: ContentSet
var _pool: EnemyPool
var _minis: MiniCrowd
var _decals: ActorDecals
var _quality: int = VisualQuality.Tier.HIGH
var _look: int = LookDevStyle.Look.CURRENT
var _high_contrast: bool = false
var _boss_id: int = 0
var _frame: int = 0


func setup(content: ContentSet) -> void:
	_content = content
	_look = LookDevStyle.current()
	_pool = EnemyPool.new()
	_pool.setup(self, content, _look, _quality)
	_decals = ActorDecals.new()
	_decals.setup(self, content.arena)
	var arena: ArenaDef = content.arena
	var bounds: AABB = AABB(
		Vector3(arena.min_x - 20.0, -2.0, arena.min_z - 20.0),
		Vector3(arena.max_x - arena.min_x + 40.0, 10.0, arena.max_z - arena.min_z + 40.0)
	)
	_minis = MiniCrowd.new()
	_minis.setup(self, content, bounds, _look, _quality)
	crate = CrateView.new()
	crate.setup(content)
	add_child(crate)
	warden = WardenView.new()
	warden.setup()
	warden.set_quality(_quality)
	add_child(warden)
	for p: int in content.arena.turret_pads.size():
		var t: TurretView = TurretView.new()
		t.setup(p)
		add_child(t)
		t.apply_look(_look, _quality)
		turrets.append(t)
	boss_marker = BossMarker.new()
	boss_marker.setup(content.arena.pitch_down_deg, content.arena.yaw_deg)
	add_child(boss_marker)
	if _high_contrast:
		_pool.set_contrast(true)


## Resets the pools, adopts every enemy already alive in the store and starts listening to Events.
func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.elite_spawned.connect(_on_elite_spawned)
	var st: EnemyStore = sim.enemies
	_minis.bind(st)
	for i: int in st.high_water:
		if st.alive[i] == 1:
			_adopt(i)
			if st.type[i] == Ids.EN_HULK:
				_boss_id = st.id[i]
	warden.bind(sim)
	for t: TurretView in turrets:
		t.bind(sim)
	crate.bind(sim)
	render(1.0, 0.0)


## Hides everything and stops reading the sim.
func unbind() -> void:
	if Events.enemy_spawned.is_connected(_on_enemy_spawned):
		Events.enemy_spawned.disconnect(_on_enemy_spawned)
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	if Events.enemy_damaged.is_connected(_on_enemy_damaged):
		Events.enemy_damaged.disconnect(_on_enemy_damaged)
	if Events.boss_spawned.is_connected(_on_boss_spawned):
		Events.boss_spawned.disconnect(_on_boss_spawned)
	if Events.elite_spawned.is_connected(_on_elite_spawned):
		Events.elite_spawned.disconnect(_on_elite_spawned)
	_sim = null
	_boss_id = 0
	if _pool != null:
		_pool.release_all()
		_minis.clear()
		crate.unbind()
		_decals.clear()
		boss_marker.track(Vector3.INF, 0.0)
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
		if st.alive[i] == 0 or _minis.is_mini(st.type[i]):
			continue
		var eid: int = st.id[i]
		if not _pool.by_id.has(eid):
			# an event was missed: the store is the truth. A full pool is never raided here (that would thrash).
			if not _pool.has_free(st.type[i]):
				continue
			_adopt(i)
		var actor: EnemyActor = _pool.by_id[eid]
		seen += 1
		var a_i: float = a
		var jump_x: float = st.x[i] - st.prev_x[i]
		var jump_z: float = st.z[i] - st.prev_z[i]
		if jump_x * jump_x + jump_z * jump_z > TELEPORT_M * TELEPORT_M:
			a_i = 1.0  # forced move: prev is still last tick's spot, so interpolating would slide across the yard
		var px: float = lerpf(st.prev_x[i], st.x[i], a_i)
		var pz: float = lerpf(st.prev_z[i], st.z[i], a_i)
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
		if actor.elite:
			_decals.add_ring(px, pz, actor.shadow_radius * 2.0)
		# VARIETY_SPEC 5.6 rule 6: a bar for elites and for damaged Hollow Wardens, shieldbearers and splitters; never for minis
		if actor.elite or (BAR_KINDS.has(actor.kind) and st.hp[i] < st.max_hp[i] - 0.001):
			_decals.add_bar(Vector3(px, actor.bar_height, pz), st.hp[i] / maxf(st.max_hp[i], 0.001))
	if seen != _pool.by_id.size():
		_release_stale()
	_minis.render(st, a, delta, _decals)
	_pool.update_dying(delta)
	for d: EnemyActor in _pool.dying:
		var k: float = 1.0 - d.dying_progress() * 0.6
		_decals.add_shadow(d.root.position.x, d.root.position.z, d.shadow_radius * k)
	_render_friends(a, delta)
	crate.render(delta)
	_render_boss_marker(delta)
	_decals.end_frame()


func set_quality(tier: int) -> void:
	_quality = VisualQuality.from_setting(tier)
	if warden != null:
		warden.set_quality(_quality)
	_dress_actors()


## Look of the Warden, the turrets and the enemies (LookDevStyle.Look; W3-C and W3-D). Also becomes the process-wide current look.
func set_look(look: int) -> void:
	LookDevStyle.set_current(look)
	_look = LookDevStyle.current()
	if warden != null:
		warden.set_look(_look)
	_dress_actors()


func quality() -> int:
	return _quality


## High-contrast setting (GDD 10.3): brighter enemy optics and rim lit plates (ActorContrast). Safe before `setup`.
func set_high_contrast(on: bool) -> void:
	_high_contrast = on
	if on:
		ActorContrast.rebuild()
	if _pool != null:
		_pool.set_contrast(on)
		_minis.apply_look(_look, _quality, on)


func is_high_contrast() -> bool:
	return _high_contrast


## World position of a live enemy's feet, or Vector3.INF if unknown. A mini has no view of its own: its position is the store's.
func enemy_world_position(enemy_id: int) -> Vector3:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		return actor.world_position()
	return _mini_position(enemy_id, 0.0)


## World position of a good hit point (torso) of a live enemy, or Vector3.INF if unknown.
func enemy_hit_position(enemy_id: int) -> Vector3:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		return actor.world_position() + Vector3(0.0, actor.hit_height, 0.0)
	return _mini_position(enemy_id, MINI_HIT_HEIGHT)


## True when this layer can draw bodies of the enemy type `type_index` (`Ids.EN_*`): a pool of views for a bodied type, a MiniSwarm
## for a mini. The debug puppet (`view_sandbox.gd`, `--scenario=chain` and `hold<N>+<M>`) asks this before it puts motes and bursters
## into the store; a type the content does not have, or a layer that is not set up, answers false.
func supports_enemy_type(type_index: int) -> bool:
	if _pool == null:
		return false
	return _minis.is_mini(type_index) or _pool.capacity(type_index) > 0


## The MiniSwarm that draws the mini type `type_index` (null for a bodied type).
func mini_swarm(type_index: int) -> MiniSwarm:
	return _minis.swarm_for(type_index)


## Minis drawn in the last frame.
func minis_drawn() -> int:
	return _minis.drawn_count()


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


## Dresses the pooled enemies and the turrets for the current look and tier (shared meshes and materials: nothing is created).
func _dress_actors() -> void:
	if _pool != null:
		_pool.set_look(_look, _quality)
		_minis.apply_look(_look, _quality, _high_contrast)
		crate.apply_look(_look, _quality)
	for t: TurretView in turrets:
		t.apply_look(_look, _quality)


func _render_friends(a: float, delta: float) -> void:
	warden.render(a, delta)
	_decals.add_shadow(warden.position.x, warden.position.z, 0.95)
	for t: TurretView in turrets:
		t.render(a, delta)
		if t.is_deployed():
			_decals.add_shadow(t.position.x, t.position.z, 0.5 + 0.4 * t.deploy_progress())


func _adopt(store_index: int) -> void:
	var st: EnemyStore = _sim.enemies
	if _minis.is_mini(st.type[store_index]):
		return  # drawn from the store by the MiniSwarm, never pooled
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


func _render_boss_marker(delta: float) -> void:
	var at: Vector3 = Vector3.INF
	if _boss_id != 0:
		at = enemy_world_position(_boss_id)
	boss_marker.track(at, delta)


func _on_boss_spawned(enemy_id: int, _kind: StringName) -> void:
	_boss_id = enemy_id


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
	if enemy_id == _boss_id:
		_boss_id = 0
	if actor.kind == Ids.EN_HULK:
		var _started: bool = _pool.begin_dying(enemy_id)
	else:
		var _released: bool = _pool.release_id(enemy_id)


func _on_enemy_damaged(enemy_id: int, _amount: float, _source: int) -> void:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		actor.flash()
	elif _sim != null:
		_minis.hit(_sim.enemies.index_of(enemy_id))  # -1 (not a mini, or gone) is ignored


## An elite: larger, a red ring on the ground and a health bar (VARIETY_SPEC 5.2). The affix mask is shown by behaviour and by
## the ground cues of the zone effects (V4-X), not by anything on the body.
func _on_elite_spawned(enemy_id: int, _kind: StringName, _affixes: int) -> void:
	if _pool != null and _pool.by_id.has(enemy_id):
		var actor: EnemyActor = _pool.by_id[enemy_id]
		actor.mark_elite(_content.run.elite_scale if _content.run != null else 1.25)


## The ground (or `height` above it) position of a mini from the store; INF for any other enemy id.
func _mini_position(enemy_id: int, height: float) -> Vector3:
	if _sim == null:
		return Vector3.INF
	var i: int = _sim.enemies.index_of(enemy_id)
	if i < 0 or not _minis.is_mini(_sim.enemies.type[i]):
		return Vector3.INF
	return Vector3(_sim.enemies.x[i], height, _sim.enemies.z[i])
