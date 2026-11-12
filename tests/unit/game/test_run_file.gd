extends GdUnitTestSuite
## V2-D: the run file document (RunFile) and the content hash it carries (ContentFingerprint).


func _world(run_seed: int = 5) -> SimWorld:
	return SimWorld.new(VarietyDKit.config(TestContent.variety(), run_seed))


func _doc(world: SimWorld, resume_tick: int = -1) -> Dictionary:
	return RunFile.compose(RunFile.header(world.config, "900-5"), RunFile.boundary(world), world.command_log.to_dicts(), resume_tick)


func test_the_header_carries_the_fields_of_the_spec() -> void:
	var world: SimWorld = _world()
	world.config.unlocked = PackedStringArray(["u_a", "u_b"])
	var head: Dictionary = RunFile.header(world.config, "900-5")
	assert_int(head["schema_version"]).is_equal(1)
	assert_str(str(head["build"])).is_equal(str(ProjectSettings.get_setting("application/config/version")))
	assert_str(str(head["content_hash"])).is_equal(ContentFingerprint.of(world.content))
	assert_int(str(head["content_hash"]).length()).is_equal(12)
	assert_str(str(head["run_id"])).is_equal("900-5")
	assert_int(head["seed"]).is_equal(5)
	assert_str(str(head["kit"])).is_equal(String(world.content.kits[0].id))
	assert_array(head["unlocked"]).is_equal(["u_a", "u_b"])
	assert_bool(head["daily"]).is_false()
	assert_bool(head.has("debug")).is_true()  # the kit's boosted config
	var plain: Dictionary = RunFile.header(SimConfig.create(TestContent.variety(), 5), "900-5")
	assert_bool(plain.has("debug")).is_false()


func test_the_boundary_holds_the_wave_the_tick_the_hash_and_the_state() -> void:
	var world: SimWorld = _world()
	assert_bool(VarietyDKit.step_until_cleared(world, 2, 40000)).is_true()
	var b: Dictionary = RunFile.boundary(world)
	assert_int(b["wave"]).is_equal(2)
	assert_int(b["tick"]).is_equal(world.tick)
	assert_str(str(b["state_hash"])).is_equal(world.state_hash())
	assert_int(str(b["state_hash"]).length()).is_equal(64)
	assert_int(typeof(b["state"])).is_equal(TYPE_DICTIONARY)


func test_compose_splits_the_log_at_the_boundary_tick() -> void:
	var world: SimWorld = _world()
	assert_bool(VarietyDKit.step_until_cleared(world, 2, 40000)).is_true()
	var logged: int = world.command_log.entries.size()  # the intermission after wave 1: the draft, the route, CONTINUE
	assert_int(logged).is_equal(3)
	var head: Dictionary = RunFile.header(world.config, "900-5")
	var boundary: Dictionary = RunFile.boundary(world)
	world.submit(SimCommand.purchase(9001, Ids.UP_DAMAGE))
	world.step()
	world.submit(SimCommand.skip(9002))
	world.step()
	var doc: Dictionary = RunFile.compose(head, boundary, world.command_log.to_dicts(), -1)
	var before: Array = doc["log"]
	var tail: Array = doc["tail"]
	assert_int(before.size()).is_equal(logged)
	assert_int(tail.size()).is_equal(2)
	var first: Dictionary = tail[0]
	assert_int(first["id"]).is_equal(9001)
	assert_int(first["tick"]).is_equal(RunFile.whole(boundary["tick"], 0) + 1)
	assert_bool(doc.has("resume_tick")).is_false()
	assert_int(RunFile.target_tick(doc)).is_equal(world.tick)  # no pause notice: the last recorded command
	var paused: Dictionary = RunFile.compose(head, boundary, world.command_log.to_dicts(), world.tick + 40)
	assert_int(paused["resume_tick"]).is_equal(world.tick + 40)
	assert_int(RunFile.target_tick(paused)).is_equal(world.tick + 40)
	var no_rows: Array[Dictionary] = []
	var no_tail: Dictionary = RunFile.compose(head, boundary, no_rows, -1)
	assert_int(RunFile.target_tick(no_tail)).is_equal(RunFile.whole(boundary["tick"], 0))


func test_check_accepts_its_own_document_after_the_trip_through_the_file() -> void:
	var world: SimWorld = _world()
	var back: Dictionary = RunStore.decode(RunStore.encode(_doc(world)))
	assert_int(RunFile.check(back, world.content)).is_equal(RunFile.Verdict.RESUMABLE)
	assert_int(RunFile.check({}, world.content)).is_equal(RunFile.Verdict.NONE)
	assert_int(RunFile.resume_wave(back)).is_equal(1)
	assert_str(RunFile.id_of(back)).is_equal("900-5")


func test_check_calls_another_build_other_content_and_damage_stale() -> void:
	var world: SimWorld = _world()
	var good: Dictionary = RunStore.decode(RunStore.encode(_doc(world)))
	var edits: Dictionary = {
		"build": "9.9.9", "content_hash": "ffffffffffff", "schema_version": 2, "boundary": "gone", "seed": -4, "run_id": "",
	}
	for key: String in edits:
		var doc: Dictionary = good.duplicate()
		doc[key] = edits[key]
		assert_int(RunFile.check(doc, world.content)).override_failure_message(key).is_equal(RunFile.Verdict.STALE)
	var no_state: Dictionary = good.duplicate(true)
	var b: Dictionary = no_state["boundary"]
	b.erase("state")
	assert_int(RunFile.check(no_state, world.content)).is_equal(RunFile.Verdict.STALE)
	assert_int(RunFile.check(good, TestContent.baseline())).is_equal(RunFile.Verdict.STALE)  # other content
	assert_int(RunFile.check(RunStore.decode(SaveTestData.text("run_other_build")), world.content)).is_equal(RunFile.Verdict.STALE)


func test_config_from_gives_the_config_back() -> void:
	var content: ContentSet = TestContent.variety()
	var cfg: SimConfig = SimConfig.create(content, 48211)
	cfg.unlocked = PackedStringArray(["u_b", "u_a"])
	cfg.daily = true
	cfg.debug_start_scrap = 300
	cfg.debug_damage_mult = 50.0
	var doc: Dictionary = RunStore.decode(RunStore.encode(RunFile.header(cfg, "1-48211")))
	var back: SimConfig = RunFile.config_from(doc, content)
	assert_int(back.run_seed).is_equal(48211)
	assert_int(back.kit_index).is_equal(0)
	assert_array(Array(back.unlocked)).is_equal(["u_a", "u_b"])  # sorted, as SimConfig wants it
	assert_bool(back.daily).is_true()
	assert_int(back.debug_start_scrap).is_equal(300)
	assert_float(back.debug_damage_mult).is_equal(50.0)
	assert_bool(back.debug_invulnerable_core).is_false()
	doc["kit"] = "k_does_not_exist"
	assert_int(RunFile.config_from(doc, content).kit_index).is_equal(0)


func test_the_closing_reward_is_a_defeat_at_the_last_saved_wave() -> void:
	var content: ContentSet = TestContent.baseline()
	var doc: Dictionary = RunStore.decode(SaveTestData.text("run_other_build"))
	assert_int(RunFile.waves_cleared(doc)).is_equal(3)
	assert_int(RunFile.resume_wave(doc)).is_equal(4)
	assert_int(RunFile.closing_reward(doc, content)).is_equal(Formulas.data_reward(RunResult.Id.DEFEAT, 3, 0.0, content.mission))
	assert_int(RunFile.closing_reward(doc, content)).is_greater(0)
	var b: Dictionary = doc["boundary"]
	b["wave"] = 999.0  # a damaged number never pays more than the run has waves
	assert_int(RunFile.closing_reward(doc, content)).is_equal(Formulas.data_reward(RunResult.Id.DEFEAT, content.waves.size(), 0.0, content.mission))
	b["wave"] = -3.0
	assert_int(RunFile.closing_reward(doc, content)).is_equal(0)


func test_the_content_hash_is_stable_and_follows_the_numbers_not_the_texts() -> void:
	var a: ContentSet = TestContent.variety()
	var b: ContentSet = TestContent.variety()
	var base: String = ContentFingerprint.of(a)
	assert_str(ContentFingerprint.of(b)).is_equal(base)
	assert_str(ContentFingerprint.of(TestContent.baseline())).is_not_equal(base)
	b.strings["menu.title"] = "another title"
	assert_str(ContentFingerprint.of(b)).is_equal(base)  # wording never ends a run
	b.enemies[0].speed_mps += 0.01
	assert_str(ContentFingerprint.of(b)).is_not_equal(base)
	var c: ContentSet = TestContent.variety()
	c.mission.core_max_hp += 1.0
	assert_str(ContentFingerprint.of(c)).is_not_equal(base)
	var d: ContentSet = TestContent.variety()
	d.waves = GameRunKit.first_waves(d, 2)
	assert_str(ContentFingerprint.of(d)).is_not_equal(base)
	var e: ContentSet = TestContent.variety()
	e.directives[0].max_stacks += 1
	assert_str(ContentFingerprint.of(e)).is_not_equal(base)
	assert_str(ContentFingerprint.of(null)).is_equal("")
