extends GdUnitTestSuite
## V4-N: the variety rules of Targeting (the mini rule, standoff enemies, pick_many), slow, stun and knockback, the
## forbidden affix pairs (CONTENT 4.3), and the elites of a generated plan becoming real elites.

const EPS: float = 0.000001


func _world() -> SimWorld:
	return SimEnemiesKit.world()


func _status(w: SimWorld, ticks: int = 1) -> void:
	for _n: int in ticks:
		SimEnemiesKit.begin_tick(w)
		AbilitySystem.step(w)
		StatusSystem.step(w)


func test_the_mini_rule_a_body_in_the_same_eta_bucket_outranks_a_mini() -> void:
	var w: SimWorld = _world()
	var mote: int = SimEnemiesKit.place_core(w, Ids.EN_MOTE, 10.0, 0.0)
	var body: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 12.0, 0.0)
	var fx: float = w.enemies.x[mote] - 1.0  # the mote is the nearer one to the shooter
	var fz: float = w.enemies.z[mote]
	w.enemies.path_dist[mote] = 0.2
	w.enemies.path_dist[body] = 0.2
	assert_int(Targeting.eta_bucket(w, mote)).is_equal(Targeting.eta_bucket(w, body))
	assert_bool(Targeting.compare(w, body, mote, fx, fz)).is_true()
	assert_bool(Targeting.compare(w, mote, body, fx, fz)).is_false()
	assert_int(Targeting.pick(w, fx, fz, 30.0)).is_equal(w.enemies.id[body])
	# a body that attacks the core comes before any mini
	w.enemies.path_dist[mote] = 0.0
	w.enemies.path_dist[body] = 0.0
	w.enemies.state[body] = EnemyStore.ST_ATTACKING
	assert_bool(Targeting.compare(w, body, mote, fx, fz)).is_true()
	# otherwise the normal order applies: a mote that is strictly nearer the core by bucket is shot first
	w.enemies.state[body] = EnemyStore.ST_MOVING
	w.enemies.path_dist[body] = 30.0
	assert_bool(Targeting.compare(w, mote, body, fx, fz)).is_true()
	# two minis: the old order (distance, then id)
	var mote2: int = SimEnemiesKit.place_core(w, Ids.EN_MOTE, 10.5, 0.0)
	w.enemies.path_dist[mote2] = 0.0
	assert_bool(Targeting.compare(w, mote, mote2, fx, fz)).is_true()


func test_a_parked_standoff_enemy_that_does_not_fire_is_not_an_attacker() -> void:
	var w: SimWorld = _world()
	var a: ArenaDef = w.content.arena
	var ring: int = StandoffPoints.ring_of(a, 12.5)
	var at: int = a.standoff_ring.find(ring)
	var r: int = SimEnemiesKit.place(w, Ids.EN_RECLAIMER, a.standoff_points[at].x, a.standoff_points[at].y)
	assert_int(SimEnemiesKit.run_until_attacking(w, r, 10)).is_greater(0)
	var k: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 3.0, 0.0)
	w.enemies.state[k] = EnemyStore.ST_ATTACKING
	w.enemies.path_dist[k] = 0.0
	# both stand still with ETA 0 and the reclaimer is the priority class and the nearer one, yet the attacker is first
	assert_bool(Targeting.compare(w, k, r, w.enemies.x[r] + 0.5, w.enemies.z[r])).is_true()
	SimEnemiesKit.run(w, 300)
	assert_bool(w.ext.has_flag(r, EnemyExtState.F_FIRED)).is_false()  # a reclaimer never fires


func test_pick_many_returns_the_best_n_in_rank_order() -> void:
	var w: SimWorld = _world()
	var rows: Array[int] = []
	for k: int in 5:
		var i: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 10.0 + float(k), 0.0)
		w.enemies.path_dist[i] = 40.0 - 8.0 * float(k)  # the last placed is the nearest by ETA
		rows.append(i)
	var fx: float = w.content.arena.core_x
	var fz: float = w.content.arena.core_z
	var out: PackedInt32Array = PackedInt32Array([99, 98])
	assert_int(Targeting.pick_many(w, fx, fz, 30.0, 3, out)).is_equal(3)
	assert_array(Array(out)).is_equal([w.enemies.id[rows[4]], w.enemies.id[rows[3]], w.enemies.id[rows[2]]])
	assert_int(out[0]).is_equal(Targeting.pick(w, fx, fz, 30.0))
	assert_int(Targeting.pick_many(w, fx, fz, 30.0, 9, out)).is_equal(5)
	assert_int(Targeting.pick_many(w, fx, fz, 12.5, 9, out)).is_equal(3)  # range
	assert_int(Targeting.pick_many(w, fx, fz, 30.0, 0, out)).is_equal(0)
	assert_int(out.size()).is_equal(0)
	# a MAGNETIC elite within its pull comes first
	var magnet: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 11.5, 0.0, SimEnemiesKit.mask(w, [&"aff_magnetic"]))
	w.enemies.path_dist[magnet] = 90.0
	Targeting.pick_many(w, fx, fz, 30.0, 2, out)
	assert_array(Array(out)).is_equal([w.enemies.id[magnet], w.enemies.id[rows[4]]])
	# the legacy content: the same order as pick
	var old: SimWorld = TestContent.world()
	var first: int = old.spawn_enemy(Ids.EN_SKITTER, 5.0, 0.0)
	var second: int = old.spawn_enemy(Ids.EN_SKITTER, 6.0, 0.0)
	old.enemies.path_dist[first] = 20.0
	old.enemies.path_dist[second] = 5.0
	Targeting.pick_many(old, 0.0, 0.0, 30.0, 2, out)
	assert_array(Array(out)).is_equal([old.enemies.id[second], old.enemies.id[first]])


func test_a_slow_scales_the_walk_the_stronger_one_wins_and_it_wears_off() -> void:
	var w: SimWorld = _world()
	var h: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 14.0, 0.0)
	SimEnemiesKit.run(w, 10)
	StatusSystem.apply_slow(w, h, 30, 400)
	var x: float = w.enemies.x[h]
	var z: float = w.enemies.z[h]
	SimEnemiesKit.tick(w)
	var step_m: float = w.nav.t_step[Ids.EN_HOLLOW]
	assert_float(Vector2(w.enemies.x[h] - x, w.enemies.z[h] - z).length()).is_equal_approx(step_m * 0.6, EPS)
	StatusSystem.apply_slow(w, h, 90, 300)  # weaker: ignored
	assert_int(w.ext.slow_milli[h]).is_equal(400)
	assert_int(w.ext.slow_ticks[h]).is_equal(29)
	StatusSystem.apply_slow(w, h, 10, 600)  # stronger: replaces, never stacks
	assert_int(w.ext.slow_milli[h]).is_equal(600)
	assert_int(w.ext.slow_ticks[h]).is_equal(10)
	StatusSystem.apply_slow(w, h, 50, 600)  # the same strength: the longer time
	assert_int(w.ext.slow_ticks[h]).is_equal(50)
	SimEnemiesKit.run(w, 50)
	assert_int(w.ext.slow_ticks[h]).is_equal(0)
	assert_int(w.ext.slow_milli[h]).is_equal(0)
	x = w.enemies.x[h]
	z = w.enemies.z[h]
	SimEnemiesKit.tick(w)
	assert_float(w.nav.speed_mul[h]).is_equal(1.0)
	assert_float(Vector2(w.enemies.x[h] - x, w.enemies.z[h] - z).length()).is_equal_approx(step_m, EPS)


func test_apply_stun_keeps_the_longer_stun_and_respects_immunity() -> void:
	var w: SimWorld = _world()
	var k: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 0.0)
	assert_bool(StatusSystem.apply_stun(w, k, 60)).is_true()
	assert_bool(StatusSystem.apply_stun(w, k, 30)).is_false()
	assert_int(w.enemies.stun_ticks[k]).is_equal(60)
	assert_bool(StatusSystem.apply_stun(w, k, 90)).is_true()
	assert_int(w.enemies.stun_ticks[k]).is_equal(90)
	var other: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 12.0, 2.0)
	w.enemies.stun_immune_ticks[other] = 10
	assert_bool(StatusSystem.apply_stun(w, other, 60)).is_false()
	assert_bool(StatusSystem.apply_stun(w, -1, 60)).is_false()
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.ENEMY_STUNNED).size()).is_equal(2)


func test_a_knockback_moves_light_bodies_fully_heavy_ones_less_and_never_into_the_core() -> void:
	var w: SimWorld = _world()
	var light: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 14.0, 0.0)
	var heavy: int = SimEnemiesKit.place_core(w, Ids.EN_HOLLOW, 14.0, 3.0)
	var boss: int = SimEnemiesKit.place_core(w, Ids.EN_HULK, 14.0, -5.0)
	var x: float = w.enemies.x[light]
	assert_float(MovementSystem.knockback(w, light, 2.0, 0.0, 1.0)).is_equal_approx(1.0, EPS)  # the direction is normalised
	assert_float(w.enemies.x[light]).is_equal_approx(x + 1.0, EPS)
	assert_float(MovementSystem.knockback(w, heavy, 1.0, 0.0, 1.0)).is_equal_approx(0.5, EPS)  # mass 3 against 1.5
	assert_float(MovementSystem.knockback(w, boss, 1.0, 0.0, 1.0)).is_equal(0.0)
	assert_float(MovementSystem.knockback(w, light, 0.0, 0.0, 1.0)).is_equal(0.0)
	var close: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 3.0, 0.0)
	MovementSystem.knockback(w, close, -1.0, 0.0, 2.5)  # at the core
	assert_float(SimEnemiesKit.core_dist(w, close)).is_greater_equal(w.content.arena.core_radius + 0.35)


func test_an_attacker_that_is_knocked_off_its_slot_walks_back() -> void:
	var w: SimWorld = _world()
	var k: int = SimEnemiesKit.place_core(w, Ids.EN_SKITTER, 5.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, k)).is_greater(0)
	SimEnemiesKit.run(w, 20)
	var slot: Vector2 = w.nav.slots.slot_position(w.enemies.slot[k])
	assert_float(MovementSystem.knockback(w, k, 1.0, 0.0, 1.0)).is_equal_approx(1.0, EPS)
	assert_int(w.enemies.state[k]).is_equal(EnemyStore.ST_ATTACKING)
	SimEnemiesKit.run(w, 30)
	assert_float(w.enemies.x[k]).is_equal_approx(slot.x, EPS)
	assert_float(w.enemies.z[k]).is_equal_approx(slot.y, EPS)


func test_forbidden_affix_pairs_never_form() -> void:
	var c: ContentSet = TestContent.variety()
	var bit: Dictionary[StringName, int] = {}
	for a: AffixDef in c.affixes:
		bit[a.id] = 1 << a.index
	assert_int(c.affixes.size()).is_equal(10)
	var magnetic_shroud: int = bit[&"aff_magnetic"] | bit[&"aff_shroud"]
	var warded_regen: int = bit[&"aff_warded"] | bit[&"aff_regen"]
	var swift_volatile: int = bit[&"aff_swift"] | bit[&"aff_volatile"]
	var late_pair: bool = false
	var other_pair: bool = false
	var singles: int = 0
	for s: int in range(1, 801):
		for act: int in [1, 2, 3]:
			var rusher: int = PlanElites.roll_affixes(c, Ids.EN_RUSHER, act, PlanRng.stream(s, &"sim_enemies.a"))
			var hollow: int = PlanElites.roll_affixes(c, Ids.EN_HOLLOW, act, PlanRng.stream(s, &"sim_enemies.b"))
			for m: int in [rusher, hollow]:
				assert_bool((m & magnetic_shroud) == magnetic_shroud).is_false()
				if act < 3:
					assert_bool((m & warded_regen) == warded_regen).is_false()
				else:
					late_pair = late_pair or (m & warded_regen) == warded_regen
			assert_bool((rusher & swift_volatile) == swift_volatile).is_false()
			other_pair = other_pair or (hollow & swift_volatile) == swift_volatile
			if act == 1:
				singles += 1 if _bits(rusher) == 1 and _bits(hollow) == 1 else 0
			if act == 3:
				assert_int(_bits(hollow)).is_equal(2)
	assert_int(singles).is_equal(800)  # act I: always one affix
	assert_bool(late_pair).is_true()  # WARDED + REGENERATING is allowed in act III only
	assert_bool(other_pair).is_true()  # SWIFT + VOLATILE is banned on a rusher only
	for never: int in [Ids.EN_MOTE, Ids.EN_SHARD, Ids.EN_BURSTER, Ids.EN_WARD_PYLON, Ids.EN_HULK]:
		assert_bool(PlanElites.eligible(c, never, 3)).is_false()
	assert_bool(PlanElites.eligible(c, Ids.EN_RECLAIMER, 2)).is_false()
	assert_bool(PlanElites.eligible(c, Ids.EN_RECLAIMER, 3)).is_true()


func _bits(m: int) -> int:
	var n: int = 0
	for k: int in 16:
		n += (m >> k) & 1
	return n


func test_the_planned_elites_of_seed_1_spawn_as_real_elites() -> void:
	var w: SimWorld = SimEnemiesKit.world(1)
	var wave_number: int = -1
	var option_index: int = -1
	for pw: PlannedWave in w.plan.waves:
		for o: int in pw.options.size():
			if wave_number < 0 and not pw.options[o].elites.is_empty():
				wave_number = pw.index
				option_index = o
	assert_int(wave_number).is_greater_equal(3)  # the plan of seed 1 schedules elites (waves 3 and 4)
	var planned_masks: PackedInt32Array = PackedInt32Array()
	for pe: PlannedElite in w.plan.waves[wave_number - 1].options[option_index].elites:
		planned_masks.append(pe.affix_mask)
	w.plan.chosen[wave_number - 1] = option_index
	w.wave = wave_number
	SimEnemiesKit.begin_tick(w)
	SpawnSystem.begin_wave(w, wave_number)
	var found: int = -1
	for _n: int in 4000:
		SimEnemiesKit.tick_spawning(w)
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] == 0:
				continue
			if w.ext.is_elite(i):
				found = i
			elif w.tick % 30 == 0:
				w.kill_enemy(i, DamageSource.Id.WARDEN)  # keep room under the caps
		if found >= 0:
			break
	assert_int(found).is_greater_equal(0)
	var def: EnemyDef = w.content.enemies[w.enemies.type[found]]
	var found_mask: int = w.ext.affix_mask[found]
	assert_bool(found_mask != 0 and planned_masks.has(found_mask)).is_true()
	var expect: float = def.hp * w.content.run.elite_hp_mult * EliteSystem.stat(w.content, found_mask, &"hp_mul", 1.0)
	assert_float(w.enemies.max_hp[found]).is_equal_approx(expect, EPS)
	assert_float(w.enemies.max_hp[found]).is_greater(def.hp * 2.0)
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.ELITE_SPAWNED).size()).is_greater_equal(1)
