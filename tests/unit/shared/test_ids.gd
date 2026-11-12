extends GdUnitTestSuite
## Fixed content ids (ARCH 4): the index is the position in these arrays, forever.


func test_enemy_ids_and_indices() -> void:
	assert_int(Ids.ENEMIES.size()).is_equal(18)
	assert_int(Ids.LEGACY_ENEMY_COUNT).is_equal(4)
	assert_int(Ids.enemy_index(&"skitter")).is_equal(Ids.EN_SKITTER)
	assert_int(Ids.enemy_index(&"hollow_warden")).is_equal(Ids.EN_HOLLOW)
	assert_int(Ids.enemy_index(&"rusher")).is_equal(Ids.EN_RUSHER)
	assert_int(Ids.enemy_index(&"siege_hulk")).is_equal(Ids.EN_HULK)


func test_upgrade_and_ability_indices() -> void:
	assert_int(Ids.UPGRADES.size()).is_equal(5)
	assert_int(Ids.upgrade_index(&"damage")).is_equal(Ids.UP_DAMAGE)
	assert_int(Ids.upgrade_index(&"smg_unlock")).is_equal(Ids.UP_SMG)
	assert_int(Ids.ABILITIES.size()).is_equal(3)
	assert_int(Ids.ability_index(&"overdrive")).is_equal(Ids.AB_OVERDRIVE)
	assert_int(Ids.weapon_index(&"smg")).is_equal(1)


func test_unknown_ids_give_minus_one() -> void:
	assert_int(Ids.enemy_index(&"nope")).is_equal(-1)
	assert_int(Ids.weapon_index(&"nope")).is_equal(-1)
	assert_int(Ids.upgrade_index(&"nope")).is_equal(-1)
	assert_int(Ids.ability_index(&"nope")).is_equal(-1)


func test_variety_ids_are_appended_and_keep_their_index_forever() -> void:
	var enemies: Array[StringName] = [
		&"skitter", &"hollow_warden", &"rusher", &"siege_hulk", &"mote", &"shard", &"burster", &"spitter", &"splitter",
		&"shieldbearer", &"reclaimer", &"jammer", &"borer", &"ward_pylon", &"brood_carrier", &"lance_platform",
		&"aegis_array", &"tremor_rig",
	]
	assert_array(Ids.ENEMIES).is_equal(enemies)
	var weapons: Array[StringName] = [
		&"pistol", &"smg", &"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch",
		&"arc_projector", &"rail_lance",
	]
	assert_array(Ids.WEAPONS).is_equal(weapons)
	assert_int(Ids.enemy_index(&"mote")).is_equal(Ids.EN_MOTE)
	assert_int(Ids.enemy_index(&"burster")).is_equal(Ids.EN_BURSTER)
	assert_int(Ids.enemy_index(&"tremor_rig")).is_equal(Ids.EN_TREMOR_RIG)
	assert_int(Ids.EN_TREMOR_RIG).is_equal(17)
	assert_int(Ids.weapon_index(&"arc_projector")).is_equal(Ids.WP_ARC_PROJECTOR)
	assert_int(Ids.WP_RAIL_LANCE).is_equal(9)
	assert_int(Ids.LEGACY_WEAPON_COUNT).is_equal(2)
