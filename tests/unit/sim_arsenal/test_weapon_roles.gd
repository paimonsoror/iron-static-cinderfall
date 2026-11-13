extends GdUnitTestSuite
## V4-W: the roles of the ten weapons (VARIETY_SPEC 3.2) as facts a bot can pick by (V4-T). Two fixed scenes, one volley each:
## a column of six skitters 1.4 m apart on the aim line (5.0 to 12.0 m from the Warden): how many enemies one volley hurts; and
## one Siege Hulk (armor 12) 8 m away: how much one volley takes off it. Delayed hits are given time to land.


func _column(weapon: int) -> SimWorld:
	var w: SimWorld = ArsenalWKit.world(weapon)
	for k: int in 6:
		ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0 + 1.4 * float(k), 0.0, k == 0)
	return w


func _volley(w: SimWorld) -> void:
	ArsenalWKit.run_until_shots(w, 1)
	ArsenalWKit.hold_fire(w)
	ArsenalWKit.run_both(w, 60)


func _hurt(w: SimWorld) -> int:
	var n: int = 0
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1 and VarietyCKit.taken(w, i) > 0.0:
			n += 1
	return n


func test_how_many_enemies_one_volley_hurts() -> void:
	var expected: Dictionary[int, int] = {
		Ids.WP_PISTOL: 1,  # reliable sidearm
		Ids.WP_SMG: 1,  # swarm trimmer: it wins on rate, not on reach
		Ids.WP_SCATTERGUN: 3,  # core defense: only what stands inside 9 m
		Ids.WP_ASSAULT_RIFLE: 2,  # generalist: the round passes into a second enemy
		Ids.WP_HORNET_RACK: 6,  # six targets at once
		Ids.WP_LMG: 1,  # suppression: one round, a stray still hurts one
		Ids.WP_SLAG_MORTAR: 3,  # area denial: the densest clump within 2.6 m
		Ids.WP_CUTTING_TORCH: 1,  # armor and boss melter
		Ids.WP_ARC_PROJECTOR: 5,  # chain lightning: the target and 4 jumps
		Ids.WP_RAIL_LANCE: 6,  # line execution: everything on the line
	}
	for weapon: int in expected:
		var w: SimWorld = _column(weapon)
		_volley(w)
		assert_int(_hurt(w)).override_failure_message("weapon %d hurt %d" % [weapon, _hurt(w)]).is_equal(expected[weapon])


func test_how_much_one_volley_takes_off_an_armored_boss() -> void:
	# armor 12: the pistol, SMG, rifle, LMG and the shotgun's pellets lose it from every hit; the torch and the arc lose
	# none, the lance half; the rack's six missiles and the shell lose it too
	var expected: Dictionary[int, float] = {
		Ids.WP_PISTOL: 18.0,
		Ids.WP_SMG: 3.0,
		Ids.WP_SCATTERGUN: 8.0,  # 8 pellets of 10: 1 each after armor
		Ids.WP_ASSAULT_RIFLE: 16.0,
		Ids.WP_HORNET_RACK: 72.0,  # 6 missiles x (24 - 12)
		Ids.WP_LMG: 8.0,
		Ids.WP_SLAG_MORTAR: 68.0,
		Ids.WP_CUTTING_TORCH: 4.0,
		Ids.WP_ARC_PROJECTOR: 40.0,
		Ids.WP_RAIL_LANCE: 314.0,
	}
	for weapon: int in expected:
		var w: SimWorld = ArsenalWKit.world(weapon)
		var hulk: int = ArsenalWKit.foe(w, Ids.EN_HULK, 8.0, 0.0, true)
		_volley(w)
		assert_float(VarietyCKit.taken(w, hulk)).override_failure_message("weapon %d took %f" % [weapon, VarietyCKit.taken(w, hulk)]).is_equal_approx(expected[weapon], 1e-3)


func test_the_roles_use_all_seven_firing_kinds_and_five_tiers() -> void:
	var kinds: Dictionary[int, bool] = {}
	var tiers: Dictionary[int, bool] = {}
	for def: WeaponDef in TestContent.variety().weapons:
		kinds[def.kind] = true
		tiers[def.tier] = true
	assert_int(kinds.size()).is_equal(WeaponDef.KIND_NAMES.size())
	assert_int(tiers.size()).is_equal(5)


func test_only_the_heat_weapons_have_no_magazine() -> void:
	for def: WeaponDef in TestContent.variety().weapons:
		assert_bool(def.is_heat()).is_equal(def.magazine == 0)
		assert_bool(def.is_heat()).is_equal(def.id in [&"cutting_torch", &"arc_projector"])


func test_the_shotgun_is_the_only_weapon_that_cannot_fire_beyond_ten_metres() -> void:
	for def: WeaponDef in TestContent.variety().weapons:
		assert_bool(def.range_m < 10.0).is_equal(def.id == &"scattergun")


func test_only_the_mortar_holds_fire_at_close_range() -> void:
	for def: WeaponDef in TestContent.variety().weapons:
		assert_bool(def.min_range_m > 0.0).is_equal(def.id == &"slag_mortar")
