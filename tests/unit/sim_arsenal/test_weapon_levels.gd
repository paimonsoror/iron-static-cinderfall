extends GdUnitTestSuite
## V4-W: weapon levels 1 to 3 (CONTENT 2): the damage multipliers, the level-3 perks as WeaponPerks applies them, and the
## ten entries of the frozen variety fixture against the table of CONTENT 2 (data/weapons.json is its byte copy).


func _def(weapon: int) -> WeaponDef:
	return TestContent.variety().weapons[weapon]


func test_every_weapon_multiplies_damage_by_1_00_1_25_and_1_55() -> void:
	for def: WeaponDef in TestContent.variety().weapons:
		assert_float(def.level_mult[0]).is_equal(1.0)
		assert_float(def.level_mult[1]).is_equal(1.25)
		assert_float(def.level_mult[2]).is_equal_approx(1.55, 1e-5)


func test_below_level_three_the_shared_def_is_fired_with() -> void:
	for def: WeaponDef in TestContent.variety().weapons:
		assert_object(WeaponPerks.effective(def, 1)).is_same(def)
		assert_object(WeaponPerks.effective(def, 2)).is_same(def)


func _perk(content: ContentSet, weapon: int) -> WeaponDef:
	return WeaponPerks.effective(content.weapons[weapon], 3)


func test_the_level_three_perks() -> void:
	var content: ContentSet = TestContent.variety()
	assert_int(_perk(content, Ids.WP_SMG).magazine).is_equal(45)
	assert_int(_perk(content, Ids.WP_SCATTERGUN).pellets).is_equal(12)
	assert_int(_perk(content, Ids.WP_ASSAULT_RIFLE).pierce).is_equal(2)
	assert_int(_perk(content, Ids.WP_HORNET_RACK).salvo).is_equal(8)
	assert_int(_perk(content, Ids.WP_LMG).spin_up_ticks).is_equal(0)
	assert_int(_perk(content, Ids.WP_SLAG_MORTAR).pool_ticks).is_equal(360)
	assert_float(_perk(content, Ids.WP_CUTTING_TORCH).ramp_cap).is_equal(22.0)
	assert_int(_perk(content, Ids.WP_ARC_PROJECTOR).chains).is_equal(6)
	assert_int(_perk(content, Ids.WP_RAIL_LANCE).magazine).is_equal(4)
	var pistol: WeaponDef = content.weapons[Ids.WP_PISTOL]
	assert_float(WeaponPerks.level_value(pistol, 3, &"crit_every", 0.0)).is_equal(6.0)
	assert_float(WeaponPerks.level_value(pistol, 3, &"crit_mult", 1.0)).is_equal(3.0)
	assert_float(WeaponPerks.level_value(pistol, 2, &"crit_every", 0.0)).is_equal(0.0)


func test_a_perk_changes_only_its_own_field_and_never_the_shared_def() -> void:
	var content: ContentSet = TestContent.variety()
	for def: WeaponDef in content.weapons:
		var made: WeaponDef = WeaponPerks.effective(def, 3)
		assert_object(made).is_not_same(def)
		for prop: Dictionary in def.get_property_list():
			var usage: int = prop["usage"]
			var prop_name: String = prop["name"]
			if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or def.level3.has(StringName(prop_name)):
				continue
			if prop_name in ["spin_up_ticks", "pool_ticks", "level3"]:
				continue  # renamed in the data (spin_up_s, pool_seconds)
			assert_that(made.get(prop_name)).is_equal(def.get(prop_name))
	assert_int(content.weapons[Ids.WP_SCATTERGUN].pellets).is_equal(8)
	assert_int(content.weapons[Ids.WP_LMG].spin_up_ticks).is_equal(90)
	assert_int(content.weapons[Ids.WP_SLAG_MORTAR].pool_ticks).is_equal(240)


func test_the_damage_triple_copy_keeps_everything_else() -> void:
	var pistol: WeaponDef = _def(Ids.WP_PISTOL)
	var tripled: WeaponDef = WeaponPerks.scaled(pistol, 3.0)
	assert_float(tripled.damage).is_equal(90.0)
	assert_int(tripled.magazine).is_equal(pistol.magazine)
	assert_float(pistol.damage).is_equal(30.0)


func test_a_weapon_given_to_a_slot_starts_at_level_one_and_the_level_caps_at_three() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_SCATTERGUN, 3)
	assert_int(w.arsenal.slot_level[0]).is_equal(3)
	ArsenalSystem.level_up(w, 0)
	assert_int(w.arsenal.slot_level[0]).is_equal(3)
	ArsenalSystem.give_weapon(w, 0, Ids.WP_SCATTERGUN)
	assert_int(w.arsenal.slot_level[0]).is_equal(1)
	ArsenalSystem.level_up(w, 1)  # an empty slot: nothing happens
	assert_int(w.arsenal.slot_level[1]).is_equal(1)


func test_the_extended_feed_modifier_applies_to_the_level_three_magazine() -> void:
	var w: SimWorld = ArsenalWKit.world(Ids.WP_RAIL_LANCE, 3)
	w.mods.w_mag_mul = 1.5
	assert_int(ArsenalSystem.magazine_size_of(w, 0)).is_equal(6)  # 4 x 1.5


# --- the fixture against CONTENT 2 ---


func test_the_table_of_content_2() -> void:
	var c: ContentSet = TestContent.variety()
	# weapon index: [tier, kind, damage, sps_milli, magazine, reload_ticks, range_m]
	var rows: Dictionary[int, Array] = {
		Ids.WP_PISTOL: [1, WeaponDef.Kind.HITSCAN, 30.0, 2000, 12, 75, 25.0],
		Ids.WP_SMG: [2, WeaponDef.Kind.HITSCAN, 15.0, 6000, 30, 96, 25.0],
		Ids.WP_SCATTERGUN: [2, WeaponDef.Kind.CONE, 10.0, 1200, 6, 144, 9.0],
		Ids.WP_ASSAULT_RIFLE: [3, WeaponDef.Kind.HITSCAN, 28.0, 4500, 30, 108, 25.0],
		Ids.WP_HORNET_RACK: [3, WeaponDef.Kind.MISSILES, 24.0, 450, 4, 192, 22.0],
		Ids.WP_LMG: [4, WeaponDef.Kind.HITSCAN, 20.0, 10000, 150, 228, 25.0],
		Ids.WP_SLAG_MORTAR: [4, WeaponDef.Kind.SHELL, 80.0, 800, 4, 144, 24.0],
		Ids.WP_CUTTING_TORCH: [4, WeaponDef.Kind.BEAM, 4.0, 10000, 0, 0, 13.0],
		Ids.WP_ARC_PROJECTOR: [5, WeaponDef.Kind.ARC, 40.0, 1600, 0, 0, 18.0],
		Ids.WP_RAIL_LANCE: [5, WeaponDef.Kind.LINE, 320.0, 450, 3, 156, 30.0],
	}
	for weapon: int in rows:
		var d: WeaponDef = c.weapons[weapon]
		var row: Array = rows[weapon]
		assert_int(d.tier).is_equal(row[0])
		assert_int(d.kind).is_equal(row[1])
		assert_float(d.damage).is_equal(row[2])
		assert_int(d.sps_milli).is_equal(row[3])
		assert_int(d.magazine).is_equal(row[4])
		assert_int(d.reload_ticks).is_equal(row[5])
		assert_float(d.range_m).is_equal(row[6])


func test_the_special_fields_of_content_2() -> void:
	var c: ContentSet = TestContent.variety()
	var gun: WeaponDef = c.weapons[Ids.WP_SCATTERGUN]
	assert_float(gun.spread_deg).is_equal(30.0)
	assert_int(gun.pellets).is_equal(8)
	assert_float(gun.knockback_m).is_equal(0.8)
	var rifle: WeaponDef = c.weapons[Ids.WP_ASSAULT_RIFLE]
	assert_int(rifle.pierce).is_equal(1)
	assert_float(rifle.pierce_falloff).is_equal_approx(0.6, 1e-5)
	var rack: WeaponDef = c.weapons[Ids.WP_HORNET_RACK]
	assert_int(rack.salvo).is_equal(6)
	assert_int(rack.flight_ticks).is_equal(30)
	assert_float(rack.splash_damage).is_equal(10.0)
	assert_float(rack.area_m).is_equal_approx(1.2, 1e-5)
	var lmg: WeaponDef = c.weapons[Ids.WP_LMG]
	assert_int(lmg.spin_up_ticks).is_equal(90)
	assert_int(lmg.sps_min_milli).is_equal(4000)
	assert_float(lmg.stray_chance).is_equal_approx(0.25, 1e-5)
	assert_float(lmg.armor_shred).is_equal_approx(0.5, 1e-5)
	assert_float(lmg.spread_deg).is_equal(5.0)
	var mortar: WeaponDef = c.weapons[Ids.WP_SLAG_MORTAR]
	assert_float(mortar.min_range_m).is_equal(6.0)
	assert_float(mortar.area_m).is_equal_approx(2.6, 1e-5)
	assert_float(mortar.edge_frac).is_equal_approx(0.5, 1e-5)
	assert_int(mortar.flight_ticks).is_equal(42)
	assert_int(mortar.pool_ticks).is_equal(240)
	assert_float(mortar.pool_dps).is_equal(15.0)
	assert_float(mortar.pool_slow).is_equal_approx(0.25, 1e-5)
	assert_float(mortar.pool_radius_m).is_equal_approx(2.2, 1e-5)
	var torch: WeaponDef = c.weapons[Ids.WP_CUTTING_TORCH]
	assert_float(torch.ramp_per_hit).is_equal_approx(0.5, 1e-5)
	assert_float(torch.ramp_cap).is_equal(16.0)
	assert_float(torch.armor_ignore).is_equal(1.0)
	assert_int(torch.heat_per_shot).is_equal(3)
	assert_int(torch.cool_per_s).is_equal(25)
	assert_int(torch.heat_cap).is_equal(100)
	assert_int(torch.vent_ticks).is_equal(120)
	var arc: WeaponDef = c.weapons[Ids.WP_ARC_PROJECTOR]
	assert_int(arc.chains).is_equal(4)
	assert_float(arc.chain_range_m).is_equal(3.0)
	assert_float(arc.chain_falloff).is_equal_approx(0.75, 1e-5)
	assert_float(arc.ward_mult).is_equal(3.0)
	assert_float(arc.stunned_mult).is_equal(1.5)
	assert_int(arc.heat_per_shot).is_equal(14)
	assert_int(arc.cool_per_s).is_equal(20)
	assert_int(arc.vent_ticks).is_equal(150)
	var rail: WeaponDef = c.weapons[Ids.WP_RAIL_LANCE]
	assert_int(rail.charge_ticks).is_equal(60)
	assert_int(rail.pierce).is_equal(-1)
	assert_float(rail.area_m).is_equal(0.5)
	assert_float(rail.armor_ignore).is_equal(0.5)


func test_the_raw_damage_per_second_of_content_2() -> void:
	var c: ContentSet = TestContent.variety()
	var gun: WeaponDef = c.weapons[Ids.WP_SCATTERGUN]
	assert_float(gun.damage * float(gun.pellets) * float(gun.sps_milli) / 1000.0).is_equal_approx(96.0, 1e-5)
	var rack: WeaponDef = c.weapons[Ids.WP_HORNET_RACK]
	assert_float(rack.damage * float(rack.salvo) * float(rack.sps_milli) / 1000.0).is_equal_approx(64.8, 1e-5)
	var rifle: WeaponDef = c.weapons[Ids.WP_ASSAULT_RIFLE]
	assert_float(rifle.damage * float(rifle.sps_milli) / 1000.0).is_equal_approx(126.0, 1e-5)
	var lmg: WeaponDef = c.weapons[Ids.WP_LMG]
	assert_float(lmg.damage * float(lmg.sps_milli) / 1000.0).is_equal_approx(200.0, 1e-5)
	var mortar: WeaponDef = c.weapons[Ids.WP_SLAG_MORTAR]
	assert_float(mortar.damage * float(mortar.sps_milli) / 1000.0).is_equal_approx(64.0, 1e-5)
	var torch: WeaponDef = c.weapons[Ids.WP_CUTTING_TORCH]
	assert_float(torch.damage * float(torch.sps_milli) / 1000.0).is_equal_approx(40.0, 1e-5)
	assert_float(torch.ramp_cap * float(torch.sps_milli) / 1000.0).is_equal_approx(160.0, 1e-5)
	var rail: WeaponDef = c.weapons[Ids.WP_RAIL_LANCE]
	assert_float(rail.damage * float(rail.sps_milli) / 1000.0).is_equal_approx(144.0, 1e-5)


func test_the_swap_and_holster_numbers() -> void:
	var c: ContentSet = TestContent.variety()
	assert_int(c.run.swap_ticks).is_equal(24)
	assert_float(c.run.holster_reload_mult).is_equal(0.5)
