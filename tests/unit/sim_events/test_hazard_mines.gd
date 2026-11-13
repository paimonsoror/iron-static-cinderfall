extends GdUnitTestSuite
## V4-V: mines on the ground (the `mine_layer` directive lays them; CONTENT 3): 90 damage within 2 m, three per turret pad,
## set off by the first living enemy within 0.9 m, the blast landing on the next tick.


func test_a_mine_waits_until_an_enemy_comes_within_the_trigger_distance_and_then_blasts_next_tick() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	assert_bool(HazardMines.place(w, 3.0, 3.0, 1)).is_true()
	var passer: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, 4.0)  # 1.0 m: outside 0.9
	var edge: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, 4.8)  # 1.8 m from the mine, inside the blast
	var out: int = VarietyVKit.place(w, Ids.EN_HOLLOW, 3.0, 5.2)  # 2.2 m, outside
	for i: int in [passer, edge, out]:
		VarietyVKit.tough(w, i)
	VarietyVKit.run(w, 5)
	assert_int(HazardMines.count(w)).is_equal(1)
	w.enemies.z[passer] = 3.8  # 0.8 m
	VarietyVKit.tick(w)  # tick 6: the mine goes off
	assert_int(HazardMines.count(w)).is_equal(0)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(0)
	VarietyVKit.tick(w)  # tick 7
	var blast: SimEvent = VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST)[0]
	assert_int(blast.a).is_equal(HazardState.K_MINE)
	assert_int(blast.b).is_equal(200)
	assert_int(blast.tick).is_equal(7)
	assert_float(VarietyVKit.taken(w, passer)).is_greater(80.0)  # 90 less the armor of 8
	assert_float(VarietyVKit.taken(w, edge)).is_greater(0.0)
	assert_float(VarietyVKit.taken(w, out)).is_equal(0.0)
	assert_float(w.combat.damage_by_source[DamageSource.Id.TURRET_0 + 1]).is_greater(0.0)  # credited to the pad that laid it


func test_a_pad_holds_three_mines_at_most_and_each_pad_has_its_own_three() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	for k: int in 3:
		assert_bool(HazardMines.place(w, float(k), 0.0, 0)).is_true()
	assert_bool(HazardMines.place(w, 5.0, 0.0, 0)).is_false()
	assert_bool(HazardMines.place(w, 5.0, 0.0, 1)).is_true()
	assert_int(HazardMines.count(w)).is_equal(4)


func test_one_enemy_sets_off_one_mine_per_tick_for_each_mine_it_stands_on() -> void:
	var w: SimWorld = VarietyVKit.world(1, 4)
	var _a: bool = HazardMines.place(w, 4.0, 4.0, 0)
	var _b: bool = HazardMines.place(w, 4.3, 4.0, 0)
	var _c: bool = HazardMines.place(w, 8.0, 4.0, 0)
	VarietyVKit.tough(w, VarietyVKit.place(w, Ids.EN_HOLLOW, 4.1, 4.0))
	VarietyVKit.run(w, 3)
	assert_int(HazardMines.count(w)).is_equal(1)  # the two it stood on are gone, the far one waits
	assert_int(VarietyVKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(2)
