extends GdUnitTestSuite
## V2-B: the ops interpreter and ModState (VARIETY_SPEC 13.1, 13.2): every op changes exactly its field, stacks, the
## recompute, the modifier of a wave, and a legacy world that is left alone.

var c: ContentSet
var w: SimWorld


func before_test() -> void:
	c = TestContent.variety()
	w = VarietyBKit.world_after(c, 3)


func _one(op: OpDef) -> Array[OpDef]:
	var ops: Array[OpDef] = [op]
	return ops


## Every stat of ModState by name.
func _stats(m: ModState) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for stat_name: String in OpDef.STATS:
		out[stat_name] = m.stat(StringName(stat_name))
	return out


func _mods_hash(m: ModState) -> String:
	var h: StateHasher = StateHasher.new()
	m.hash_into(h)
	return h.finish()


func _flags_on(m: ModState) -> int:
	var n: int = 0
	for bit: int in m.flags:
		n += bit
	return n


func test_every_add_op_changes_exactly_its_stat() -> void:
	for stat_name: String in OpDef.STATS:
		w.mods.reset()
		var before: Dictionary[String, float] = _stats(w.mods)
		ModSystem.apply_ops(w, _one(VarietyBKit.op_add(StringName(stat_name), 0.5)), 1)
		var after: Dictionary[String, float] = _stats(w.mods)
		for other: String in OpDef.STATS:
			var want: float = before[other] + (0.5 if other == stat_name else 0.0)
			assert_float(after[other]).override_failure_message("add %s moved %s" % [stat_name, other]).is_equal_approx(want, 0.00001)
		assert_int(_flags_on(w.mods)).is_equal(0)


func test_every_mul_op_changes_exactly_its_stat() -> void:
	for stat_name: String in OpDef.STATS:
		w.mods.reset()
		w.mods.set(stat_name, 3.0)
		var before: Dictionary[String, float] = _stats(w.mods)
		ModSystem.apply_ops(w, _one(VarietyBKit.op_mul(StringName(stat_name), 2.0)), 1)
		var after: Dictionary[String, float] = _stats(w.mods)
		for other: String in OpDef.STATS:
			var want: float = before[other] * (2.0 if other == stat_name else 1.0)
			assert_float(after[other]).override_failure_message("mul %s moved %s" % [stat_name, other]).is_equal_approx(want, 0.00001)


func test_every_flag_op_sets_exactly_its_bit() -> void:
	for flag_name: String in OpDef.FLAGS:
		w.mods.reset()
		ModSystem.apply_ops(w, _one(VarietyBKit.op_flag(StringName(flag_name))), 1)
		for other: String in OpDef.FLAGS:
			assert_bool(w.mods.has_flag(StringName(other))).is_equal(other == flag_name)
		assert_int(_flags_on(w.mods)).is_equal(1)
		assert_float(w.mods.lvl_damage).is_equal(0.0)


func test_stacks_add_linearly_and_multiply_by_power() -> void:
	w.mods.reset()
	ModSystem.apply_ops(w, _one(VarietyBKit.op_add(&"core_max_add", 150.0)), 3)
	assert_float(w.mods.core_max_add).is_equal(450.0)
	ModSystem.apply_ops(w, _one(VarietyBKit.op_mul(&"w_rate_mul", 1.1)), 3)
	assert_float(w.mods.w_rate_mul).is_equal_approx(1.331, 0.00001)
	ModSystem.apply_ops(w, _one(VarietyBKit.op_add(&"emp_cd_mul", -0.15)), 2)
	assert_float(w.mods.emp_cd_mul).is_equal_approx(0.7, 0.00001)  # a *_mul stat starts at 1.0, an add moves it


func test_grant_ops_and_unknown_names_leave_the_mods_alone() -> void:
	w.mods.reset()
	var before: String = _mods_hash(w.mods)
	var ops: Array[OpDef] = [
		VarietyBKit.op_grant(&"scrap", 100.0), VarietyBKit.op_grant(&"free_reroll", 1.0),
		VarietyBKit.op_add(&"not_a_stat", 5.0), VarietyBKit.op_mul(&"not_a_stat", 5.0), VarietyBKit.op_flag(&"not_a_flag"),
	]
	ModSystem.apply_ops(w, ops, 2)
	assert_str(_mods_hash(w.mods)).is_equal(before)
	assert_int(w.scrap).is_equal(0)  # apply_ops never grants


func test_a_turret_grant_is_a_stat_contribution() -> void:
	w.mods.reset()
	ModSystem.apply_ops(w, _one(VarietyBKit.op_grant(&"turret", 1.0)), 2)
	assert_float(w.mods.turrets).is_equal(2.0)


func test_recompute_is_a_pure_function_of_what_is_held() -> void:
	w.draft.stacks[c.directive_index(&"hot_loads")] = 2
	w.draft.stacks[c.directive_index(&"emp_capacitor")] = 1
	ModSystem.recompute(w)
	var once: String = _mods_hash(w.mods)
	ModSystem.recompute(w)
	ModSystem.recompute(w)
	assert_str(_mods_hash(w.mods)).is_equal(once)
	w.draft.stacks[c.directive_index(&"hot_loads")] = 0
	w.draft.stacks[c.directive_index(&"emp_capacitor")] = 0
	ModSystem.recompute(w)
	assert_str(_mods_hash(w.mods)).is_equal(_mods_hash(ModState.new()))
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)


func test_a_restored_draft_recomputes_to_the_same_mods() -> void:
	var a: SimWorld = VarietyBKit.world_after(c, 3, 4)
	for id: StringName in [&"hot_loads", &"hot_loads", &"cyclic_tuning", &"emp_capacitor", &"incendiary_tips", &"glass_cannon"]:
		assert_bool(DraftSystem.grant_stack(a, c.directive_index(id))).is_true()
	var b: SimWorld = VarietyBKit.world_after(c, 3, 4)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(a.draft.to_dict()))
	b.draft.from_dict(doc)
	ModSystem.recompute(b)
	assert_str(_mods_hash(b.mods)).is_equal(_mods_hash(a.mods))
	assert_array(Array(b.upgrade_levels)).is_equal(Array(a.upgrade_levels))
	assert_float(b.core_max_hp).is_equal(a.core_max_hp)


func test_hot_loads_stack_by_stack_gives_the_hit_damage_table() -> void:
	var per_level: float = c.upgrades[Ids.UP_DAMAGE].per_level
	assert_float(per_level).is_equal(0.2)
	var hot: int = c.directive_index(&"hot_loads")
	var want: Array[float] = [22.0, 28.0, 34.0, 40.0, 46.0, 52.0]  # hit_damage(30, level, 0.2, 8); level 0 is the ARCH 6.5 golden
	for level: int in want.size():
		assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(level)
		assert_float(Formulas.hit_damage(30.0, w.upgrade_levels[Ids.UP_DAMAGE], per_level, 8.0)).is_equal_approx(want[level], 0.0001)
		if level < 5:
			assert_bool(DraftSystem.grant_stack(w, hot)).is_true()
	assert_int(w.draft.stacks_of(hot)).is_equal(5)
	assert_bool(DraftSystem.grant_stack(w, hot)).is_false()  # max 5


func test_three_picks_of_hot_loads_feed_the_level_field_and_the_real_hit() -> void:
	var hot: int = c.directive_index(&"hot_loads")
	for _n: int in 3:
		assert_bool(DraftSystem.grant_stack(w, hot)).is_true()
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(3)
	assert_float(w.mods.lvl_damage).is_equal(3.0)
	var hollow: int = w.spawn_enemy(Ids.EN_HOLLOW, 5.0, 0.0)
	var dealt: float = DamageResolver.hit(w, hollow, 30.0, w.upgrade_levels[Ids.UP_DAMAGE], DamageSource.Id.WARDEN)
	assert_float(dealt).is_equal_approx(40.0, 0.0001)  # hit_damage(30, 3, 0.2, 8)
	var changed: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.UPGRADE_LEVEL_CHANGED)
	assert_int(changed.size()).is_equal(3)
	assert_int(changed[2].a).is_equal(Ids.UP_DAMAGE)
	assert_int(changed[2].b).is_equal(3)


func test_cyclic_tuning_feeds_the_fire_rate_level() -> void:
	var cyclic: int = c.directive_index(&"cyclic_tuning")
	var base: int = WeaponSystem.current_sps_milli(w)
	for _n: int in 3:
		assert_bool(DraftSystem.grant_stack(w, cyclic)).is_true()
	assert_int(w.upgrade_levels[Ids.UP_FIRE_RATE]).is_equal(3)
	var def: WeaponDef = c.weapons[0]
	assert_int(base).is_equal(def.sps_milli)
	assert_int(WeaponSystem.current_sps_milli(w)).is_equal(Formulas.sps_milli(def.sps_milli, 3, 0.15, 1000))


func test_penetrator_cores_feed_the_armor_piercing_level() -> void:
	var pen: int = c.directive_index(&"penetrator_cores")
	for _n: int in 5:
		assert_bool(DraftSystem.grant_stack(w, pen)).is_true()
	assert_int(w.upgrade_levels[Ids.UP_ARMOR_PIERCING]).is_equal(5)
	assert_float(Formulas.effective_armor(12.0, 5, 0.15, 0.9)).is_equal_approx(3.0, 0.0001)  # the ARCH 6.5 golden
	var hulk: int = w.spawn_enemy(Ids.EN_HULK, 5.0, 0.0)  # armor 12 -> 3.0
	var dealt: float = DamageResolver.hit(w, hulk, 30.0, 0, DamageSource.Id.WARDEN)
	assert_float(dealt).is_equal_approx(27.0, 0.0001)


func test_turret_deploy_puts_a_turret_on_the_next_free_pad() -> void:
	var turret: int = c.directive_index(&"turret_deploy")
	assert_int(w.turrets.active_count()).is_equal(0)
	assert_bool(DraftSystem.grant_stack(w, turret)).is_true()
	assert_int(w.turrets.active[0]).is_equal(1)
	assert_int(w.turrets.active[1]).is_equal(0)
	assert_int(w.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(1)
	assert_bool(DraftSystem.grant_stack(w, turret)).is_true()
	assert_int(w.turrets.active_count()).is_equal(2)
	assert_int(w.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(2)
	assert_bool(DraftSystem.grant_stack(w, turret)).is_false()  # max 2
	var deployed: Array[SimEvent] = VarietyBKit.events_of(w, SimEventKind.Id.TURRET_DEPLOYED)
	assert_int(deployed.size()).is_equal(2)
	assert_int(deployed[0].a).is_equal(0)
	assert_int(deployed[1].a).is_equal(1)


func test_a_recompute_does_not_deploy_twice() -> void:
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"turret_deploy"))).is_true()
	ModSystem.recompute(w)
	ModSystem.recompute(w)
	assert_int(VarietyBKit.events_of(w, SimEventKind.Id.TURRET_DEPLOYED).size()).is_equal(1)
	assert_int(w.turrets.active_count()).is_equal(1)


func test_glass_cannon_trades_the_core_for_damage() -> void:
	w.set_core_hp(500.0)
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"glass_cannon"))).is_true()
	assert_float(w.mods.w_dmg_mul).is_equal_approx(1.8, 0.00001)
	assert_float(w.core_max_hp).is_equal(700.0)
	assert_float(w.core_hp).is_equal_approx(350.0, 0.001)  # the same fraction of a smaller core


func test_reinforced_cage_raises_the_maximum_and_repairs() -> void:
	var cage: int = c.directive_index(&"reinforced_cage")
	w.set_core_hp(600.0)
	assert_bool(DraftSystem.grant_stack(w, cage)).is_true()
	assert_float(w.core_max_hp).is_equal(1150.0)
	assert_float(w.core_hp).is_equal(750.0)  # max up keeps the hp; the grant repairs 150
	assert_bool(DraftSystem.grant_stack(w, cage)).is_true()
	assert_float(w.core_max_hp).is_equal(1300.0)
	assert_float(w.core_hp).is_equal(900.0)
	assert_int(VarietyBKit.events_of(w, SimEventKind.Id.CORE_HEALED).size()).is_equal(2)


func test_other_slice_directives_land_in_their_stats() -> void:
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"emp_capacitor"))).is_true()
	assert_float(w.mods.emp_cd_mul).is_equal_approx(0.85, 0.00001)
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"emp_capacitor"))).is_true()
	assert_float(w.mods.emp_cd_mul).is_equal_approx(0.70, 0.00001)
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"incendiary_tips"))).is_true()
	assert_float(w.mods.burn_dps).is_equal(8.0)
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"incendiary_tips"))).is_true()
	assert_float(w.mods.burn_dps).is_equal(16.0)


func test_a_wave_modifier_applies_and_clears() -> void:
	var volatile: int = c.run.modifier_index(&"mod_volatile")
	ModSystem.set_wave_modifier(w, volatile)
	assert_int(w.mods.wave_modifier).is_equal(volatile)
	assert_bool(w.mods.has_flag(&"volatile_skitters")).is_true()
	assert_float(w.mods.volatile_radius).is_equal(1.2)
	assert_float(w.mods.volatile_damage).is_equal(20.0)
	ModSystem.set_wave_modifier(w, -1)
	assert_int(w.mods.wave_modifier).is_equal(-1)
	assert_bool(w.mods.has_flag(&"volatile_skitters")).is_false()
	assert_float(w.mods.volatile_damage).is_equal(0.0)
	ModSystem.set_wave_modifier(w, 99)
	assert_int(w.mods.wave_modifier).is_equal(-1)


func test_a_modifier_stacks_with_the_build() -> void:
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"hot_loads"))).is_true()
	ModSystem.set_wave_modifier(w, c.run.modifier_index(&"mod_volatile"))
	assert_float(w.mods.lvl_damage).is_equal(1.0)
	assert_bool(w.mods.has_flag(&"volatile_skitters")).is_true()
	assert_bool(DraftSystem.grant_stack(w, c.directive_index(&"hot_loads"))).is_true()
	assert_bool(w.mods.has_flag(&"volatile_skitters")).is_true()  # a pick keeps the modifier of the wave


func test_a_plan_patch_hook_runs_the_plan_patch_without_harm() -> void:
	var patcher: int = VarietyBKit.add_directive(c, VarietyBKit.def(&"patcher", DirectiveDef.Rarity.CORRUPTED, 1))
	c.directives[patcher].hook = ModSystem.HOOK_PLAN_PATCH
	var world: SimWorld = VarietyBKit.world_after(c, 3)
	assert_bool(DraftSystem.grant_stack(world, patcher)).is_true()
	assert_int(world.draft.stacks_of(patcher)).is_equal(1)


func test_a_legacy_world_is_left_alone() -> void:
	var legacy: SimWorld = TestContent.world(5)
	var before: String = legacy.state_hash()
	ModSystem.recompute(legacy)
	ModSystem.init_world(legacy)
	ModSystem.set_wave_modifier(legacy, 0)
	assert_str(legacy.state_hash()).is_equal(before)
	legacy.upgrade_levels[Ids.UP_DAMAGE] = 2  # a bought level survives
	ModSystem.recompute(legacy)
	assert_int(legacy.upgrade_levels[Ids.UP_DAMAGE]).is_equal(2)
	assert_int(legacy.events.peek().size()).is_equal(0)
