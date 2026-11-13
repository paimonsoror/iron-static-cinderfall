extends GdUnitTestSuite
## V4-W: the slag mortar (firing kind S, VARIETY_SPEC 3.3). 80 damage in a 2.6 m blast (50% at the edge), 0.8 shots a
## second (the first shell leaves on tick 75), 4 shells, a 144-tick reload, range 6 to 24 m, a 42-tick flight, then a pool of
## 2.2 m for 240 ticks (360 at level 3): 15 damage a second and a 25% slow. The shell goes to the densest cluster; the lock
## does not matter. Skitter: 45 hp, armor 0, radius 0.35.


func _mortar(level: int = 1) -> SimWorld:
	return ArsenalWKit.world(Ids.WP_SLAG_MORTAR, level)


## Three skitters in a tight group (ids 1 to 3), a pair (4, 5) and a lone one (6, the target) at dx, dz from the Warden.
func _field(w: SimWorld) -> void:
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.5, 0.5)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 11.0, -0.5)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 13.0, 3.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 13.5, 3.5)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, -4.0, true)


func _fire_once(w: SimWorld) -> void:
	ArsenalWKit.run_until_shots(w, 1)
	ArsenalWKit.hold_fire(w)


func test_the_shell_leaves_on_tick_75_and_lands_42_ticks_later_on_the_densest_cluster() -> void:
	var w: SimWorld = _mortar()
	_field(w)
	assert_int(ArsenalWKit.run_until_shots(w, 1)).is_equal(75)
	ArsenalWKit.hold_fire(w)
	var launched: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)
	assert_int(launched.size()).is_equal(1)
	assert_int(launched[0].a).is_equal(HazardState.K_SHELL)
	assert_int(launched[0].b).is_equal(42)
	# the group of three: every member has 3 within 2.6 m, so the lower id (the first skitter) is the centre
	assert_float(launched[0].f).is_equal_approx(w.enemies.x[0], 1e-4)
	assert_float(launched[0].g).is_equal_approx(w.enemies.z[0], 1e-4)
	ArsenalWKit.run_both(w, 41)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)  # tick 116: still in the air
	ArsenalWKit.run_both(w, 1)  # tick 117
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(1)
	var blast: SimEvent = VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST)[0]
	assert_int(blast.a).is_equal(HazardState.K_SHELL)
	assert_int(blast.b).is_equal(260)
	assert_int(blast.tick).is_equal(117)


func test_the_damage_falls_from_the_whole_at_the_centre_to_half_at_the_edge() -> void:
	var w: SimWorld = _mortar()
	_field(w)
	_fire_once(w)
	ArsenalWKit.run_both(w, 42)
	var centre: Vector2 = Vector2(w.enemies.x[0], w.enemies.z[0])
	for i: int in [0, 1, 2]:
		var d: float = centre.distance_to(Vector2(w.enemies.x[i], w.enemies.z[i]))
		assert_float(VarietyCKit.taken(w, i)).is_equal_approx(80.0 * (1.0 - 0.5 * d / 2.6), 1e-3)
	assert_float(VarietyCKit.taken(w, 0)).is_equal_approx(80.0, 1e-3)
	for i: int in [3, 4, 5]:
		assert_float(VarietyCKit.taken(w, i)).is_equal(0.0)


func test_a_kill_by_the_shell_is_the_wardens() -> void:
	var w: SimWorld = _mortar()
	var weak: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 10.0, 0.0)
	w.enemies.path_dist[weak] = 1.0
	_fire_once(w)
	ArsenalWKit.run_both(w, 42)
	assert_int(w.enemies.alive[weak]).is_equal(0)
	assert_int(w.combat.kills_by_source[DamageSource.Id.WARDEN]).is_equal(1)


func test_the_pool_starts_when_the_shell_lands_and_burns_for_exactly_four_seconds() -> void:
	var w: SimWorld = _mortar()
	_field(w)
	_fire_once(w)
	ArsenalWKit.run_both(w, 41)  # tick 116
	assert_int(w.hazards.pool_count()).is_equal(0)
	ArsenalWKit.run_both(w, 1)  # tick 117: the shell lands and the pool opens
	assert_int(w.hazards.pool_count()).is_equal(1)
	assert_int(w.hazards.p_ticks_left[0]).is_equal(239)  # 240, less the tick of the landing
	assert_float(w.hazards.p_radius[0]).is_equal_approx(2.2, 1e-5)
	assert_float(w.hazards.p_dps[0]).is_equal(15.0)
	assert_float(w.hazards.p_slow[0]).is_equal(0.25)
	assert_float(w.hazards.p_x[0]).is_equal_approx(w.enemies.x[0], 1e-4)
	var started: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.POOL_STARTED)
	assert_int(started.size()).is_equal(1)
	assert_int(started[0].tick).is_equal(117)
	assert_int(started[0].b).is_equal(220)
	var before: float = VarietyCKit.taken(w, 1)
	ArsenalWKit.run_both(w, 239)  # to tick 356
	assert_int(w.hazards.pool_count()).is_equal(0)
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.POOL_ENDED)).is_equal([356])
	# eight pulses of 7.5 (15 a second for 4 s) on everyone within 2.2 m of the point, whatever the armor
	assert_float(VarietyCKit.taken(w, 1) - before).is_equal_approx(60.0, 1e-5)
	assert_float(VarietyCKit.taken(w, 4)).is_equal(0.0)  # the pair stood outside the pool


func test_level_three_leaves_the_pool_for_six_seconds_and_level_two_hits_harder() -> void:
	var two: SimWorld = _mortar(2)
	_field(two)
	_fire_once(two)
	ArsenalWKit.run_both(two, 42)
	assert_float(VarietyCKit.taken(two, 0)).is_equal_approx(100.0, 1e-3)
	var three: SimWorld = _mortar(3)
	_field(three)
	_fire_once(three)
	ArsenalWKit.run_both(three, 42)
	assert_float(VarietyCKit.taken(three, 0)).is_equal_approx(80.0 * 1.55, 1e-2)
	assert_int(three.hazards.p_ticks_left[0]).is_equal(359)
	ArsenalWKit.run_both(three, 359)
	assert_array(VarietyCKit.ticks_of(three, SimEventKind.Id.POOL_ENDED)).is_equal([117 + 359])


func test_overpressure_widens_the_blast_and_the_pool() -> void:
	var w: SimWorld = _mortar()
	w.mods.area_mul = 1.35
	_field(w)
	_fire_once(w)
	ArsenalWKit.run_both(w, 42)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST)[0].b).is_equal(351)
	assert_float(w.hazards.p_radius[0]).is_equal_approx(2.2 * 1.35, 1e-5)


func test_equal_clusters_go_to_the_one_with_the_best_ranked_enemy() -> void:
	var w: SimWorld = _mortar()
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0)  # id 1 \ a pair
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.8, 0.0)  # id 2 /
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, -6.0)  # id 3 \ another pair
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.8, -6.0, true)  # id 4 /  holds the best-ranked enemy
	_fire_once(w)
	var launched: SimEvent = VarietyCKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)[0]
	assert_float(launched.f).is_equal_approx(w.enemies.x[2], 1e-4)  # the lower id of the pair that won
	assert_float(launched.g).is_equal_approx(w.enemies.z[2], 1e-4)


func test_the_pick_cluster_query_agrees_and_the_band_is_six_to_twenty_four_metres() -> void:
	var w: SimWorld = _mortar()
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0, 0.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.5, 0.5)
	var at: Vector2 = Targeting.pick_cluster(w, w.warden.x, w.warden.z, 6.0, 24.0, 2.6)
	assert_vector(at).is_equal(Vector2(w.warden.x, w.warden.z))  # nothing between 6 and 24 m
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 7.0, 0.0)
	at = Targeting.pick_cluster(w, w.warden.x, w.warden.z, 6.0, 24.0, 2.6)
	assert_float(at.x).is_equal_approx(w.warden.x + 7.0, 1e-4)


func test_it_holds_fire_while_everything_is_inside_six_metres() -> void:
	var w: SimWorld = _mortar()
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 1.0)
	ArsenalWKit.run_both(w, 300)
	assert_int(w.warden.shots_fired).is_equal(0)
	assert_int(w.hazards.queued()).is_equal(0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(4)  # nothing was paid for
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 7.0, 0.0)
	ArsenalWKit.run_both(w, 1)
	assert_int(w.warden.shots_fired).is_equal(1)  # the banked shot leaves at once


func test_four_shells_then_a_reload_of_144_ticks() -> void:
	var w: SimWorld = _mortar()
	ArsenalWKit.foe(w, Ids.EN_HULK, 10.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 450)
	assert_array(ticks).is_equal([75, 150, 225, 300, 444])
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_STARTED)).is_equal([300])
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)[0].a).is_equal(144)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(5)


func test_a_shell_in_the_air_when_the_wave_clears_lands_without_a_pool() -> void:
	var w: SimWorld = _mortar()
	_field(w)
	_fire_once(w)
	HazardSystem.clear(w)  # the wave cleared with the shell in the air: the queue is dropped
	ArsenalWKit.run_both(w, 60)
	assert_int(w.hazards.pool_count()).is_equal(0)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)
