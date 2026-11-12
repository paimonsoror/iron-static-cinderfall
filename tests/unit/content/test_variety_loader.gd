extends GdUnitTestSuite
## V1-S: the loaders of the six variety files and arena.json schema 2 on the frozen variety fixture
## (tests/fixtures/data_variety): counts, conversions and id resolution, file by file.

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()


func test_the_variety_fixture_loads_and_validates() -> void:
	var r: ContentLoadResult = ContentLoader.load_from_dir(TestContent.VARIETY_DIR)
	assert_str("\n".join(r.errors)).is_empty()
	assert_str("\n".join(ContentValidator.validate(r.content))).is_empty()
	assert_bool(r.content.is_variety()).is_true()


func test_run_json_acts_and_waves() -> void:
	var run: RunDef = c.run
	assert_int(run.acts.size()).is_equal(3)
	assert_str(str(run.acts[0].id)).is_equal("act_yard")
	assert_float(run.act(2).hp_mult).is_equal_approx(1.35, 0.0001)
	assert_float(run.act(3).core_dmg_mult).is_equal_approx(1.3, 0.0001)
	assert_array(Array(run.acts[0].rarity_weights)).is_equal([70.0, 26.0, 4.0])
	assert_float(run.acts[0].corrupted_chance).is_equal_approx(0.12, 0.0001)
	assert_object(run.act(0)).is_null()
	assert_object(run.act(4)).is_null()
	assert_int(run.waves.size()).is_equal(5)
	var opener: WaveSlotDef = run.wave_slot(1)
	assert_int(opener.kind).is_equal(WaveSlotDef.Kind.OPENER)
	assert_int(opener.window_ticks).is_equal(22 * 60)
	assert_float(opener.budget).is_equal(24.0)
	assert_int(opener.fixed_pack_index).is_equal(run.pack_index(&"pack_tide"))
	assert_int(run.wave_slot(3).kind).is_equal(WaveSlotDef.Kind.NORMAL)
	assert_int(run.wave_slot(3).fixed_pack_index).is_equal(-1)
	assert_int(run.wave_slot(5).kind).is_equal(WaveSlotDef.Kind.BOSS)
	assert_int(run.wave_slot(4).peak_minis).is_equal(16)
	assert_object(run.wave_slot(6)).is_null()


func test_run_json_packs_modifiers_and_rewards() -> void:
	var run: RunDef = c.run
	assert_int(run.packs.size()).is_equal(3)
	var powder: PackDef = run.packs[run.pack_index(&"pack_powder")]
	assert_int(powder.group_count()).is_equal(3)
	assert_int(powder.group_enemy[0]).is_equal(Ids.EN_BURSTER)
	assert_int(powder.group_enemy[2]).is_equal(Ids.EN_MOTE)
	assert_float(powder.group_share[0]).is_equal_approx(0.35, 0.0001)
	assert_str(str(powder.group_region[2])).is_equal("upper_right")
	assert_float(powder.group_tempo[1]).is_equal_approx(0.8, 0.0001)
	assert_int(run.pack_index(&"pack_nope")).is_equal(-1)
	assert_int(run.modifiers.size()).is_equal(1)
	var volatile: ModifierDef = run.modifiers[run.modifier_index(&"mod_volatile")]
	assert_int(volatile.list).is_equal(ModifierDef.List.HOT)
	assert_int(volatile.ops[0].kind).is_equal(OpDef.Kind.FLAG)
	assert_str(str(volatile.ops[0].target)).is_equal("volatile_skitters")
	assert_int(run.route_rewards.size()).is_equal(8)
	var scrap: RewardDef = run.route_rewards[run.reward_index(&"rw_scrap")]
	assert_int(scrap.ops[0].kind).is_equal(OpDef.Kind.GRANT)
	assert_float(scrap.ops[0].amount(1)).is_equal(120.0)
	assert_float(scrap.ops[0].amount(2)).is_equal(200.0)
	assert_float(scrap.ops[0].amount(3)).is_equal(280.0)
	var charge: RewardDef = run.route_rewards[run.reward_index(&"rw_charge")]
	assert_str(str(charge.ops[0].arg)).is_equal("deadfall_strike")
	assert_float(charge.weight_standard).is_equal(0.0)
	assert_float(charge.weight_hot).is_equal(10.0)


func test_run_json_draft_salvage_caps_reward_and_mission() -> void:
	var run: RunDef = c.run
	assert_int(run.draft_offer_size).is_equal(3)
	assert_int(run.draft_skip_scrap).is_equal(60)
	assert_int(run.reroll_base + run.reroll_step).is_equal(100)
	assert_int(run.buyout_base).is_equal(250)
	assert_float(run.patch_frac).is_equal_approx(0.1, 0.0001)
	assert_int(run.patch_base + run.patch_step).is_equal(270)
	assert_float(run.tag_lean).is_equal(2.0)
	assert_int(run.rare_pity).is_equal(3)
	assert_int(run.salvage_secure_ticks).is_equal(720)
	assert_int(run.salvage_lifetime_ticks).is_equal(2400)
	assert_int(run.salvage_bank_max).is_equal(2)
	assert_array(Array(run.salvage_scrap_by_act)).is_equal([80, 140, 200])
	assert_float(run.tier_weight(1, 5)).is_equal(100.0)
	assert_float(run.tier_weight(2, 3)).is_equal(45.0)
	assert_float(run.tier_weight(3, 2)).is_equal(0.0)
	assert_float(run.tier_weight(4, 2)).is_equal(0.0)
	assert_int(run.swarm_cap).is_equal(40)
	assert_int(run.max_elites_alive).is_equal(4)
	assert_int(run.max_blasts_per_tick).is_equal(8)
	assert_int(run.reward_per_wave).is_equal(6)
	assert_array(Array(run.reward_boss_by_act)).is_equal([30, 45])
	assert_int(c.mission.swarm_cap).is_equal(40)
	assert_int(c.mission.breather_ticks).is_equal(180)
	assert_bool(c.mission.shop_enabled).is_false()
	assert_int(c.mission.enemy_cap).is_equal(50)  # the bodied cap is unchanged (decision D6)


func test_weapons_json_all_ten_weapons_in_id_order() -> void:
	assert_int(c.weapons.size()).is_equal(Ids.WEAPONS.size())
	for i: int in c.weapons.size():
		assert_str(str(c.weapons[i].id)).is_equal(String(Ids.WEAPONS[i]))
		assert_int(c.weapons[i].index).is_equal(i)
		assert_int(c.weapons[i].level_mult.size()).is_equal(3)
	var pistol: WeaponDef = c.weapons[Ids.WP_PISTOL]
	assert_float(pistol.damage).is_equal(30.0)  # the legacy numbers stay in the balance file
	assert_int(pistol.magazine).is_equal(12)
	assert_int(pistol.kind).is_equal(WeaponDef.Kind.HITSCAN)
	assert_int(c.weapons[Ids.WP_SMG].tier).is_equal(2)
	assert_float(c.weapons[Ids.WP_SMG].level3[&"magazine"]).is_equal(45.0)
	assert_int(c.run.swap_ticks).is_equal(24)
	assert_float(c.run.holster_reload_mult).is_equal(0.5)


func test_weapons_json_kind_specific_fields() -> void:
	var arc: WeaponDef = c.weapons[Ids.WP_ARC_PROJECTOR]
	assert_int(arc.kind).is_equal(WeaponDef.Kind.ARC)
	assert_int(arc.tier).is_equal(5)
	assert_int(arc.sps_milli).is_equal(1600)
	assert_int(arc.chains).is_equal(4)
	assert_float(arc.chain_range_m).is_equal(3.0)
	assert_float(arc.chain_falloff).is_equal(0.75)
	assert_bool(arc.is_heat()).is_true()
	assert_int(arc.heat_per_shot).is_equal(14)
	assert_int(arc.vent_ticks).is_equal(150)
	assert_float(arc.ward_mult).is_equal(3.0)
	var lmg: WeaponDef = c.weapons[Ids.WP_LMG]
	assert_int(lmg.sps_milli).is_equal(10000)
	assert_int(lmg.sps_min_milli).is_equal(4000)
	assert_int(lmg.spin_up_ticks).is_equal(90)
	var mortar: WeaponDef = c.weapons[Ids.WP_SLAG_MORTAR]
	assert_int(mortar.kind).is_equal(WeaponDef.Kind.SHELL)
	assert_int(mortar.flight_ticks).is_equal(42)
	assert_int(mortar.pool_ticks).is_equal(240)
	assert_float(mortar.pool_radius_m).is_equal_approx(2.2, 0.0001)
	assert_float(mortar.min_range_m).is_equal(6.0)
	var rail: WeaponDef = c.weapons[Ids.WP_RAIL_LANCE]
	assert_int(rail.pierce).is_equal(-1)
	assert_int(rail.charge_ticks).is_equal(60)
	assert_int(c.weapons[Ids.WP_SCATTERGUN].pellets).is_equal(8)
	assert_int(c.weapons[Ids.WP_HORNET_RACK].salvo).is_equal(6)
	assert_int(c.weapons[Ids.WP_CUTTING_TORCH].kind).is_equal(WeaponDef.Kind.BEAM)
	assert_int(c.turret_types.size()).is_equal(3)
	assert_str(str(c.turret_types[0].id)).is_equal("turret_gun")
	assert_int(c.turret_types[0].sps_milli).is_equal(3000)


func test_enemies_json_all_eighteen_enemies_in_id_order() -> void:
	assert_int(c.enemies.size()).is_equal(Ids.ENEMIES.size())
	for i: int in c.enemies.size():
		assert_str(str(c.enemies[i].id)).is_equal(String(Ids.ENEMIES[i]))
		assert_int(c.enemies[i].index).is_equal(i)
		assert_int(c.enemies[i].alive_cap).is_greater(0)
	var mote: EnemyDef = c.enemies[Ids.EN_MOTE]
	assert_bool(mote.is_mini()).is_true()
	assert_float(mote.hp).is_equal(12.0)
	assert_float(mote.cost).is_equal_approx(0.4, 0.0001)
	assert_int(mote.alive_cap).is_equal(40)
	var burster: EnemyDef = c.enemies[Ids.EN_BURSTER]
	assert_int(burster.enemy_class).is_equal(EnemyDef.BodyClass.BODIED)
	assert_float(burster.beh(&"death_blast_radius")).is_equal_approx(2.6, 0.0001)
	assert_float(burster.beh(&"death_blast_damage")).is_equal(90.0)
	assert_float(burster.beh(&"chain_delay_ticks")).is_equal(6.0)
	assert_float(burster.beh(&"nope", 7.0)).is_equal(7.0)
	var spitter: EnemyDef = c.enemies[Ids.EN_SPITTER]
	assert_int(spitter.enemy_class).is_equal(EnemyDef.BodyClass.STANDOFF)
	assert_float(spitter.standoff_m).is_equal(10.5)
	assert_float(c.enemies[Ids.EN_SPLITTER].beh(&"split_type")).is_equal(float(Ids.EN_SHARD))  # an id becomes its index
	assert_bool(c.enemies[Ids.EN_BROOD_CARRIER].is_boss).is_true()
	assert_int(c.enemies[Ids.EN_SPLITTER].min_act).is_equal(2)


func test_enemies_json_overrides_keep_the_legacy_numbers() -> void:
	var base: ContentSet = TestContent.baseline()
	for i: int in Ids.LEGACY_ENEMY_COUNT:
		assert_float(c.enemies[i].hp).is_equal(base.enemies[i].hp)
	# V3-I refreshed the fixture with the Scrap values of CONTENT 4.1 (20 / 35 / 25 became 5 / 15 / 8; the boss keeps its own)
	assert_int(c.enemies[Ids.EN_SKITTER].scrap).is_equal(5)
	assert_int(c.enemies[Ids.EN_HOLLOW].scrap).is_equal(15)
	assert_int(c.enemies[Ids.EN_RUSHER].scrap).is_equal(8)
	assert_int(c.enemies[Ids.EN_HULK].scrap).is_equal(base.enemies[Ids.EN_HULK].scrap)
	assert_int(c.enemies[Ids.EN_SKITTER].alive_cap).is_equal(50)
	assert_int(c.enemies[Ids.EN_HOLLOW].alive_cap).is_equal(24)
	assert_int(c.enemies[Ids.EN_RUSHER].alive_cap).is_equal(32)
	assert_float(c.enemies[Ids.EN_HOLLOW].cost).is_equal(3.0)


func test_enemies_json_elites_affixes_and_bosses() -> void:
	var run: RunDef = c.run
	assert_float(run.elite_hp_mult).is_equal_approx(2.2, 0.0001)
	assert_float(run.elite_scrap_mult).is_equal(4.0)
	assert_int(c.affixes.size()).is_equal(10)
	assert_int(c.affix_index(&"aff_plated")).is_equal(0)
	assert_int(c.affix_index(&"aff_shroud")).is_equal(9)
	assert_str(str(c.affixes[0].ops[0].target)).is_equal("armor_add")
	assert_int(run.forbid_a.size()).is_equal(3)
	assert_int(run.forbid_a[0]).is_equal(c.affix_index(&"aff_magnetic"))
	assert_int(run.forbid_b[0]).is_equal(c.affix_index(&"aff_shroud"))
	assert_int(run.forbid_until_act[1]).is_equal(3)
	assert_int(run.forbid_enemy[2]).is_equal(Ids.EN_RUSHER)
	assert_int(run.forbid_enemy[0]).is_equal(-1)
	assert_float(run.affix_two_chance[1]).is_equal_approx(0.4, 0.0001)
	assert_int(c.bosses.size()).is_equal(1)
	var hulk: BossDef = c.boss(&"siege_hulk")
	assert_int(hulk.enemy_index).is_equal(Ids.EN_HULK)
	assert_int(hulk.pool_act).is_equal(1)
	assert_float(hulk.beh(&"enrage_frac")).is_equal(0.25)
	assert_array(Array(hulk.escort_enemy)).is_equal([Ids.EN_SKITTER, Ids.EN_MOTE])
	assert_str(hulk.name_key).is_equal("boss.siege_hulk.name")
	assert_int(run.hulk_variants.size()).is_equal(3)


func test_directives_json() -> void:
	assert_int(c.directives.size()).is_equal(8)
	var ids: Array[String] = []
	for d: DirectiveDef in c.directives:
		ids.append(String(d.id))
		assert_int(d.index).is_equal(ids.size() - 1)
	assert_array(ids).is_equal([
		"hot_loads", "cyclic_tuning", "penetrator_cores", "turret_deploy", "reinforced_cage", "emp_capacitor",
		"incendiary_tips", "glass_cannon",
	])
	var hot: DirectiveDef = c.directive(&"hot_loads")
	assert_int(hot.category).is_equal(DirectiveDef.Category.WEAPON)
	assert_int(hot.rarity).is_equal(DirectiveDef.Rarity.COMMON)
	assert_int(hot.max_stacks).is_equal(5)
	assert_str(str(hot.ops[0].target)).is_equal("lvl_damage")
	assert_int(hot.ops[0].kind).is_equal(OpDef.Kind.ADD)
	assert_str(hot.name_key).is_equal("directive.hot_loads.name")
	assert_str(str(hot.pool)).is_equal("base")
	assert_float(c.directive(&"turret_deploy").requires[&"free_pad"]).is_equal(1.0)
	assert_str(str(c.directive(&"incendiary_tips").hook)).is_equal("on_warden_hit")
	var glass: DirectiveDef = c.directive(&"glass_cannon")
	assert_int(glass.rarity).is_equal(DirectiveDef.Rarity.CORRUPTED)
	assert_float(glass.ops[1].value).is_equal_approx(-0.3, 0.0001)
	assert_array(glass.tags).is_equal([&"bullet", &"rail"])
	assert_int(c.directive_index(&"glass_cannon")).is_equal(7)
	assert_object(c.directive(&"nope")).is_null()


func test_events_json() -> void:
	assert_int(c.events.size()).is_equal(1)
	var strike: EventDef = c.event_def(&"deadfall_strike")
	assert_int(strike.index).is_equal(0)
	assert_int(strike.who).is_equal(EventDef.Who.PLAYER)
	assert_int(strike.warn_ticks).is_equal(120)
	assert_bool(strike.harmful).is_false()
	assert_float(strike.param(&"damage")).is_equal(450.0)
	assert_float(strike.param(&"charge_cap")).is_equal(3.0)
	assert_float(strike.param(&"nope", 2.0)).is_equal(2.0)
	assert_int(c.event_index(&"core_vent")).is_equal(-1)
	assert_float(c.run.event_window_min).is_equal(0.25)
	assert_float(c.run.mercy_core_frac).is_equal_approx(0.15, 0.0001)
	var burn: Dictionary = c.run.hazards[&"burn"]
	assert_float(burn[&"seconds"]).is_equal(3.0)


func test_unlocks_json() -> void:
	assert_int(c.unlocks.size()).is_equal(5)
	var lmg: UnlockDef = c.unlock(&"u_w_lmg")
	assert_int(lmg.branch).is_equal(UnlockDef.Branch.ARMORY)
	assert_int(lmg.cost).is_equal(120)
	assert_array(lmg.grants).is_equal([&"lmg"])
	assert_int(c.kits.size()).is_equal(1)
	assert_int(c.kit_index(&"k_standard")).is_equal(0)
	assert_int(c.kits[0].cost).is_equal(0)
	assert_array(Array(c.run.tier_gates)).is_equal([3, 8])
	assert_int(c.run.milestones[&"ms_first_victory"]).is_equal(200)


func test_arena_schema_two_points() -> void:
	var a: ArenaDef = c.arena
	assert_int(a.drop_points.size()).is_equal(4)
	assert_int(a.breach_points.size()).is_equal(4)
	assert_int(a.drum_points.size()).is_equal(6)
	assert_array(Array(a.rail_z)).is_equal([-7.0, 10.5])
	assert_int(a.standoff_radii.size()).is_equal(3)
	assert_int(a.standoff_points.size()).is_greater(20)
	assert_int(a.standoff_points.size()).is_less(42)  # the candidates that fall on an obstacle are dropped
	assert_int(a.standoff_ring.size()).is_equal(a.standoff_points.size())
	for i: int in a.standoff_points.size():
		var p: Vector2 = a.standoff_points[i]
		assert_bool(ArenaBuilder.point_is_free(a, p.x, p.y, 0.6)).is_true()
		var d: float = p.distance_to(Vector2(a.core_x, a.core_z))
		assert_float(d).is_equal_approx(a.standoff_radii[a.standoff_ring[i]], 0.001)
	assert_int(a.slot_positions.size()).is_equal(64)  # the attack slots are unchanged


func test_variety_strings_are_loaded_and_cover_every_reason() -> void:
	assert_str(c.strings["draft.header"]).is_equal("LANTERN CELL // PATCH WINDOW")
	assert_str(c.strings["weapon.arc_projector.name"]).is_equal("Arc Projector")
	assert_str(c.strings["enemy.skitter.name"]).is_equal("Skitter")
	for key: String in Reason.KEYS:
		assert_bool(c.strings.has(key)).override_failure_message("missing " + key).is_true()


func test_a_missing_variety_file_is_reported() -> void:
	var docs: Dictionary = VarietyBadData.docs()
	docs.erase("events.json")
	var r: ContentLoadResult = VarietyBadData.build(docs)
	assert_object(r.content).is_null()
	assert_str("\n".join(r.errors)).contains("events.json: $: file missing from the variety set")
