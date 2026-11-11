extends GdUnitTestSuite
## GameHoldScenario (--scenario=hold<N>): keeps N enemies alive while a wave is in combat, through the sim's mutators.


func _combat_world() -> SimWorld:
	var w: SimWorld = TestContent.world(2)
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 1
	return w


func test_it_does_nothing_outside_combat() -> void:
	var w: SimWorld = TestContent.world()
	var h: GameHoldScenario = GameHoldScenario.new(20, 1)
	h.act(w)
	assert_int(w.alive_count()).is_equal(0)
	assert_int(h.spawned_total).is_equal(0)


func test_it_tops_the_field_up_to_n_a_few_enemies_per_tick() -> void:
	var w: SimWorld = _combat_world()
	var h: GameHoldScenario = GameHoldScenario.new(10, 1)
	h.act(w)
	assert_int(w.alive_count()).is_equal(GameHoldScenario.MAX_SPAWNS_PER_TICK)
	for i: int in 10:
		h.act(w)
	assert_int(w.alive_count()).is_equal(10)
	h.act(w)
	assert_int(w.alive_count()).is_equal(10)


func test_it_refills_after_kills() -> void:
	var w: SimWorld = _combat_world()
	var h: GameHoldScenario = GameHoldScenario.new(6, 1)
	for i: int in 4:
		h.act(w)
	assert_int(w.alive_count()).is_equal(6)
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and w.alive_count() > 3:
			w.kill_enemy(i, DamageSource.Id.WARDEN)
	assert_int(w.alive_count()).is_equal(3)
	for i: int in 3:
		h.act(w)
	assert_int(w.alive_count()).is_equal(6)


func test_it_never_exceeds_the_enemy_cap() -> void:
	var w: SimWorld = _combat_world()
	var h: GameHoldScenario = GameHoldScenario.new(500, 1)
	for i: int in 100:
		h.act(w)
	assert_int(w.alive_count()).is_equal(w.content.mission.enemy_cap)


func test_a_mixed_crowd_spawns_inside_the_spawn_regions() -> void:
	var w: SimWorld = _combat_world()
	var h: GameHoldScenario = GameHoldScenario.new(30, 5)
	for i: int in 12:
		h.act(w)
	var kinds: Dictionary = {}
	var arena: ArenaDef = w.content.arena
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 0:
			continue
		kinds[w.enemies.type[i]] = true
		var inside: bool = false
		for r: SpawnRegionDef in arena.spawn_regions:
			var on_x: bool = w.enemies.x[i] >= minf(r.x0, r.x1) - 0.001 and w.enemies.x[i] <= maxf(r.x0, r.x1) + 0.001
			var on_z: bool = w.enemies.z[i] >= minf(r.z0, r.z1) - 0.001 and w.enemies.z[i] <= maxf(r.z0, r.z1) + 0.001
			inside = inside or (on_x and on_z)
		assert_bool(inside).is_true()
	assert_int(kinds.size()).is_greater_equal(2)


func test_the_same_seed_gives_the_same_crowd() -> void:
	var a: SimWorld = _combat_world()
	var b: SimWorld = _combat_world()
	var ha: GameHoldScenario = GameHoldScenario.new(12, 9)
	var hb: GameHoldScenario = GameHoldScenario.new(12, 9)
	for i: int in 6:
		ha.act(a)
		hb.act(b)
	assert_str(a.state_hash()).is_equal(b.state_hash())


func test_a_run_with_the_scenario_never_ends_while_enemies_are_held() -> void:
	var cfg: SimConfig = GameRunKit.config(1)
	cfg.debug_invulnerable_core = true
	var rc: RunController = GameRunKit.controller(self, cfg)
	rc.scenario = GameHoldScenario.new(15, 1)
	GameRunKit.frames(rc, rc.sim.content.mission.prepare_ticks + 600)
	assert_bool(GameState.is_combat(rc.sim.phase)).is_true()
	assert_int(rc.sim.alive_count()).is_greater_equal(12)  # topped up before every tick; a tick kills at most a few
	assert_float(rc.sim.core_hp).is_equal(rc.sim.core_max_hp)
