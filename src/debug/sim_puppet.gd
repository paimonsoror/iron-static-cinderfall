class_name SimPuppet
extends Node
## Builds a real SimWorld, then drives its stores and Events directly (ARCH 11): spawns N enemies of mixed
## types, walks them toward the core on straight lines, fires fake shots and kills, and keeps N alive. Lets
## the view be built and captured before the simulation systems exist. The puppet is the only writer here.

const TICK_DT: float = 1.0 / 60.0

var world: SimWorld
var _content: ContentSet
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hold: int = 50
var _acc: float = 0.0
var _goals: Dictionary = {}  ## enemy id -> Vector2 (x, z) of its attack slot
var _kinds: Dictionary = {}  ## enemy id -> type index
var _mix: Array[int] = [0, 0, 0, 1, 0, 2, 0, 0, 1, 2]


## count = how many enemies to hold alive. `boss_only` builds a single Siege Hulk with a few escorts.
func setup(content: ContentSet, count: int = 50, puppet_seed: int = 1, boss_only: bool = false) -> void:
	_content = content
	_hold = clampi(count, 1, content.mission.enemy_cap)
	_rng.seed = puppet_seed
	world = SimWorld.new(SimConfig.create(content, puppet_seed))
	world.config.debug_invulnerable_core = true
	if boss_only or _hold >= 40:
		_spawn(Ids.EN_HULK, 0.55)  # the boss is never killed by the puppet
	for i: int in _hold:
		if world.alive_count() >= _hold:
			break
		_spawn(_next_type(i), _rng.randf_range(0.05, 1.0))
	_flush_events()


## Advances the puppet by `delta` seconds in 60 Hz steps; returns the interpolation alpha for rendering.
func advance(delta: float) -> float:
	_acc += minf(delta, 0.1)
	while _acc >= TICK_DT:
		_acc -= TICK_DT
		_tick()
	return _acc / TICK_DT


func _tick() -> void:
	world.tick += 1
	world.events.current_tick = world.tick
	var st: EnemyStore = world.enemies
	var first_attacker: int = -1
	for i: int in st.high_water:
		if st.alive[i] == 0:
			continue
		st.prev_x[i] = st.x[i]
		st.prev_z[i] = st.z[i]
		if st.state[i] == EnemyStore.ST_ATTACKING:
			var killable: bool = st.type[i] != Ids.EN_HULK
			if killable and (first_attacker < 0 or st.id[i] < st.id[first_attacker]):
				first_attacker = i
			continue
		var goal: Vector2 = _goals.get(st.id[i], Vector2(world.content.arena.core_x, world.content.arena.core_z))
		var dx: float = goal.x - st.x[i]
		var dz: float = goal.y - st.z[i]
		var dist: float = sqrt(dx * dx + dz * dz)
		var step: float = world.content.enemies[st.type[i]].speed_mps * TICK_DT
		if dist <= maxf(step, 0.05):
			st.x[i] = goal.x
			st.z[i] = goal.y
			st.state[i] = EnemyStore.ST_ATTACKING
		else:
			st.x[i] += dx / dist * step
			st.z[i] += dz / dist * step
			st.face_x[i] = dx / dist
			st.face_z[i] = dz / dist
	if first_attacker >= 0 and world.tick % 24 == 0:
		_shoot_and_kill(first_attacker)
	while world.alive_count() < _hold:
		_spawn(_next_type(world.next_enemy_id), 0.0)
	_flush_events()


func _shoot_and_kill(i: int) -> void:
	var st: EnemyStore = world.enemies
	world.warden.aim_x = st.x[i]
	world.warden.aim_z = st.z[i]
	world.events.push(SimEventKind.Id.SHOT_FIRED, DamageSource.Id.WARDEN, st.id[i])
	world.kill_enemy(i, DamageSource.Id.WARDEN)


func _next_type(n: int) -> int:
	return _mix[n % _mix.size()]


## progress 0 = at the spawn region, 1 = at the attack slot.
func _spawn(type_index: int, progress: float) -> void:
	var arena: ArenaDef = _content.arena
	var region: SpawnRegionDef = arena.spawn_regions[_rng.randi() % arena.spawn_regions.size()]
	var t: float = _rng.randf()
	var sx: float = lerpf(region.x0, region.x1, t)
	var sz: float = lerpf(region.z0, region.z1, t)
	var goal: Vector2 = arena.slot_positions[_rng.randi() % arena.slot_positions.size()]
	var i: int = world.spawn_enemy(type_index, lerpf(sx, goal.x, progress), lerpf(sz, goal.y, progress))
	if i < 0:
		return
	_goals[world.enemies.id[i]] = goal
	_kinds[world.enemies.id[i]] = type_index
	if progress >= 0.999:
		world.enemies.state[i] = EnemyStore.ST_ATTACKING


## Drains the sim's events and re-emits the ones the view and HUD care about on the Events bus.
func _flush_events() -> void:
	for e: SimEvent in world.events.drain():
		match e.kind:
			SimEventKind.Id.ENEMY_SPAWNED:
				Events.enemy_spawned.emit(e.a, Ids.ENEMIES[e.b])
			SimEventKind.Id.BOSS_SPAWNED:
				Events.boss_spawned.emit(e.a, Ids.ENEMIES[e.b])
			SimEventKind.Id.SHOT_FIRED:
				Events.shot_fired.emit(e.a, e.b)
			SimEventKind.Id.ENEMY_KILLED:
				Events.enemy_killed.emit(e.a, e.b)
				var type_index: int = _kinds.get(e.a, 0)
				Events.enemy_died_at.emit(e.a, Ids.ENEMIES[type_index], e.f, e.g, _content.enemies[type_index].scrap)
				_goals.erase(e.a)
				_kinds.erase(e.a)
