extends GdUnitTestSuite
## V2-A: the elites (CONTENT 4.3, VARIETY_SPEC 5.2) and the world events (CONTENT 6) rolled into the plan at tick 0.


func _count_elites(o: RouteOption) -> int:
	return o.elites.size()


func test_elites_start_at_wave_3_and_boss_waves_have_none() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	for s: int in range(1, 61):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for n: int in [1, 2, 5, 10, 15]:
			for o: RouteOption in plan.wave(n).options:
				# the act's own range is empty before wave 3 and in boss waves; a pack or modifier may still add its elites
				var added: int = RunPlanSystem._extra_elites(c, o) if n == 2 else 0
				assert_int(_count_elites(o)).override_failure_message("seed %d wave %d" % [s, n]).is_equal(added)


func test_elites_per_option_follow_the_act_range_and_the_hot_bonus() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var act_lo: Array[int] = [0, 1, 2]
	var act_hi: Array[int] = [1, 2, 3]
	var seen_hi: Dictionary[int, bool] = {}
	for s: int in range(1, 121):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			if pw.is_boss or pw.index < 3:
				continue
			for o: RouteOption in pw.options:
				var bonus: int = (1 if o.hot and pw.act >= 2 else 0) + RunPlanSystem._extra_elites(c, o)  # pack_hunt, mod_elite_pair
				var lo: int = act_lo[pw.act - 1] + bonus
				var hi: int = act_hi[pw.act - 1] + bonus
				assert_int(_count_elites(o)).is_between(lo, hi)
				if _count_elites(o) == hi:
					seen_hi[pw.act] = true
	assert_int(seen_hi.size()).is_equal(3)  # the top of every range is reached


func test_elites_are_valid_unique_sorted_bodied_machines() -> void:
	var c: ContentSet = VarietyAKit.long_content()
	var pack: PackDef = VarietyAKit.pack_of(c, &"pack_all", PackedInt32Array([
		Ids.EN_SKITTER, Ids.EN_MOTE, Ids.EN_BURSTER, Ids.EN_HOLLOW, Ids.EN_RECLAIMER, Ids.EN_WARD_PYLON, Ids.EN_HULK,
	]))
	var slot: WaveSlotDef = VarietyAKit.slot(c, 12)
	for act: int in [2, 3]:
		slot.act = act
		for s: int in range(1, 41):
			var o: RouteOption = RouteOption.new()
			o.groups = WaveBuilder.build(c, slot, pack.index, 1.0, PlanRng.stream(s, &"t"))
			PlanElites.roll(c, slot, o, 6, PlanRng.stream(s, &"plan.elite:12"))
			assert_int(o.elites.size()).is_greater_equal(6)
			var seen: Dictionary[int, bool] = {}
			var last_key: int = -1
			for e: PlannedElite in o.elites:
				var g: SpawnGroupDef = o.groups[e.group]
				assert_int(e.ordinal).is_between(0, g.count - 1)
				assert_bool(PlanElites.eligible(c, g.enemy_index, act)).is_true()
				assert_bool(c.enemies[g.enemy_index].is_mini()).is_false()
				assert_bool(c.enemies[g.enemy_index].is_boss).is_false()
				assert_bool([Ids.EN_BURSTER, Ids.EN_WARD_PYLON].has(g.enemy_index)).is_false()
				if act == 2:
					assert_int(g.enemy_index).is_not_equal(Ids.EN_RECLAIMER)  # a reclaimer is elite from act III only
				var key: int = e.group * 100000 + e.ordinal
				assert_bool(seen.has(key)).is_false()
				assert_int(key).is_greater(last_key)
				seen[key] = true
				last_key = key
				assert_int(e.affix_mask).is_not_equal(0)


func test_a_pack_or_modifier_can_add_elites() -> void:
	var c: ContentSet = VarietyAKit.content()
	var pair: ModifierDef = ModifierDef.new()
	pair.id = &"mod_elite_pair"
	pair.list = ModifierDef.List.HOT
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.ADD
	op.target = &"extra_elites"
	op.value = 2.0
	pair.ops.append(op)
	c.run.modifiers = [pair]
	pair.index = 0
	for s: int in range(1, 31):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		assert_int(plan.wave(4).options[1].elites.size()).is_greater_equal(2)  # act I hot: 0 to 1 plus the pair
		assert_int(plan.wave(2).options[1].elites.size()).is_equal(2)  # even before wave 3: the modifier says so


func test_the_affix_count_is_one_in_act_one_two_in_act_three_and_either_in_act_two() -> void:
	var c: ContentSet = VarietyAKit.content()
	var counts: Array[Dictionary] = [{}, {}, {}]
	for s: int in range(1, 401):
		for act: int in [1, 2, 3]:
			var mask: int = PlanElites.roll_affixes(c, Ids.EN_HOLLOW, act, PlanRng.stream(s, &"plan.elite:3"))
			var bits: int = 0
			for a: int in c.affixes.size():
				bits += 1 if (mask & (1 << a)) != 0 else 0
			counts[act - 1][bits] = true
	assert_array(counts[0].keys()).is_equal([1])
	assert_array(counts[2].keys()).is_equal([2])
	assert_int(counts[1].size()).is_equal(2)


func test_forbidden_affix_pairs_never_appear() -> void:
	var c: ContentSet = VarietyAKit.content()
	var magnetic: int = c.affix_index(&"aff_magnetic")
	var shroud: int = c.affix_index(&"aff_shroud")
	var warded: int = c.affix_index(&"aff_warded")
	var regen: int = c.affix_index(&"aff_regen")
	var swift: int = c.affix_index(&"aff_swift")
	var volatile: int = c.affix_index(&"aff_volatile")
	var swift_volatile_elsewhere: bool = false
	var warded_regen_late: bool = false
	for s: int in range(1, 1501):
		for act: int in [2, 3]:
			var rusher: int = PlanElites.roll_affixes(c, Ids.EN_RUSHER, act, PlanRng.stream(s, &"x"))
			var other: int = PlanElites.roll_affixes(c, Ids.EN_SKITTER, act, PlanRng.stream(s, &"y"))
			for mask: int in [rusher, other]:
				assert_bool((mask & (1 << magnetic)) != 0 and (mask & (1 << shroud)) != 0).is_false()
				if act < 3:
					assert_bool((mask & (1 << warded)) != 0 and (mask & (1 << regen)) != 0).is_false()
				else:
					warded_regen_late = warded_regen_late or ((mask & (1 << warded)) != 0 and (mask & (1 << regen)) != 0)
			assert_bool((rusher & (1 << swift)) != 0 and (rusher & (1 << volatile)) != 0).is_false()
			swift_volatile_elsewhere = swift_volatile_elsewhere or ((other & (1 << swift)) != 0 and (other & (1 << volatile)) != 0)
	assert_bool(warded_regen_late).is_true()  # allowed in act III
	assert_bool(swift_volatile_elsewhere).is_true()  # only banned on a rusher


func test_the_spawner_gives_a_planned_elite_its_affixes() -> void:
	var w: SimWorld = VarietyAKit.world(3)
	var planned: PlannedElite = PlannedElite.new()
	planned.group = 0
	planned.ordinal = 2
	planned.affix_mask = 0b101
	var groups: Array[SpawnGroupDef] = [VarietyAKit.group(Ids.EN_SKITTER, 5, 0, 10, &"right")]
	w.plan.waves[0].options[0].elites = [planned]
	VarietyAKit.start_wave(w, groups)
	VarietyAKit.tick_spawn(w, 60)
	var elite: int = -1
	for i: int in w.enemies.high_water:
		if w.ext.is_elite(i):
			elite = i
	assert_int(elite).is_greater_equal(0)
	assert_int(w.ext.affix_mask[elite]).is_equal(0b101)
	assert_int(w.alive_count()).is_equal(5)
	assert_int(EliteSystem.alive_elites(w)).is_equal(1)
	assert_int(w.enemies.spawn_tick[elite]).is_equal(w.enemies.spawn_tick[0] + 20)  # the third body of the group (ordinal 2)


# --- world events ---


func _events_content() -> ContentSet:
	var c: ContentSet = VarietyAKit.long_content()
	var rows: Array = [
		[&"accord_window", [30.0, 15.0, 10.0], true, false],
		[&"supply_drop", [30.0, 20.0, 15.0], true, false],
		[&"power_surge", [20.0, 15.0, 15.0], true, false],
		[&"runaway_freight", [10.0, 15.0, 15.0], true, false],
		[&"static_front", [10.0, 15.0, 20.0], false, true],
		[&"floor_breach", [0.0, 15.0, 15.0], false, true],
		[&"recount", [0.0, 5.0, 10.0], false, true],
	]
	for row: Array in rows:
		var weights: Array = row[1]
		var id: StringName = row[0]
		var e: EventDef = c.event_def(id)  # the frozen fixture has the real events now: the rows replace their plan fields
		if e == null:
			e = EventDef.new()
			e.id = id
			e.index = c.events.size()
			e.who = EventDef.Who.WORLD
			c.events.append(e)
		e.weights = PackedFloat32Array(weights)
		e.boss_safe = row[2]
		e.harmful = row[3]
	return c


func _has_duplicates(ids: Array[StringName]) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		if seen.has(id):
			return true
		seen[id] = true
	return false


func _ids(c: ContentSet, pw: PlannedWave) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: PlannedEvent in pw.events:
		out.append(c.events[e.event_index].id)
	return out


func test_event_slots_decide_how_many_events_a_wave_gets() -> void:
	var c: ContentSet = _events_content()
	var seen_two: bool = false
	for s: int in range(1, 41):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		for pw: PlannedWave in plan.waves:
			var slots: int = c.run.wave_slot(pw.index).event_slots
			assert_int(pw.events.size()).is_less_equal(slots)
			if slots == 0:
				assert_int(pw.events.size()).is_equal(0)
			seen_two = seen_two or pw.events.size() == 2
		assert_int(plan.wave(3).events.size()).is_equal(1)
	assert_bool(seen_two).is_true()


func test_wave_three_is_helpful_and_the_fairness_rules_hold_on_every_wave() -> void:
	var c: ContentSet = _events_content()
	for s: int in range(1, 201):
		var plan: RunPlan = RunPlanSystem.build_for(c, s)
		var previous: Array[StringName] = []
		for pw: PlannedWave in plan.waves:
			var ids: Array[StringName] = _ids(c, pw)
			var harmful: int = 0
			for e: PlannedEvent in pw.events:
				var def: EventDef = c.events[e.event_index]
				harmful += 1 if def.harmful else 0
				assert_bool(def.who == EventDef.Who.WORLD).is_true()
				if pw.is_boss:
					assert_bool(def.boss_safe).is_true()
				if pw.index == 3:
					assert_bool(def.harmful).is_false()
				assert_bool(previous.has(def.id)).override_failure_message("seed %d wave %d repeats %s" % [s, pw.index, def.id]).is_false()
			if pw.act <= 2:
				assert_int(harmful).is_less_equal(1)
			assert_bool(ids.has(&"static_front") and ids.has(&"power_surge")).is_false()
			assert_bool(_has_duplicates(ids)).is_false()
			previous = ids


func test_event_warnings_start_between_25_and_70_percent_of_the_window_in_order() -> void:
	var c: ContentSet = _events_content()
	for s: int in range(1, 61):
		for pw: PlannedWave in RunPlanSystem.build_for(c, s).waves:
			var window: float = float(c.run.wave_slot(pw.index).window_ticks)
			var last: int = -1
			for e: PlannedEvent in pw.events:
				assert_float(float(e.start_offset)).is_between(0.25 * window - 1.0, 0.7 * window + 1.0)
				assert_int(e.start_offset).is_greater_equal(last)
				last = e.start_offset


func test_a_slice_without_world_events_plans_none() -> void:
	var c: ContentSet = VarietyAKit.content()
	for e: EventDef in c.events:
		if e.who == EventDef.Who.WORLD:
			e.weights = PackedFloat32Array([0.0, 0.0, 0.0])  # no world event has a weight: the plan rolls none
	for pw: PlannedWave in RunPlanSystem.build_for(c, 1).waves:
		assert_int(pw.events.size()).is_equal(0)
