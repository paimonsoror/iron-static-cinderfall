extends GdUnitTestSuite
## V2-H: the text of `plan_dump` (PlanReport) on hand-made plans, and the check that tells the scaffold's stub plan from
## a generated one. The generated plan itself comes from V2-A; this suite does not need it.

var w: SimWorld


func before_test() -> void:
	w = VarietyHKit.world()


func _group(enemy: int, count: int, start: int, interval: int, region: StringName) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = enemy
	g.count = count
	g.start_tick = start
	g.interval_ticks = interval
	g.region_id = region
	return g


## Two waves: an opener with one option and a normal wave with two, one event and one elite.
func _plan() -> RunPlan:
	var plan: RunPlan = RunPlan.new()
	plan.boss_ids = PackedInt32Array([Ids.EN_HULK, Ids.EN_HULK, Ids.EN_HULK])
	plan.drum_points = PackedInt32Array([1, 3, 5])
	var opener: PlannedWave = PlannedWave.new()
	opener.index = 1
	var tide: RouteOption = VarietyHKit.option(w, &"pack_tide", &"rw_scrap", false)
	tide.groups.append(_group(Ids.EN_SKITTER, 12, 0, 40, &"right"))
	tide.groups.append(_group(Ids.EN_MOTE, 5, 300, 20, &"upper_right"))
	opener.options.append(tide)
	var normal: PlannedWave = PlannedWave.new()
	normal.index = 2
	var hot: RouteOption = VarietyHKit.option(w, &"pack_powder", &"rw_crate", true)
	hot.modifier_index = w.content.run.modifier_index(&"mod_volatile")
	hot.groups.append(_group(Ids.EN_BURSTER, 4, 60, 90, &"right"))
	var pe: PlannedElite = PlannedElite.new()
	pe.group = 0
	pe.ordinal = 2
	hot.elites.append(pe)
	normal.options.append(VarietyHKit.option(w, &"pack_column", &"rw_patch", false))
	normal.options.append(hot)
	var event: PlannedEvent = PlannedEvent.new()
	event.event_index = w.content.event_index(&"deadfall_strike")
	event.start_offset = 700
	normal.events.append(event)
	plan.waves.append(opener)
	plan.waves.append(normal)
	plan.chosen = PackedInt32Array([0, 0])
	return plan


func _joined(plan: RunPlan) -> String:
	return "\n".join(PlanReport.lines(plan, w.content, 7))


func test_the_scaffold_stub_is_recognised_and_a_plan_with_bosses_is_not() -> void:
	assert_bool(PlanReport.is_legacy_stub(w.plan)).is_false()  # since V2-A RunPlanSystem.build makes a real plan
	assert_bool(PlanReport.is_legacy_stub(TestContent.world().plan)).is_true()  # the legacy content has none
	assert_bool(PlanReport.is_legacy_stub(RunPlan.new())).is_true()  # no boss ids: the shape of the old stub
	assert_bool(PlanReport.is_legacy_stub(null)).is_true()
	assert_bool(PlanReport.is_legacy_stub(_plan())).is_false()


func test_the_stub_message_says_what_is_missing() -> void:
	assert_str(PlanReport.STUB_MESSAGE).contains("legacy stub")
	assert_str(PlanReport.STUB_MESSAGE).contains("V2-A")


func test_the_plan_text_names_bosses_waves_options_groups_elites_and_events() -> void:
	var text: String = _joined(_plan())
	assert_str(text).contains("PLAN seed=7 waves=2 acts=3")
	assert_str(text).contains("PLAN boss act=1 enemy=siege_hulk")
	assert_str(text).contains("PLAN wave=1 act=1 kind=opener options=1 events=0")
	assert_str(text).contains("PLAN wave=2 act=1 kind=normal options=2 events=1")
	assert_str(text).contains("PLAN   option=A pack=pack_tide modifier=- reward=rw_scrap hot=0 bodies=17 elites=0")
	assert_str(text).contains("PLAN   option=B pack=pack_powder modifier=mod_volatile reward=rw_crate hot=1 bodies=4 elites=1")
	assert_str(text).contains("PLAN     group enemy=skitter count=12 start_tick=0 interval_ticks=40 region=right")
	assert_str(text).contains("PLAN     group enemy=mote count=5 start_tick=300 interval_ticks=20 region=upper_right")
	assert_str(text).contains("PLAN     elite group=0 ordinal=2 affixes=-")
	assert_str(text).contains("PLAN   event=deadfall_strike at_tick=700")
	assert_str(text).contains("PLAN drums points=1,3,5")


func test_the_last_line_is_the_summary_with_counts_and_the_plan_hash() -> void:
	var lines: PackedStringArray = PlanReport.lines(_plan(), w.content, 7)
	var last: String = lines[lines.size() - 1]
	assert_str(last).starts_with("PLAN SUMMARY: seed=7 waves=2 options=3 events=1 plan_hash=")
	var h: StateHasher = StateHasher.new()
	_plan().hash_into(h)
	assert_str(last).ends_with(h.finish())


func test_every_line_but_the_last_starts_with_plan_and_no_id_is_unresolved() -> void:
	for line: String in PlanReport.lines(_plan(), w.content, 7):
		assert_str(line).starts_with("PLAN")
		assert_bool(line.contains("?")).is_false()


func test_the_same_plan_prints_the_same_bytes_and_another_plan_another_hash() -> void:
	assert_str(_joined(_plan())).is_equal(_joined(_plan()))
	var other: RunPlan = _plan()
	other.waves[1].options[1].reward_index = w.content.run.reward_index(&"rw_data")
	assert_str(_joined(other)).is_not_equal(_joined(_plan()))
	var lines_a: PackedStringArray = PlanReport.lines(_plan(), w.content, 7)
	var lines_b: PackedStringArray = PlanReport.lines(other, w.content, 7)
	assert_str(lines_a[lines_a.size() - 1]).is_not_equal(lines_b[lines_b.size() - 1])


func test_an_unknown_index_prints_as_a_question_mark_not_a_crash() -> void:
	var plan: RunPlan = _plan()
	plan.waves[1].events[0].event_index = 99
	plan.waves[0].options[0].groups[0].enemy_index = 99
	var text: String = _joined(plan)
	assert_str(text).contains("event=?99")
	assert_str(text).contains("enemy=?99")
