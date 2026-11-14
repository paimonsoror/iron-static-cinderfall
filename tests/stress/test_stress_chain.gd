extends GdUnitTestSuite
## Stress variant of the variety game (ARCH 13.2, VARIETY_SPEC 10; WORK_PLAN card V5-A): the yard held at BOTH caps, 50
## bodied enemies and 40 minis, with a blast every second, for five simulated minutes (18,000 ticks) on the shipped
## enemy numbers. Every bodied type of the 15-wave game is in the mix (wards, auras, tethers, standoff points and
## death blasts all run), the Warden fires all the time and the core cannot fall. The test keeps the population up by
## hand: whatever died is sent in again at the spawn edge on the same tick, so the caps stay full instead of following a
## wave's schedule. One run in before(); the tests read it.
##
## The limit is the one of test_stress_ten_minutes: 1.0 ms per tick on the desktop. It is a wall-clock benchmark: on a
## loaded machine run it again, never edit the budget.

const TICKS: int = 18000
const BLAST_PERIOD: int = 60  ## one blast a second
const BLAST_RADIUS_M: float = 3.0
const BLAST_DAMAGE: float = 60.0
const WARM_UP: int = 600  ## ticks until the yard is full; the cap counts start after it
## The bodied types of the game, in the order the top-up tries them (a type at its own alive cap is passed over).
const BODIED: PackedInt32Array = [
	Ids.EN_SKITTER, Ids.EN_HOLLOW, Ids.EN_RUSHER, Ids.EN_BURSTER, Ids.EN_SKITTER, Ids.EN_SPITTER, Ids.EN_SPLITTER,
	Ids.EN_SKITTER, Ids.EN_SHIELDBEARER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_BORER, Ids.EN_RUSHER, Ids.EN_SKITTER,
]

var content: ContentSet
var world: SimWorld
var step_usec: int = 0
var slowest_usec: int = 0
var ticks_bodied_at_cap: int = 0
var ticks_minis_near_cap: int = 0
var minis_max: int = 0
var bodied_max: int = 0
var blasts_made: int = 0
var blast_events: int = 0
var blast_hits: int = 0
var spawned: int = 0
var killed: int = 0
var non_finite: int = 0
var out_of_bounds: int = 0
var high_water_max: int = 0
var types_seen: Dictionary[int, bool] = {}
var _next_type: int = 0
var _next_place: int = 0


func before() -> void:
	content = HarnessKit.shipped()
	var cfg: SimConfig = HarnessKit.config(content, 23)
	cfg.debug_invulnerable_core = true
	world = SimWorld.new(cfg)
	_never_ending_wave(world)
	var bodied_cap: int = content.mission.enemy_cap
	var mini_cap: int = content.mission.swarm_cap
	var arena: ArenaDef = content.arena
	while world.tick < TICKS and not world.is_over():
		if GameState.is_combat(world.phase):
			_top_up(world, bodied_cap, mini_cap)
			if world.tick % BLAST_PERIOD == 0:
				_blast(world)
		var t0: int = Time.get_ticks_usec()
		world.step()
		var dt: int = Time.get_ticks_usec() - t0
		step_usec += dt
		slowest_usec = maxi(slowest_usec, dt)
		for e: SimEvent in world.events.drain():
			match e.kind:
				SimEventKind.Id.ENEMY_SPAWNED:
					spawned += 1
					types_seen[e.b] = true
				SimEventKind.Id.ENEMY_KILLED:
					killed += 1
				SimEventKind.Id.AREA_BLAST:
					blast_events += 1
		_watch(world, arena, bodied_cap, mini_cap)


## Every wave of the plan becomes one skitter that never arrives: the wave stays in SPAWNING and nothing ends it.
func _never_ending_wave(w: SimWorld) -> void:
	for wave_number: int in range(1, w.plan.wave_count() + 1):
		for option: RouteOption in w.plan.wave(wave_number).options:
			var groups: Array[SpawnGroupDef] = [HarnessKit.group(Ids.EN_SKITTER, 1, HarnessKit.FAR_START_TICKS, 60, &"right")]
			option.groups = groups
			option.elites.clear()
		w.plan.wave(wave_number).events.clear()


## Sends bodies in at the spawn edge until both caps are full (a cap, a type cap or a full store answers -1).
func _top_up(w: SimWorld, bodied_cap: int, mini_cap: int) -> void:
	var minis: int = _minis(w)
	var bodied: int = w.alive_count() - minis
	var tries: int = 0
	while bodied < bodied_cap and tries < BODIED.size():
		var type_index: int = BODIED[_next_type % BODIED.size()]
		_next_type += 1
		tries += 1
		if _send(w, type_index):
			bodied += 1
			tries = 0
	while minis < mini_cap and _send(w, Ids.EN_MOTE):
		minis += 1


func _send(w: SimWorld, type_index: int) -> bool:
	var region: SpawnRegionDef = w.content.arena.spawn_regions[_next_place % w.content.arena.spawn_regions.size()]
	var along: float = float((_next_place * 7) % 23) / 22.0
	_next_place += 1
	var x: float = lerpf(region.x0, region.x1, along)
	var z: float = lerpf(region.z0, region.z1, 1.0 - along)
	return BossEffects.send_now(w, type_index, x, z) >= 0


## A blast on the densest cluster of the yard (the place a chain would be).
func _blast(w: SimWorld) -> void:
	var arena: ArenaDef = w.content.arena
	var at: Vector2 = AreaDamage.densest_cluster(w, arena.core_x, arena.core_z, 0.0, 100.0, BLAST_RADIUS_M)
	blast_hits += AreaDamage.blast(w, at.x, at.y, BLAST_RADIUS_M, BLAST_DAMAGE, 0.5, DamageResolver.F_AREA, DamageSource.Id.HAZARD)
	blasts_made += 1


func _minis(w: SimWorld) -> int:
	var n: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.ext.has_flag(i, EnemyExtState.F_MINI):
			n += 1
	return n


func _watch(w: SimWorld, arena: ArenaDef, bodied_cap: int, mini_cap: int) -> void:
	var store: EnemyStore = w.enemies
	var minis: int = 0
	var alive: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		alive += 1
		if w.ext.has_flag(i, EnemyExtState.F_MINI):
			minis += 1
		if not (is_finite(store.x[i]) and is_finite(store.z[i])):
			non_finite += 1
		elif store.x[i] < arena.min_x - 3.0 or store.x[i] > arena.max_x + 3.0 or store.z[i] < arena.min_z - 3.0 or store.z[i] > arena.max_z + 3.0:
			out_of_bounds += 1
	var bodied: int = alive - minis
	minis_max = maxi(minis_max, minis)
	bodied_max = maxi(bodied_max, bodied)
	high_water_max = maxi(high_water_max, store.high_water)
	if w.tick > WARM_UP:
		ticks_bodied_at_cap += 1 if bodied >= bodied_cap - 2 else 0
		ticks_minis_near_cap += 1 if minis >= mini_cap - 5 else 0


func test_it_ran_five_minutes_in_one_wave() -> void:
	assert_int(world.tick).is_equal(TICKS)
	assert_bool(world.is_over()).is_false()
	assert_bool(GameState.is_combat(world.phase)).is_true()
	assert_int(world.wave).is_equal(1)


func test_both_caps_were_held() -> void:
	var counted: int = TICKS - WARM_UP
	assert_int(bodied_max).is_less_equal(content.mission.enemy_cap)  # SPEC 5.5: no spawn uses the store's 8 spare rows
	assert_int(minis_max).is_equal(content.mission.swarm_cap)
	assert_int(ticks_bodied_at_cap).is_greater(floori(float(counted) * 0.9))  # 50 bodied, give or take the two that just died
	assert_int(ticks_minis_near_cap).is_greater(floori(float(counted) * 0.9))  # 40 minis


func test_there_was_a_blast_every_second_and_it_hit_a_crowd() -> void:
	assert_int(blasts_made).is_greater_equal(floori(float(TICKS - content.mission.prepare_ticks) / float(BLAST_PERIOD)) - 1)
	assert_int(blast_events).is_greater_equal(blasts_made)  # the test's own, and the death blasts on top
	assert_int(blast_hits).is_greater(blasts_made * 3)


func test_every_bodied_type_of_the_game_and_the_minis_were_in_the_yard() -> void:
	for type_index: int in BODIED:
		assert_bool(types_seen.has(type_index)).override_failure_message("type %d never spawned" % type_index).is_true()
	assert_bool(types_seen.has(Ids.EN_MOTE)).is_true()
	assert_bool(types_seen.has(Ids.EN_SHARD)).is_true()  # splitters broke
	assert_int(killed).is_greater(500)
	assert_int(spawned).is_greater(killed)


func test_no_position_is_nan_or_infinite_or_outside_the_yard() -> void:
	assert_int(non_finite).is_equal(0)
	assert_int(out_of_bounds).is_equal(0)
	assert_int(high_water_max).is_less_equal(world.enemies.capacity)


func test_the_average_tick_costs_under_one_millisecond() -> void:
	var avg_ms: float = float(step_usec) / 1000.0 / float(world.tick)
	print("STRESS CHAIN avg step %.3f ms, slowest %.2f ms, %d ticks, spawned %d, killed %d, blasts %d (%d events, %d hits), minis max %d" % [
		avg_ms, float(slowest_usec) / 1000.0, world.tick, spawned, killed, blasts_made, blast_events, blast_hits, minis_max])
	assert_float(avg_ms).is_less(1.0)
