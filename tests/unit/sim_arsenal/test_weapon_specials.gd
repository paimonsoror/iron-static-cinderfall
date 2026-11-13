extends GdUnitTestSuite
## V4-W: the specials of the hitscan weapons around FireHitscan (VARIETY_SPEC 3.3, CONTENT 2): the LMG's spin-up, strays and
## armor shred, the assault rifle's second pierce at level 3, the pistol's guaranteed x3 hit at level 3 and the SMG's
## larger magazine at level 3. Skitter: 45 hp, armor 0; Hollow Warden: 150 hp, armor 8; Siege Hulk: armor 12.


# --- LMG ---


func test_lmg_spin_up_starts_at_4_a_second_and_reaches_10_after_90_ticks_of_fire() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 240)
	assert_int(ticks[0]).is_equal(14)  # 4.0 a second climbing: 62,067 milli banked after 14 ticks
	assert_int(ticks[1]).is_equal(25)  # the second shot comes after 11 ticks: the rate is still climbing
	var tail: int = ticks.size() - 1
	for k: int in range(tail - 4, tail + 1):
		assert_int(ticks[k] - ticks[k - 1]).is_equal(6)  # 10 a second at full spin
	assert_int(w.arsenal.spin_ticks).is_equal(90)


func test_one_second_without_fire_starts_the_spin_up_again() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	var t: int = ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	VarietyCKit.run_weapon(w, 100)
	assert_int(w.arsenal.spin_ticks).is_equal(90)
	w.kill_enemy(t, DamageSource.Id.WARDEN)
	VarietyCKit.run_weapon(w, 59)
	assert_int(w.arsenal.spin_ticks).is_equal(90)
	VarietyCKit.run_weapon(w, 1)
	assert_int(w.arsenal.spin_ticks).is_equal(0)
	# a target within the second keeps the spin
	var again: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	var first: int = ArsenalWKit.foe(again, Ids.EN_HULK, 8.0, 0.0, true)
	VarietyCKit.run_weapon(again, 100)
	again.kill_enemy(first, DamageSource.Id.WARDEN)
	VarietyCKit.run_weapon(again, 30)
	ArsenalWKit.foe(again, Ids.EN_HULK, 9.0, 0.0, true)
	VarietyCKit.run_weapon(again, 2)
	assert_int(again.arsenal.spin_ticks).is_equal(90)
	assert_int(again.arsenal.idle_ticks).is_equal(0)


func test_level_three_has_no_spin_up() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG, 3)
	ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	var ticks: Array[int] = ArsenalWKit.shot_ticks(w, 40)
	assert_array(ticks).is_equal([6, 12, 18, 24, 30, 36])


func test_a_stray_goes_to_a_neighbour_within_1_5_metres_and_draws_only_from_the_aim_stream() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	w.content.weapons[Ids.WP_LMG].stray_chance = 1.0
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	var near: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.5, 0.5, false)  # 0.71 m from the target
	var far: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 3.0, false)  # 3 m: out of reach
	ArsenalWKit.run_until_shots(w, 1)
	assert_float(VarietyCKit.taken(w, near)).is_equal(20.0)
	assert_float(VarietyCKit.taken(w, t)).is_equal(0.0)
	assert_float(VarietyCKit.taken(w, far)).is_equal(0.0)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.SHOT_FIRED)[0].b).is_equal(w.enemies.id[near])
	assert_int(w.warden.target_id).is_equal(w.enemies.id[t])  # the lock stays on the real target
	var mirror: RandomNumberGenerator = SimRng.new(1).stream(&"aim")
	var _roll: float = mirror.randf()
	var _pick: int = mirror.randi_range(0, 0)
	assert_int(w.rng.stream(&"aim").state).is_equal(mirror.state)
	assert_bool(w.rng.names_sorted().has("proc")).is_false()


func test_a_stray_with_no_neighbour_hits_the_target_and_costs_one_draw() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	w.content.weapons[Ids.WP_LMG].stray_chance = 1.0
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 3.0)
	ArsenalWKit.run_until_shots(w, 3)
	assert_float(VarietyCKit.taken(w, t)).is_equal(60.0)
	var mirror: RandomNumberGenerator = SimRng.new(1).stream(&"aim")
	for _n: int in 3:
		var _roll: float = mirror.randf()
	assert_int(w.rng.stream(&"aim").state).is_equal(mirror.state)


func test_a_quarter_of_the_rounds_stray_and_every_round_lands_on_one_of_the_two() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	var near: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.5, 0.5, false)
	ArsenalWKit.run_until_shots(w, 150)
	var on_target: float = VarietyCKit.taken(w, t) / 20.0
	var strays: float = VarietyCKit.taken(w, near) / 20.0
	assert_float(on_target + strays).is_equal(150.0)
	assert_float(strays).is_between(20.0, 60.0)  # 25% of 150 is 37.5
	# the same seed gives the same split
	var again: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	ArsenalWKit.foe(again, Ids.EN_SKITTER, 8.0, 0.0, true)
	var near_again: int = ArsenalWKit.foe(again, Ids.EN_SKITTER, 8.5, 0.5, false)
	ArsenalWKit.run_until_shots(again, 150)
	assert_float(VarietyCKit.taken(again, near_again)).is_equal(VarietyCKit.taken(w, near))


func test_each_round_strips_half_an_armor_point_up_to_six() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_LMG)
	w.content.weapons[Ids.WP_LMG].stray_chance = 0.0
	var hulk: int = ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(w, 16)
	var dealt: Array[float] = ArsenalWKit.dealt(w)
	for k: int in 16:
		assert_float(dealt[k]).is_equal_approx(minf(14.0, 8.0 + 0.5 * float(k)), 1e-5)  # 20 less armor 12, 11.5, ... 6
	assert_int(w.ext.shred_milli[hulk]).is_equal(6000)
	assert_float(DamageResolver.effective_armor(w, hulk, 0)).is_equal(6.0)


# --- assault rifle, pistol, SMG ---


func _line_of_three(w: SimWorld) -> void:
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0, true)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 11.5, 0.1)  # 1.5 m behind, on the line
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 13.0, 0.2)  # 1.5 m behind that one


func test_the_assault_rifle_passes_into_a_second_enemy_and_at_level_three_a_third() -> void:
	var one: SimWorld = ArsenalWKit.world(Ids.WP_ASSAULT_RIFLE)
	_line_of_three(one)
	VarietyCKit.run_weapon(one, 14)
	assert_float(VarietyCKit.taken(one, 0)).is_equal(28.0)
	assert_float(VarietyCKit.taken(one, 1)).is_equal_approx(16.8, 1e-5)
	assert_float(VarietyCKit.taken(one, 2)).is_equal(0.0)
	var three: SimWorld = ArsenalWKit.world(Ids.WP_ASSAULT_RIFLE, 3)
	_line_of_three(three)
	VarietyCKit.run_weapon(three, 14)
	assert_float(VarietyCKit.taken(three, 0)).is_equal_approx(28.0 * 1.55, 1e-3)
	assert_float(VarietyCKit.taken(three, 1)).is_equal_approx(28.0 * 1.55 * 0.6, 1e-3)
	assert_float(VarietyCKit.taken(three, 2)).is_equal_approx(28.0 * 1.55 * 0.36, 1e-3)
	assert_int(VarietyCKit.count(three, SimEventKind.Id.SHOT_FIRED)).is_equal(1)


func test_the_pistol_at_level_three_hits_for_triple_on_every_sixth_shot() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL, 3)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(w, 18)  # a reload sits between the 12th and the 13th
	var dealt: Array[float] = ArsenalWKit.dealt(w)
	assert_int(dealt.size()).is_equal(18)
	for k: int in 18:
		var crit: bool = (k + 1) % 6 == 0
		assert_float(dealt[k]).is_equal_approx(30.0 * 1.55 * (3.0 if crit else 1.0), 1e-3)


func test_the_triple_hit_meets_the_armor_once() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL, 3)
	ArsenalWKit.foe(w, Ids.EN_HOLLOW, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(w, 6)
	var dealt: Array[float] = ArsenalWKit.dealt(w)
	assert_float(dealt[0]).is_equal_approx(30.0 * 1.55 - 8.0, 1e-3)
	assert_float(dealt[5]).is_equal_approx(30.0 * 1.55 * 3.0 - 8.0, 1e-3)  # not three hits of 38.5


func test_the_pistol_has_no_triple_hit_below_level_three() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_PISTOL, 2)
	ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(w, 12)
	for f: float in ArsenalWKit.dealt(w):
		assert_float(f).is_equal_approx(37.5, 1e-5)
	assert_int(w.arsenal.shots_since_proc).is_equal(0)


func test_the_smg_holds_45_rounds_at_level_three_and_a_level_up_adds_the_difference() -> void:
	var one: SimWorld = ArsenalWKit.world(Ids.WP_SMG)
	ArsenalWKit.foe(one, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(one, 30)
	assert_array(VarietyCKit.ticks_of(one, SimEventKind.Id.RELOAD_STARTED)).is_equal([one.tick])
	var three: SimWorld = ArsenalWKit.world(Ids.WP_SMG, 3)
	ArsenalWKit.foe(three, Ids.EN_HULK, 8.0, 0.0, true)
	ArsenalWKit.run_until_shots(three, 44)
	assert_int(VarietyCKit.count(three, SimEventKind.Id.RELOAD_STARTED)).is_equal(0)
	ArsenalWKit.run_until_shots(three, 45)
	assert_array(VarietyCKit.ticks_of(three, SimEventKind.Id.RELOAD_STARTED)).is_equal([three.tick])
	var leveled: SimWorld = ArsenalWKit.world(Ids.WP_SMG)
	ArsenalSystem.level_up(leveled, 0)
	assert_int(leveled.arsenal.slot_magazine[0]).is_equal(30)
	ArsenalSystem.level_up(leveled, 0)
	assert_int(leveled.arsenal.slot_magazine[0]).is_equal(45)
	assert_int(leveled.warden.magazine).is_equal(45)  # the mirror follows
