class_name NavTestUtil
extends RefCounted
## Shared helpers for the sim_nav tests. Not a suite (the name does not start with test_).
## `advance` runs only the two W1-A systems, so these tests do not depend on the other Wave 1 systems.


## A world on the frozen baseline content.
static func world(run_seed: int = 1) -> SimWorld:
	return TestContent.world(run_seed)


static func world_with(content: ContentSet, run_seed: int = 1) -> SimWorld:
	return SimWorld.new(SimConfig.create(content, run_seed))


## One tick of the nav systems: tick counter, SpawnSystem.step, MovementSystem.step.
static func advance(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick
	SpawnSystem.step(w)
	MovementSystem.step(w)


static func advance_n(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		advance(w)


## Emulates the tick in which the phase system starts a wave: enters SPAWNING, calls begin_wave, then runs the
## systems of that tick. Returns the tick (wave-relative tick 0).
static func start_wave(w: SimWorld, wave_index: int) -> int:
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = wave_index
	w.tick += 1
	w.events.current_tick = w.tick
	SpawnSystem.begin_wave(w, wave_index)
	SpawnSystem.step(w)
	MovementSystem.step(w)
	return w.tick


static func group(enemy_index: int, count: int, start_tick: int, interval_ticks: int, region: StringName) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = enemy_index
	g.count = count
	g.start_tick = start_tick
	g.interval_ticks = interval_ticks
	g.region_id = region
	return g


## Replaces the groups of wave `wave_index` (1-based) in a content set.
static func set_groups(content: ContentSet, wave_index: int, groups: Array[SpawnGroupDef]) -> void:
	content.waves[wave_index - 1].groups = groups


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func count_events(w: SimWorld, kind: int) -> int:
	return events_of(w, kind).size()


static func kill_all(w: SimWorld) -> void:
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1:
			w.kill_enemy(i, DamageSource.Id.WARDEN)


## Store index of an enemy id (-1 if dead).
static func index_of(w: SimWorld, enemy_id: int) -> int:
	return w.enemies.index_of(enemy_id)


## Fills the world with `n` mixed enemies spread along both spawn edges (types cycle skitter x3, hollow, rusher, ...;
## exactly one hulk when n >= 40). Returns nothing; ids are 1..n in creation order.
static func fill_mixed(w: SimWorld, n: int) -> void:
	var pattern: Array[int] = [
		Ids.EN_SKITTER, Ids.EN_SKITTER, Ids.EN_RUSHER, Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_SKITTER, Ids.EN_RUSHER
	]
	for k: int in n:
		var type_index: int = pattern[k % pattern.size()]
		if n >= 40 and k == n - 1:
			type_index = Ids.EN_HULK
		var t: float = fposmod(float(k) * 0.618034, 1.0)
		var x: float
		var z: float
		if k % 3 == 2:
			x = -1.0 + 11.0 * t
			z = -16.8
		else:
			x = 10.8
			z = -8.0 + 17.0 * t
		w.spawn_enemy(type_index, x, z)
