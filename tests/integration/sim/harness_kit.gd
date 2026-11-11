class_name HarnessKit
extends RefCounted
## Helpers for tests/integration/sim and tests/stress. Not a suite (the name does not start with test_).
## Whole-run tests use the SHIPPED data (res://data): they are the gate that the tuned game is winnable, losable
## and sound. The lab worlds use the frozen baseline (TestContent) so the rules they pin do not move with tuning.

## A spawn start so far away that a lab wave never produces an enemy.
const FAR_START_TICKS: int = 1000000
const TOUGH_HP: float = 1.0e9


## The shipped content, loaded and validated. A broken data file fails the calling test here.
static func shipped() -> ContentSet:
	var r: ContentLoadResult = ContentLoader.load_from_dir("res://data")
	assert(r.errors.is_empty(), "shipped data does not load: " + "; ".join(r.errors))
	var problems: PackedStringArray = ContentValidator.validate(r.content)
	assert(problems.is_empty(), "shipped data is invalid: " + "; ".join(problems))
	return r.content


static func config(content: ContentSet, run_seed: int = 1, damage_mult: float = 1.0) -> SimConfig:
	return SimHarness.config_for(content, run_seed, damage_mult)


## A world on the frozen baseline whose five waves never spawn anything, stepped into wave 1 (SPAWNING). Enemies
## in a lab are placed by the test.
static func lab_world(run_seed: int = 1) -> SimWorld:
	var content: ContentSet = TestContent.baseline()
	for wave: WaveDef in content.waves:
		var g: SpawnGroupDef = SpawnGroupDef.new()
		g.enemy_index = Ids.EN_SKITTER
		g.count = 1
		g.start_tick = FAR_START_TICKS
		g.interval_ticks = 60
		g.region_id = &"right"
		wave.groups = [g]
	var w: SimWorld = SimWorld.new(SimConfig.create(content, run_seed))
	for t: int in content.mission.prepare_ticks:
		w.step()
	w.events.drain()
	return w


## `n` enemies that cannot die, standing on the inner attack ring; returns their ids.
static func garrison(w: SimWorld, n: int, type_index: int = Ids.EN_SKITTER) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for k: int in n:
		var at: Vector2 = w.nav.slots.slot_position(k)
		var i: int = w.spawn_enemy(type_index, at.x, at.y)
		w.enemies.hp[i] = TOUGH_HP
		w.enemies.max_hp[i] = TOUGH_HP
		ids.append(w.enemies.id[i])
	return ids


static func attacking_count(w: SimWorld) -> int:
	var n: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.enemies.state[i] == EnemyStore.ST_ATTACKING:
			n += 1
	return n


static func count_of(events: Array[SimEvent], kind: int) -> int:
	var n: int = 0
	for e: SimEvent in events:
		if e.kind == kind:
			n += 1
	return n


static func first_of(events: Array[SimEvent], kind: int) -> SimEvent:
	for e: SimEvent in events:
		if e.kind == kind:
			return e
	return null


static func group(enemy_index: int, count: int, start_ticks: int, interval_ticks: int, region: StringName) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = enemy_index
	g.count = count
	g.start_tick = start_ticks
	g.interval_ticks = interval_ticks
	g.region_id = region
	return g


## The shipped content with five waves that out-spawn the Warden for far longer than ten minutes: every wave
## sends a flood of all the cheap types at once, so 50 stay alive with the queue behind them. Pair it with
## SimConfig.debug_invulnerable_core so the run cannot end.
static func stress_content() -> ContentSet:
	var c: ContentSet = shipped()
	for w: int in 5:
		var groups: Array[SpawnGroupDef] = [
			group(Ids.EN_SKITTER, 260, 0, 15, &"right"),
			group(Ids.EN_HOLLOW, 50, 60, 60, &"upper_right"),
			group(Ids.EN_RUSHER, 50, 120, 60, &"right"),
			group(Ids.EN_HULK, 1, 1200, 60, &"upper_right"),
		]
		c.waves[w].groups = groups
	return c
