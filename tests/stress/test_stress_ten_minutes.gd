extends GdUnitTestSuite
## Stress (TEST_PLAN "Stress"; acceptance A06): ten simulated minutes (36,000 ticks) with the arena held at the cap
## of 50 and enemies spawning and dying all the time, on the shipped enemy numbers. The core is invulnerable and the
## waves are floods (HarnessKit.stress_content), so nothing ends the run early. One run in before(); the tests read it.

const TICKS: int = 36000
const HALF: int = 18000
const THREE_QUARTERS: int = 27000  # 75% of the ticks

var content: ContentSet
var world: SimWorld
var checker: HarnessChecker

var non_finite: int = 0
var out_of_bounds: int = 0
var high_water_max: int = 0
var ticks_at_cap: int = 0
var ticks_near_cap: int = 0
var stuck_events: int = 0
var stuck_violations: PackedStringArray = PackedStringArray()
var step_usec: int = 0
var slowest_usec: int = 0
var killed: int = 0
var spawned: int = 0
var max_pending: int = 0


## Progress book-keeping for one enemy: the path distance when it last made real progress, and when.
class Progress:
	extends RefCounted
	var ref_dist: float = 0.0
	var ref_tick: int = 0


func before() -> void:
	content = HarnessKit.stress_content()
	var cfg: SimConfig = HarnessKit.config(content, 11)
	cfg.debug_invulnerable_core = true
	world = SimWorld.new(cfg)
	checker = HarnessChecker.new(world)
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.NONE)
	var cap: int = content.mission.enemy_cap
	var window: int = 2 * content.mission.stuck_ticks
	var min_progress: float = content.mission.stuck_min_progress_m
	var arena: ArenaDef = content.arena
	var seen: Dictionary[int, Progress] = {}
	while world.tick < TICKS and not world.is_over():
		bot.act(world)
		var t0: int = Time.get_ticks_usec()
		world.step()
		var dt: int = Time.get_ticks_usec() - t0
		step_usec += dt
		slowest_usec = maxi(slowest_usec, dt)
		var events: Array[SimEvent] = world.events.drain()
		for e: SimEvent in events:
			if e.kind == SimEventKind.Id.ENEMY_STUCK:
				stuck_events += 1
				if seen.has(e.a):
					seen[e.a].ref_tick = world.tick  # the sim noticed and is recovering it
			elif e.kind == SimEventKind.Id.ENEMY_KILLED:
				killed += 1
				seen.erase(e.a)
			elif e.kind == SimEventKind.Id.ENEMY_SPAWNED:
				spawned += 1
		checker.after_step(world, events)
		_watch_enemies(world, seen, window, min_progress, arena)
		var alive: int = world.alive_count()
		ticks_at_cap += 1 if alive >= cap else 0
		ticks_near_cap += 1 if alive >= cap - 5 else 0
		max_pending = maxi(max_pending, SpawnSystem.pending_count(world))
		high_water_max = maxi(high_water_max, world.enemies.high_water)
	checker.finish(world, bot.commands_submitted)


func _watch_enemies(w: SimWorld, seen: Dictionary[int, Progress], window: int, min_progress: float, arena: ArenaDef) -> void:
	var store: EnemyStore = w.enemies
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if not (is_finite(store.x[i]) and is_finite(store.z[i])):
			non_finite += 1
			continue
		if store.x[i] < arena.min_x - 3.0 or store.x[i] > arena.max_x + 3.0 or store.z[i] < arena.min_z - 3.0 or store.z[i] > arena.max_z + 3.0:
			out_of_bounds += 1
		var enemy_id: int = store.id[i]
		if not seen.has(enemy_id):
			var p: Progress = Progress.new()
			p.ref_dist = store.path_dist[i]
			p.ref_tick = w.tick
			seen[enemy_id] = p
		var prog: Progress = seen[enemy_id]
		if store.state[i] == EnemyStore.ST_ATTACKING:
			prog.ref_dist = 0.0
			prog.ref_tick = w.tick
		elif store.stun_ticks[i] > 0 or prog.ref_dist - store.path_dist[i] >= min_progress:
			prog.ref_dist = store.path_dist[i]
			prog.ref_tick = w.tick
		elif w.tick - prog.ref_tick > window and stuck_violations.size() < 10:
			stuck_violations.append("t%d: enemy %d (state %d) made no progress for %d ticks without ENEMY_STUCK" % [w.tick, enemy_id, store.state[i], w.tick - prog.ref_tick])
			prog.ref_tick = w.tick


func test_it_ran_the_whole_ten_minutes() -> void:
	assert_int(world.tick).is_equal(TICKS)
	assert_bool(world.is_over()).is_false()
	assert_float(float(world.tick) / float(SimWorld.TICK_RATE)).is_equal(600.0)


func test_the_arena_was_held_at_the_cap_with_a_queue_behind_it() -> void:
	assert_int(ticks_at_cap).is_greater(HALF)  # 50 alive for most of the ten minutes
	assert_int(ticks_near_cap).is_greater(THREE_QUARTERS)
	assert_int(max_pending).is_greater(10)  # spawns waited in the queue
	assert_int(world.stats.max_pending).is_equal(max_pending)


func test_enemies_kept_spawning_and_dying() -> void:
	assert_int(spawned).is_greater(300)
	assert_int(killed).is_greater(200)
	assert_int(world.next_enemy_id - 1).is_equal(spawned)  # every id handed out is an ENEMY_SPAWNED event


func test_no_position_is_nan_or_infinite_or_outside_the_yard() -> void:
	assert_int(non_finite).is_equal(0)
	assert_int(out_of_bounds).is_equal(0)


func test_the_store_never_outgrows_its_capacity() -> void:
	assert_int(high_water_max).is_less_equal(world.enemies.capacity)
	assert_int(high_water_max).is_less_equal(content.mission.enemy_cap + 8)


func test_nobody_stays_stuck_without_the_sim_noticing() -> void:
	assert_str("\n".join(stuck_violations)).is_empty()


func test_the_invariant_checker_found_nothing() -> void:
	assert_str("\n".join(checker.violations)).is_empty()


func test_the_average_tick_costs_under_one_millisecond() -> void:
	var avg_ms: float = float(step_usec) / 1000.0 / float(world.tick)
	print("STRESS avg step %.3f ms, slowest %.2f ms, %d ticks, spawned %d, killed %d, stuck events %d, queue max %d" % [avg_ms, float(slowest_usec) / 1000.0, world.tick, spawned, killed, stuck_events, max_pending])
	assert_float(avg_ms).is_less(1.0)
