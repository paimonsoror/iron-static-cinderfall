extends GdUnitTestSuite
## The loader on the frozen baseline (WORK_PLAN rule 5): counts, conversions, errors.

var c: ContentSet


func before_test() -> void:
	c = TestContent.baseline()


func test_baseline_loads_without_errors() -> void:
	var r: ContentLoadResult = ContentLoader.load_from_dir(TestContent.BASELINE_DIR)
	assert_str("\n".join(r.errors)).is_empty()
	assert_object(r.content).is_not_null()


func test_counts() -> void:
	assert_int(c.enemies.size()).is_equal(4)
	assert_int(c.waves.size()).is_equal(5)
	assert_int(c.weapons.size()).is_equal(2)
	assert_int(c.upgrades.size()).is_equal(5)
	assert_int(c.abilities.size()).is_equal(3)


func test_wave_totals() -> void:
	var totals: Array[int] = []
	for w: WaveDef in c.waves:
		totals.append(w.total_count())
	assert_array(totals).is_equal([16, 36, 54, 76, 103])
	var peaks: Array[int] = []
	for w: WaveDef in c.waves:
		peaks.append(w.peak_target)
	assert_array(peaks).is_equal([10, 18, 28, 40, 50])


func test_wave_group_tick_conversion() -> void:
	var g: SpawnGroupDef = c.waves[0].groups[0]
	assert_int(g.enemy_index).is_equal(Ids.EN_SKITTER)
	assert_int(g.count).is_equal(16)
	assert_int(g.start_tick).is_equal(0)
	assert_int(g.interval_ticks).is_equal(102)
	assert_str(String(g.region_id)).is_equal("right")
	var boss: SpawnGroupDef = c.waves[4].groups[3]
	assert_int(boss.enemy_index).is_equal(Ids.EN_HULK)
	assert_int(boss.start_tick).is_equal(1080)
	assert_str(String(boss.region_id)).is_equal("upper_right")
	assert_int(c.waves[1].groups[1].start_tick).is_equal(480)
	assert_int(c.waves[1].groups[1].interval_ticks).is_equal(240)


func test_attack_slots_are_64_over_four_rings() -> void:
	assert_int(c.arena.slot_positions.size()).is_equal(64)
	assert_int(c.arena.slot_ring.size()).is_equal(64)
	var per_ring: Array[int] = [0, 0, 0, 0]
	for ring: int in c.arena.slot_ring:
		per_ring[ring] += 1
	assert_array(per_ring).is_equal([10, 14, 18, 22])
	assert_int(c.arena.slot_ring[0]).is_equal(0)
	assert_int(c.arena.slot_ring[10]).is_equal(1)
	assert_int(c.arena.slot_ring[24]).is_equal(2)
	assert_int(c.arena.slot_ring[42]).is_equal(3)
	assert_int(c.arena.slot_ring[63]).is_equal(3)


func test_slot_positions_follow_the_angle_convention() -> void:
	# ring 0: 10 slots over -40..130 deg; slot 0 at -40 + 0.5 * 17 = -31.5 deg, radius 3.0 around the core
	var a: float = deg_to_rad(-31.5)
	var expected: Vector2 = Vector2(-7.5 + 3.0 * cos(a), 3.0 - 3.0 * sin(a))
	var got: Vector2 = c.arena.slot_positions[0]
	assert_float(got.x).is_equal_approx(expected.x, 0.0001)
	assert_float(got.y).is_equal_approx(expected.y, 0.0001)
	for p: Vector2 in c.arena.slot_positions:
		var d: float = p.distance_to(Vector2(c.arena.core_x, c.arena.core_z))
		assert_float(d).is_between(2.99, 6.61)


func test_mission_conversions() -> void:
	var m: MissionDef = c.mission
	assert_float(m.core_max_hp).is_equal(1000.0)
	assert_int(m.ticks_per_second).is_equal(60)
	assert_int(m.enemy_cap).is_equal(50)
	assert_int(m.intermission_ticks).is_equal(480)
	assert_int(m.prepare_ticks).is_equal(180)
	assert_int(m.lock_ticks).is_equal(24)
	assert_int(m.eta_bucket_ticks).is_equal(30)
	assert_int(m.stuck_ticks).is_equal(240)
	assert_int(m.max_spawns_per_tick).is_equal(4)
	assert_float(m.stuck_min_progress_m).is_equal(0.5)
	assert_float(m.target_duration_min_s).is_equal(270.0)
	assert_float(m.target_duration_max_s).is_equal(360.0)
	assert_int(m.reward_victory_base).is_equal(100)
	assert_int(m.reward_core_hp_divisor).is_equal(20)
	assert_int(m.reward_defeat_per_wave).is_equal(10)


func test_enemy_defs() -> void:
	var sk: EnemyDef = c.enemy(&"skitter")
	assert_float(sk.hp).is_equal(45.0)
	assert_int(sk.attack_period_ticks).is_equal(90)
	assert_int(sk.weave_period_ticks).is_equal(72)
	assert_float(sk.radius).is_equal(0.35)
	assert_int(sk.scrap).is_equal(20)
	var hulk: EnemyDef = c.enemy(&"siege_hulk")
	assert_bool(hulk.is_boss).is_true()
	assert_int(hulk.slot_span).is_equal(3)
	assert_int(hulk.attack_period_ticks).is_equal(150)
	assert_bool(c.enemy(&"rusher").priority_class).is_true()
	assert_bool(c.enemy(&"rusher").direct_seek).is_true()
	assert_object(c.enemy(&"nope")).is_null()
	for i: int in c.enemies.size():
		assert_int(c.enemies[i].index).is_equal(i)
		assert_str(String(c.enemies[i].id)).is_equal(String(Ids.ENEMIES[i]))


func test_weapon_defs() -> void:
	var pistol: WeaponDef = c.weapon(&"pistol")
	assert_int(pistol.sps_milli).is_equal(2000)
	assert_int(pistol.magazine).is_equal(12)
	assert_int(pistol.reload_ticks).is_equal(75)
	assert_float(pistol.range_m).is_equal(25.0)
	var smg: WeaponDef = c.weapon(&"smg")
	assert_int(smg.sps_milli).is_equal(6000)
	assert_int(smg.reload_ticks).is_equal(96)
	assert_float(smg.damage).is_equal(15.0)


func test_upgrade_defs() -> void:
	var smg: UpgradeDef = c.upgrade(&"smg_unlock")
	assert_int(smg.base_cost).is_equal(300)
	assert_int(smg.min_wave).is_equal(2)
	assert_int(smg.kind).is_equal(UpgradeDef.Kind.WEAPON_UNLOCK)
	assert_int(smg.weapon_index).is_equal(1)
	var turret: UpgradeDef = c.upgrade(&"auto_turret")
	assert_int(turret.kind).is_equal(UpgradeDef.Kind.TURRET)
	assert_int(turret.max_level).is_equal(2)
	assert_int(turret.turret_sps_milli).is_equal(3000)
	assert_int(turret.turret_lock_ticks).is_equal(24)
	assert_float(turret.turret_range_m).is_equal(17.0)
	assert_float(turret.turret_damage).is_equal(12.0)
	assert_float(c.upgrade(&"armor_piercing").cap).is_equal(0.9)
	assert_int(c.upgrade(&"damage").weapon_index).is_equal(-1)


func test_ability_defs() -> void:
	var emp: AbilityDef = c.ability(&"emp")
	assert_int(emp.cooldown_ticks).is_equal(2100)
	assert_int(emp.stun_ticks).is_equal(180)
	assert_int(emp.boss_stun_ticks).is_equal(60)
	assert_int(emp.boss_immunity_ticks).is_equal(300)
	assert_int(emp.cooldown_start).is_equal(AbilityDef.CooldownStart.ON_ACTIVATE)
	var shield: AbilityDef = c.ability(&"shield")
	assert_float(shield.absorb).is_equal(100.0)
	assert_int(shield.duration_ticks).is_equal(480)
	assert_int(shield.cooldown_ticks).is_equal(3000)
	assert_int(shield.cooldown_start).is_equal(AbilityDef.CooldownStart.ON_END)
	var od: AbilityDef = c.ability(&"overdrive")
	assert_int(od.fire_rate_mult_milli).is_equal(2000)
	assert_int(od.duration_ticks).is_equal(360)
	assert_int(od.cooldown_ticks).is_equal(3600)


func test_arena_and_tokens() -> void:
	assert_int(c.arena.spawn_regions.size()).is_equal(2)
	assert_object(c.arena.region(&"right")).is_not_null()
	assert_object(c.arena.region(&"upper_right")).is_not_null()
	assert_object(c.arena.region(&"nope")).is_null()
	assert_int(c.arena.obstacles.size()).is_equal(4)
	assert_int(c.arena.turret_pads.size()).is_equal(2)
	assert_float(c.arena.approach_radius).is_equal(9.0)
	assert_float(c.arena.pitch_down_deg).is_equal(60.0)
	assert_str(c.tokens.color(&"core_amber").to_html(false).to_upper()).is_equal("F1A34A")
	assert_str(c.tokens.color(&"obsidian").to_html(false).to_upper()).is_equal("101820")
	assert_int(c.tokens.palette.size()).is_equal(6)
	assert_float(c.tokens.top_hud_fraction).is_equal(0.11)
	assert_int(c.tokens.touch_target_min_dp).is_equal(48)


func test_obstacle_contains() -> void:
	var drums: ObstacleDef = c.arena.obstacles[3]
	assert_bool(drums.contains(drums.x + 0.9, drums.z, 0.0)).is_true()
	assert_bool(drums.contains(drums.x + 1.1, drums.z, 0.0)).is_false()
	assert_bool(drums.contains(drums.x + 1.1, drums.z, 0.2)).is_true()
	var barrier: ObstacleDef = c.arena.obstacles[0]
	assert_bool(barrier.contains(barrier.x, barrier.z, 0.0)).is_true()
	assert_bool(barrier.contains(barrier.x + 5.0, barrier.z, 0.0)).is_false()


func test_strings_loaded_and_complete_for_content() -> void:
	assert_str(c.strings["enemy.skitter.name"]).is_equal("Skitter")
	assert_str(c.strings["upgrade.smg_unlock.name"]).is_equal("SMG")
	for id: StringName in Ids.ABILITIES:
		assert_bool(c.strings.has("ability.%s.name" % String(id))).is_true()
	for key: String in Reason.KEYS:
		assert_bool(c.strings.has(key)).is_true()


func test_unknown_enemy_in_waves_is_reported() -> void:
	var dir: String = TestContent.BASELINE_DIR
	var waves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/waves.json"))
	var bad_waves: Array = waves["waves"]
	var w0: Dictionary = bad_waves[0]
	var groups: Array = w0["groups"]
	var g0: Dictionary = groups[0]
	g0["enemy"] = "gremlin"
	var r: ContentLoadResult = ContentLoader.build(
		_json(dir + "/vertical_slice_balance.json"),
		waves,
		_json(dir + "/visual_tokens.json"),
		_json(dir + "/content_ext.json"),
		_json(dir + "/arena.json"),
		{}
	)
	assert_object(r.content).is_null()
	assert_bool(r.errors.size() > 0).is_true()
	assert_str("\n".join(r.errors)).contains("gremlin")
	assert_str("\n".join(r.errors)).contains("waves.json")


func test_missing_directory_is_reported() -> void:
	var r: ContentLoadResult = ContentLoader.load_from_dir("res://tests/fixtures/does_not_exist")
	assert_object(r.content).is_null()
	assert_bool(r.errors.size() > 0).is_true()


func _json(path: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d
