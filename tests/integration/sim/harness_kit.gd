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


## The debug build of the full-run tests (WORK_PLAN card V5-A): every Archive unlock (the `--unlock=all` of the game) and
## `debug_damage_mult`, so a bot wins the 15 waves fast and for certain whatever the balance of the day is.
static func debug_config(content: ContentSet, run_seed: int = 1, damage_mult: float = 4.0) -> SimConfig:
	var cfg: SimConfig = SimHarness.config_for(content, run_seed, damage_mult)
	var ids: PackedStringArray = PackedStringArray()
	for u: UnlockDef in content.unlocks:
		ids.append(String(u.id))
	ids.sort()
	cfg.unlocked = ids
	return cfg


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


## Turns the run plan of `w` (a world on the shipped data, before its first wave) into floods that out-spawn the
## Warden for far longer than ten minutes: every option of every wave sends all the slice types at once, bodied and
## minis, so the bodied cap of 50 stays full with the queue behind it and the swarm of minis keeps arriving. Pair it
## with SimConfig.debug_invulnerable_core so the run cannot end. (A debug write of the plan: the real one is built
## from the seed; the stress test wants a fixed, heavy spawn list on the shipped enemy numbers.)
## The bodies arrive only a little faster than they die. SpawnSystem walks its whole pending queue every tick (an entry
## blocked by one cap does not hold up the others), so a queue of thousands, which no real wave has, costs
## milliseconds per tick: a first flood with 3,000 waiting entries measured 4.9 ms a tick, this one stays in the
## hundreds.
static func flood_plan(w: SimWorld) -> void:
	for wave_number: int in range(1, w.plan.wave_count() + 1):
		for option: RouteOption in w.plan.wave(wave_number).options:
			var groups: Array[SpawnGroupDef] = [
				group(Ids.EN_SKITTER, 60, 0, 15, &"right"),  # fills the yard to the cap in the first seconds
				group(Ids.EN_SKITTER, 600, 900, 60, &"right"),  # then more than the Warden can kill
				group(Ids.EN_HOLLOW, 300, 60, 120, &"upper_right"),
				group(Ids.EN_RUSHER, 180, 120, 200, &"right"),
				group(Ids.EN_BURSTER, 60, 90, 600, &"right"),
				group(Ids.EN_MOTE, 1800, 30, 20, &"upper_right"),
				group(Ids.EN_HULK, 1, 1200, 60, &"upper_right"),
			]
			option.groups = groups
			option.elites.clear()
