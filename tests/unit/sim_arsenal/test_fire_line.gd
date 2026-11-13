extends GdUnitTestSuite
## V4-W: the rail lance (firing kind L, VARIETY_SPEC 3.3). 320 damage, 0.45 shots a second (450 milli per tick), 3 rounds
## (4 at level 3), a 156-tick reload, range 30 m, a 60-tick wind-up with the line fixed, a line 0.5 m wide (an enemy is on
## it when its body is within 0.25 m of the line), half the armor ignored. The wind-up starts so that it ends as the cadence
## allows the shot: the first charge begins on tick 74 (33,300 milli banked, 60 x 450 more to come) and the line is
## resolved on tick 134; the next shots follow every 133 ticks. Skitter: radius 0.35, armor 0; Hollow Warden: armor 8.


func _lance(level: int = 1) -> SimWorld:
	return ArsenalWKit.world(Ids.WP_RAIL_LANCE, level)


func test_the_wind_up_lasts_60_ticks_and_the_cadence_stays_at_0_45_a_second() -> void:
	var w: SimWorld = _lance()
	ArsenalWKit.foe(w, Ids.EN_HULK, 10.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 420)
	assert_array(ticks).is_equal([134, 267, 400])
	assert_int(ticks[1] - ticks[0]).is_equal(133)  # 60000 / 450 = 133.3


func test_the_magazine_holds_three_rounds_then_a_reload_of_156_ticks() -> void:
	var w: SimWorld = _lance()
	ArsenalWKit.foe(w, Ids.EN_HULK, 10.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 640)
	assert_array(ticks).is_equal([134, 267, 400, 616])  # reload ends on 556, the charge takes 60 more
	assert_int(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_STARTED)[0]).is_equal(400)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)[0].a).is_equal(156)
	assert_int(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_FINISHED)[0]).is_equal(556)


func test_the_charge_is_visible_in_the_state_and_the_line_is_fixed() -> void:
	var w: SimWorld = _lance()
	ArsenalWKit.foe(w, Ids.EN_HULK, 10.0, 0.0, true)
	VarietyCKit.run_weapon(w, 73)
	assert_int(w.arsenal.charge_left).is_equal(0)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_READY)
	VarietyCKit.run_weapon(w, 1)  # tick 74
	assert_int(w.arsenal.charge_left).is_equal(60)
	assert_int(ArsenalSystem.slot_state(w, 0)).is_equal(ArsenalSystem.ST_CHARGING)
	assert_float(w.arsenal.charge_x).is_equal_approx(w.warden.x + 30.0, 1e-5)  # the far end, at the range
	assert_float(w.arsenal.charge_z).is_equal_approx(w.warden.z, 1e-5)
	VarietyCKit.run_weapon(w, 26)  # tick 100
	assert_int(ArsenalSystem.slot_ticks_left(w, 0)).is_equal(34)
	VarietyCKit.run_weapon(w, 33)  # tick 133, one tick before the line
	assert_int(w.warden.shots_fired).is_equal(0)
	VarietyCKit.run_weapon(w, 1)
	assert_int(w.warden.shots_fired).is_equal(1)
	assert_int(w.arsenal.charge_left).is_equal(0)


func _line_world() -> SimWorld:
	var w: SimWorld = _lance()
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0, true)  # id 1, the target
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0, 0.3)  # id 2: 0.3 m off the line, body 0.35: on it
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 14.0, -0.5)  # id 3: behind the target, edge 0.15 m from the line
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 12.0, 0.9)  # id 4: edge 0.55 m from the line: off it
	ArsenalWKit.foe(w, Ids.EN_SKITTER, -3.0, 0.0)  # id 5: behind the Warden
	return w


func test_every_enemy_on_the_line_is_hit_nearest_first_and_the_others_are_not() -> void:
	var w: SimWorld = _line_world()
	ArsenalWKit.run_until_shots(w, 1)
	assert_int(w.tick).is_equal(134)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(320.0)
	assert_float(VarietyCKit.taken(w, 1)).is_equal(320.0)
	assert_float(VarietyCKit.taken(w, 2)).is_equal(320.0)
	for i: int in [3, 4]:
		assert_float(VarietyCKit.taken(w, i)).is_equal(0.0)
	var order: Array[int] = []
	for e: SimEvent in VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED):
		order.append(e.a)
	assert_array(order).is_equal([2, 1, 3])  # along the line from the Warden
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.SHOT_FIRED)[0].b).is_equal(2)  # the nearest enemy on the line


func test_the_line_ends_at_the_range_and_an_enemy_beyond_its_end_is_missed_unless_its_body_reaches() -> void:
	var w: SimWorld = _lance()
	var reaches: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.3, 0.0)  # 0.3 m past the end, body 0.35
	var misses: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.0)  # 1.0 m past the end
	var hit: PackedInt32Array = FireLine.on_line(w, w.warden.x, w.warden.z, w.warden.x + 5.0, w.warden.z, 0.25)
	assert_bool(hit.has(reaches)).is_true()
	assert_bool(hit.has(misses)).is_false()


func test_the_line_stays_where_it_was_fixed_when_the_target_walks_away() -> void:
	var w: SimWorld = _line_world()
	VarietyCKit.run_weapon(w, 90)
	assert_int(w.arsenal.charge_left).is_greater(0)
	w.enemies.z[0] = w.warden.z + 6.0  # the locked target leaves the line ...
	w.enemies.z[3] = w.warden.z  # ... and another enemy steps onto it
	VarietyCKit.run_weapon(w, 44)
	assert_int(w.warden.shots_fired).is_equal(1)
	assert_float(VarietyCKit.taken(w, 0)).is_equal(0.0)
	assert_float(VarietyCKit.taken(w, 3)).is_equal(320.0)


func test_half_of_the_armor_is_ignored() -> void:
	var w: SimWorld = _lance()
	var hollow: int = ArsenalWKit.foe(w, Ids.EN_HOLLOW, 10.0, 0.0, true)
	var hulk: int = ArsenalWKit.foe(w, Ids.EN_HULK, 14.0, 0.0)
	ArsenalWKit.run_until_shots(w, 1)
	assert_float(VarietyCKit.taken(w, hollow)).is_equal(320.0 - 4.0)  # armor 8 / 2
	assert_float(VarietyCKit.taken(w, hulk)).is_equal(320.0 - 6.0)  # armor 12 / 2


func test_a_swap_cancels_the_charge_and_nothing_fires() -> void:
	var w: SimWorld = _lance()
	ArsenalSystem.give_weapon(w, 1, Ids.WP_PISTOL)
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0, true)
	VarietyCKit.run_weapon(w, 100)
	assert_int(w.arsenal.charge_left).is_greater(0)
	assert_int(VarietyCKit.swap_on_next_tick(w, 1)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.charge_left).is_equal(0)
	assert_float(VarietyCKit.taken(w, t)).is_equal(0.0)
	assert_int(VarietyCKit.swap_on_next_tick(w, 0)).is_equal(Reason.Id.WRONG_STATE)  # refused while the swap runs
	VarietyCKit.run_weapon(w, 30)
	assert_int(VarietyCKit.swap_on_next_tick(w, 0)).is_equal(Reason.Id.OK)
	assert_int(w.arsenal.charge_left).is_equal(0)  # the wind-up starts over from the banked cadence


func test_levels_two_and_three_scale_the_damage_and_the_third_adds_a_round() -> void:
	var two: SimWorld = _lance(2)
	var a: int = ArsenalWKit.foe(two, Ids.EN_SKITTER, 10.0, 0.0, true)
	ArsenalWKit.run_until_shots(two, 1)
	assert_float(VarietyCKit.taken(two, a)).is_equal(400.0)
	var three: SimWorld = _lance(3)
	var b: int = ArsenalWKit.foe(three, Ids.EN_SKITTER, 10.0, 0.0, true)
	ArsenalWKit.run_until_shots(three, 1)
	assert_float(VarietyCKit.taken(three, b)).is_equal_approx(320.0 * 1.55, 1e-3)
	assert_int(ArsenalSystem.magazine_size_of(three, 0)).is_equal(4)
	var shots: Array[int] = ArsenalWKit.shot_ticks(three, 400)
	assert_array(shots).is_equal([267, 400, 534])  # a fourth round: the reload starts with the shot of tick 534
	assert_array(VarietyCKit.ticks_of(three, SimEventKind.Id.RELOAD_STARTED)).is_equal([534])


func test_leveling_up_adds_the_extra_round_to_a_magazine_in_use() -> void:
	var w: SimWorld = _lance()
	assert_int(w.arsenal.slot_magazine[0]).is_equal(3)
	ArsenalSystem.level_up(w, 0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(3)  # level 2 changes nothing
	ArsenalSystem.level_up(w, 0)
	assert_int(w.arsenal.slot_magazine[0]).is_equal(4)  # level 3: a fourth round
	ArsenalSystem.level_up(w, 0)
	assert_int(w.arsenal.slot_level[0]).is_equal(3)  # the cap
	assert_int(w.arsenal.slot_magazine[0]).is_equal(4)
