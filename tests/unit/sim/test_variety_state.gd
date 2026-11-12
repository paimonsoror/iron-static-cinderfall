extends GdUnitTestSuite
## V1-S: the state classes of the variety milestone (VARIETY_SPEC 9.5 rule 3, 13.2). Every listed field is hashed
## ("mutate one field, the hash must change"), survives to_dict -> JSON -> from_dict, and starts neutral.


func _hash(state: Object) -> String:
	var h: StateHasher = StateHasher.new()
	state.call("hash_into", h)
	return h.finish()


## Changes field `f` of `o` to a different value of its own type.
func _mutate(o: Object, f: String) -> void:
	var v: Variant = o.get(f)
	match typeof(v):
		TYPE_INT:
			var i: int = v
			o.set(f, i + 1)
		TYPE_BOOL:
			var b: bool = v
			o.set(f, not b)
		TYPE_FLOAT:
			var x: float = v
			o.set(f, x + 0.5)
		TYPE_PACKED_INT32_ARRAY:
			var ia: PackedInt32Array = v
			ia = ia.duplicate()
			ia.append(7)
			o.set(f, ia)
		TYPE_PACKED_FLOAT64_ARRAY:
			var fa: PackedFloat64Array = v
			fa = fa.duplicate()
			fa.append(1.25)
			o.set(f, fa)
		TYPE_PACKED_BYTE_ARRAY:
			var ba: PackedByteArray = v
			ba = ba.duplicate()
			ba.append(1)
			o.set(f, ba)
		_:
			assert_bool(false).override_failure_message("field %s has an unsupported type" % f).is_true()


func _states() -> Array[Object]:
	return [
		DraftState.new(8), ArsenalState.new(), SalvageState.new(), EnemyExtState.new(6), HazardState.new(),
		EventState.new(3), BossState.new(),
	]


func _fields(state: Object) -> PackedStringArray:
	var script: Script = state.get_script()
	var fields: PackedStringArray = script.get_script_constant_map()["FIELDS"]
	return fields


## A new instance of the class of `state`.
func _fresh(state: Object) -> Object:
	var script: Script = state.get_script()
	var made: Object = script.call("new")
	return made


func test_every_listed_field_is_hashed() -> void:
	for proto: Object in _states():
		var fields: PackedStringArray = _fields(proto)
		assert_int(fields.size()).is_greater(5)
		var seen: Dictionary[String, String] = {}
		for f: String in fields:
			var state: Object = _fresh(proto)
			var before: String = _hash(state)
			_mutate(state, f)
			var after: String = _hash(state)
			assert_str(after).override_failure_message("%s is not hashed" % f).is_not_equal(before)
			assert_bool(seen.has(after)).override_failure_message("%s hashes like %s" % [f, seen.get(after, "")]).is_false()
			seen[after] = f


func test_every_field_list_names_real_properties_and_misses_none() -> void:
	for state: Object in _states():
		var script: Script = state.get_script()
		var declared: Array[String] = []
		for p: Dictionary in script.get_script_property_list():
			var usage: int = p["usage"]
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				declared.append(str(p["name"]))
		var fields: PackedStringArray = _fields(state)
		for f: String in fields:
			assert_bool(declared.has(f)).override_failure_message("%s is not a property" % f).is_true()
		for name_of_var: String in declared:
			if name_of_var == "capacity":
				continue  # EnemyExtState: fixed by the store size, not state
			assert_bool(fields.has(name_of_var)).override_failure_message("%s is not in FIELDS" % name_of_var).is_true()


func test_states_survive_a_json_round_trip() -> void:
	for state: Object in _states():
		for f: String in _fields(state):
			_mutate(state, f)
		var doc: Dictionary = state.call("to_dict")
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(doc))
		var copy: Object = _fresh(state)
		copy.call("from_dict", parsed)
		assert_str(_hash(copy)).is_equal(_hash(state))


func test_mod_state_defaults_flags_and_hash() -> void:
	var m: ModState = ModState.new()
	for stat_name: String in OpDef.STATS:
		assert_float(m.stat(StringName(stat_name))).is_equal(1.0 if stat_name.ends_with("_mul") else 0.0)
	assert_bool(m.has_flag(&"od_turrets")).is_false()
	var base: String = _hash(m)
	var seen: Dictionary[String, bool] = {base: true}
	for stat_name: String in OpDef.STATS:
		var changed: ModState = ModState.new()
		changed.set(stat_name, changed.stat(StringName(stat_name)) + 0.25)
		assert_bool(seen.has(_hash(changed))).override_failure_message("%s is not hashed" % stat_name).is_false()
		seen[_hash(changed)] = true
	for flag_name: String in OpDef.FLAGS:
		var flagged: ModState = ModState.new()
		flagged.set_flag(StringName(flag_name), true)
		assert_bool(flagged.has_flag(StringName(flag_name))).is_true()
		assert_bool(seen.has(_hash(flagged))).override_failure_message("%s is not hashed" % flag_name).is_false()
		seen[_hash(flagged)] = true
	m.set_flag(&"not_a_flag", true)
	assert_str(_hash(m)).is_equal(base)
	m.wave_modifier = 0
	assert_str(_hash(m)).is_not_equal(base)


func test_mod_state_round_trip_and_reset() -> void:
	var m: ModState = ModState.new()
	m.lvl_damage = 3.0
	m.w_dmg_mul = 1.8
	m.core_max_mul = 0.7
	m.set_flag(&"volatile_skitters", true)
	m.wave_modifier = 2
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	var copy: ModState = ModState.new()
	copy.from_dict(parsed)
	assert_str(_hash(copy)).is_equal(_hash(m))
	assert_bool(copy.has_flag(&"volatile_skitters")).is_true()
	copy.reset()
	assert_float(copy.w_dmg_mul).is_equal(1.0)
	assert_float(copy.lvl_damage).is_equal(0.0)
	assert_bool(copy.has_flag(&"volatile_skitters")).is_false()


func test_enemy_ext_state_rows() -> void:
	var x: EnemyExtState = EnemyExtState.new(4)
	assert_int(x.capacity).is_equal(4)
	assert_int(x.flags.size()).is_equal(4)
	assert_int(x.anchor_point[2]).is_equal(-1)
	assert_int(x.hp_scale_milli[2]).is_equal(1000)
	x.flags[2] = EnemyExtState.F_ELITE | EnemyExtState.F_ARMED
	x.burn_ticks[2] = 90
	x.anchor_point[2] = 5
	assert_bool(x.is_elite(2)).is_true()
	assert_bool(x.has_flag(2, EnemyExtState.F_ARMED)).is_true()
	assert_bool(x.has_flag(2, EnemyExtState.F_MINI)).is_false()
	assert_bool(x.has_flag(9, EnemyExtState.F_ELITE)).is_false()
	x.reset(2)
	assert_int(x.flags[2]).is_equal(0)
	assert_int(x.burn_ticks[2]).is_equal(0)
	assert_int(x.anchor_point[2]).is_equal(-1)
	x.reset(99)  # out of range: ignored


func test_small_state_queries() -> void:
	var d: DraftState = DraftState.new(8)
	assert_int(d.stacks.size()).is_equal(8)
	d.stacks[3] = 2
	assert_int(d.stacks_of(3)).is_equal(2)
	assert_int(d.stacks_of(99)).is_equal(0)
	var e: EventState = EventState.new(2)
	e.charges[1] = 3
	assert_int(e.charges_of(1)).is_equal(3)
	assert_int(e.charges_of(-1)).is_equal(0)
	assert_int(e.active_count()).is_equal(0)
	var a: ArsenalState = ArsenalState.new()
	assert_int(a.slot_count).is_equal(2)
	assert_array(Array(a.slot_weapon)).is_equal([0, -1, -1])
	var h: HazardState = HazardState.new()
	assert_int(h.queued() + h.pool_count()).is_equal(0)
	assert_int(BossState.new().boss_id).is_equal(0)


func test_run_plan_from_legacy_waves_and_round_trip() -> void:
	var content: ContentSet = TestContent.baseline()
	var plan: RunPlan = RunPlan.from_legacy(content.waves)
	assert_int(plan.wave_count()).is_equal(5)
	assert_int(plan.wave(1).options.size()).is_equal(1)
	assert_int(plan.option(1).total_count()).is_equal(content.waves[0].total_count())
	assert_int(plan.option(5).groups.size()).is_equal(content.waves[4].groups.size())
	assert_object(plan.wave(0)).is_null()
	assert_object(plan.option(6)).is_null()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(plan.to_dict()))
	var copy: RunPlan = RunPlan.from_dict(parsed)
	assert_str(_hash(copy)).is_equal(_hash(plan))
	assert_str(String(copy.option(5).groups[3].region_id)).is_equal("upper_right")


func test_run_plan_hash_covers_choices_options_events_and_elites() -> void:
	var content: ContentSet = TestContent.baseline()
	var seen: Dictionary[String, bool] = {}
	for variant: int in 7:
		var plan: RunPlan = RunPlan.from_legacy(content.waves)
		var second: RouteOption = RouteOption.new()
		second.pack_index = 2
		second.groups = content.waves[1].groups.duplicate()
		plan.waves[1].options.append(second)
		match variant:
			1:
				plan.chosen[1] = 1
			2:
				plan.waves[1].options[1].hot = true
			3:
				plan.waves[1].options[1].reward_index = 4
			4:
				var ev: PlannedEvent = PlannedEvent.new()
				ev.event_index = 0
				ev.start_offset = 600
				plan.waves[2].events.append(ev)
			5:
				var el: PlannedElite = PlannedElite.new()
				el.group = 0
				el.ordinal = 3
				el.affix_mask = 5
				plan.waves[1].options[0].elites.append(el)
			6:
				plan.boss_ids = PackedInt32Array([Ids.EN_HULK])
		var digest: String = _hash(plan)
		assert_bool(seen.has(digest)).override_failure_message("variant %d is not hashed" % variant).is_false()
		seen[digest] = true
		if variant == 1:
			assert_int(plan.option(2).pack_index).is_equal(2)  # the chosen option is the one that spawns


func test_snap_util_reads_what_json_gives_back() -> void:
	assert_float(SnapUtil.num(3)).is_equal(3.0)
	assert_float(SnapUtil.num(2.5)).is_equal(2.5)
	assert_float(SnapUtil.num("x")).is_equal(0.0)
	assert_array(Array(SnapUtil.ints([1.0, 2.0, 3]))).is_equal([1, 2, 3])
	assert_array(Array(SnapUtil.floats([1, 2.5]))).is_equal([1.0, 2.5])
	assert_int(SnapUtil.ints("nope").size()).is_equal(0)
