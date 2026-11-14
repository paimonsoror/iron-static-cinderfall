extends GdUnitTestSuite
## V4-W: the hornet rack (firing kind M, VARIETY_SPEC 3.3) and the target picks it uses (FireTargets.pick_many, the body of
## Targeting.pick_many). A salvo of 6 missiles (8 at level 3), each to a different target, each 48 damage in a 1.2 m blast
## that falls to 18 at the edge (V5-C: was 24 and 10); flight 30 ticks; 0.5 salvos a second (the first on tick 120), 4 salvos, a 192-tick reload,
## range 22 m. With fewer targets than missiles the list repeats. Skitter: 45 hp, armor 0, radius 0.35.


func _rack(level: int = 1) -> SimWorld:
	return ArsenalWKit.world(Ids.WP_HORNET_RACK, level)


## Eight skitters, ids 1 to 8, by distance from the Warden: 4, 7.3, 10.2, 13.0, 15.3, 16.4, 18.8, 20.6 m. All stand at
## least 3.6 m apart, so no splash reaches a neighbour. The first is the locked target.
func _eight(w: SimWorld) -> void:
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 7.0, 2.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, -2.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 13.0, 1.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 15.0, -3.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, -13.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, -17.0)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, -20.0)


func _salvo(w: SimWorld) -> void:
	ArsenalWKit.run_until_shots(w, 1)
	ArsenalWKit.hold_fire(w)
	ArsenalWKit.run_both(w, 30)


func test_six_missiles_go_to_the_six_best_ranked_enemies() -> void:
	var w: SimWorld = _rack()
	_eight(w)
	assert_int(ArsenalWKit.run_until_shots(w, 1)).is_equal(120)
	ArsenalWKit.hold_fire(w)
	var launched: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)
	assert_int(launched.size()).is_equal(6)
	for k: int in 6:
		assert_int(launched[k].a).is_equal(HazardState.K_MISSILE)
		assert_int(launched[k].b).is_equal(30)
		assert_float(launched[k].f).is_equal_approx(w.enemies.x[k], 1e-5)  # the target's place at launch
		assert_float(launched[k].g).is_equal_approx(w.enemies.z[k], 1e-5)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)
	ArsenalWKit.run_both(w, 29)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)  # tick 149: still in the air
	ArsenalWKit.run_both(w, 1)  # tick 150
	for i: int in 6:
		assert_float(VarietyCKit.taken(w, i)).is_equal(48.0)
	assert_float(VarietyCKit.taken(w, 6)).is_equal(0.0)
	assert_float(VarietyCKit.taken(w, 7)).is_equal(0.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(6)


func test_fewer_targets_than_missiles_repeat_from_the_start_of_the_list() -> void:
	var three: SimWorld = _rack()
	for k: int in 3:
		ArsenalWKit.foe(three, Ids.EN_SKITTER, 4.0 + 5.5 * k, 0.0, k == 0)
	_salvo(three)
	for i: int in 3:
		assert_float(VarietyCKit.taken(three, i)).is_equal(96.0)  # two missiles each
	var one: SimWorld = _rack()
	ArsenalWKit.foe(one, Ids.EN_SKITTER, 8.0, 0.0, true)
	_salvo(one)
	assert_float(VarietyCKit.taken(one, 0)).is_equal(288.0)  # all six
	var four: SimWorld = _rack()
	for k: int in 4:
		ArsenalWKit.foe(four, Ids.EN_SKITTER, 4.0 + 3.5 * k, float(k) * 2.0 - 3.0, k == 0)
	_salvo(four)
	assert_float(VarietyCKit.taken(four, 0)).is_equal(96.0)  # 6 missiles over 4 targets: the first two get a second
	assert_float(VarietyCKit.taken(four, 1)).is_equal(96.0)
	assert_float(VarietyCKit.taken(four, 2)).is_equal(48.0)
	assert_float(VarietyCKit.taken(four, 3)).is_equal(48.0)


func test_the_splash_falls_from_48_at_the_centre_to_18_at_1_2_metres() -> void:
	var w: SimWorld = _rack()
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.9)
	_salvo(w)
	# 3 missiles on each: 3 x 48 of its own and 3 splashes at 0.9 m of the other's: 48 x (1 - (1 - 18 / 48) x 0.9 / 1.2)
	var splash: float = 48.0 * (1.0 - (1.0 - 18.0 / 48.0) * 0.9 / 1.2)
	assert_float(splash).is_equal_approx(25.5, 1e-5)
	assert_float(VarietyCKit.taken(w, 0)).is_equal_approx(144.0 + 3.0 * 25.5, 1e-5)
	assert_float(VarietyCKit.taken(w, 1)).is_equal_approx(144.0 + 3.0 * 25.5, 1e-5)


func test_level_three_fires_eight_missiles_of_1_55_times_the_damage() -> void:
	var w: SimWorld = _rack(3)
	_eight(w)
	ArsenalWKit.run_until_shots(w, 1)
	ArsenalWKit.hold_fire(w)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(8)
	ArsenalWKit.run_both(w, 30)
	for i: int in 8:
		assert_float(VarietyCKit.taken(w, i)).is_equal_approx(48.0 * 1.55, 1e-3)


func test_level_two_scales_the_damage() -> void:
	var w: SimWorld = _rack(2)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	_salvo(w)
	assert_float(VarietyCKit.taken(w, 0)).is_equal_approx(6.0 * 60.0, 1e-5)


func test_four_salvos_then_a_reload_of_192_ticks() -> void:
	var w: SimWorld = _rack()
	ArsenalWKit.foe(w, Ids.EN_HULK, 10.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 540)
	assert_array(ticks).is_equal([120, 240, 360, 480])
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_STARTED)).is_equal([480])
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)[0].a).is_equal(192)


func test_the_rack_does_not_reach_beyond_22_metres() -> void:
	var w: SimWorld = _rack()
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 14.0, -17.0, true)  # 22.0 m
	w.enemies.z[t] = w.warden.z - 17.5  # 22.6 m
	ArsenalWKit.run_both(w, 200)
	assert_int(w.warden.shots_fired).is_equal(0)


# --- FireTargets.pick_many (the body Targeting.pick_many should return) ---


func test_pick_many_ranks_by_the_targeting_order_and_stops_at_n() -> void:
	var w: SimWorld = _rack()
	var near: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 3.0, 0.0)
	var soon: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.0, 0.0, true)  # arrives first: the best rank
	var mid: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.0)
	var out: PackedInt32Array = PackedInt32Array([99, 98])  # cleared first
	assert_int(FireTargets.pick_many(w, w.warden.x, w.warden.z, 22.0, 2, out)).is_equal(2)
	assert_array(Array(out)).is_equal([w.enemies.id[soon], w.enemies.id[near]])
	assert_int(FireTargets.pick_many(w, w.warden.x, w.warden.z, 22.0, 9, out)).is_equal(3)
	assert_array(Array(out)).is_equal([w.enemies.id[soon], w.enemies.id[near], w.enemies.id[mid]])
	assert_int(FireTargets.pick_many(w, w.warden.x, w.warden.z, 22.0, 0, out)).is_equal(0)
	assert_bool(out.is_empty()).is_true()


func test_pick_many_ties_go_to_the_lower_id_and_range_is_respected() -> void:
	var w: SimWorld = _rack()
	var upper: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 2.0)  # id 1
	var lower: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, -2.0)  # id 2: the same distance
	var out_of_range: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.0, 0.0)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(FireTargets.pick_many(w, w.warden.x, w.warden.z, 9.0, 5, out)).is_equal(2)
	assert_array(Array(out)).is_equal([w.enemies.id[upper], w.enemies.id[lower]])
	assert_bool(out.has(w.enemies.id[out_of_range])).is_false()


func test_the_salvo_list_puts_the_locked_target_first_even_when_it_ranks_low() -> void:
	var w: SimWorld = _rack()
	for k: int in 4:
		ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0 + 3.0 * float(k), 0.0, k == 0)
	var far_id: int = w.enemies.id[3]
	var three: PackedInt32Array = FireTargets.salvo_targets(w, far_id, w.warden.x, w.warden.z, 22.0, 3)
	assert_array(Array(three)).is_equal([4, 1, 2])
	var six: PackedInt32Array = FireTargets.salvo_targets(w, far_id, w.warden.x, w.warden.z, 22.0, 6)
	assert_array(Array(six)).is_equal([4, 1, 2, 3, 4, 1])
	var none: PackedInt32Array = FireTargets.salvo_targets(w, 77, w.warden.x, w.warden.z, 1.0, 6)
	assert_bool(none.is_empty()).is_true()
