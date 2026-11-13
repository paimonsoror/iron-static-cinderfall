extends GdUnitTestSuite
## AudioVarietyRoutes: the interface, the crate and the drone. A fake source node stands in for `Events`. The data pins read
## the frozen variety fixture, never `res://data/`.

var _events: AudioTestEvents
var _dir: AudioDirector


func before_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	_events = auto_free(AudioTestEvents.new())
	add_child(_events)
	_dir = AudioTestKit.make_routed(self, _events)


func after_test() -> void:
	Save.use_fs(MemorySaveFs.new())
	@warning_ignore("return_value_discarded")
	Save.load_profile()
	Sfx.apply_settings()


func _last() -> StringName:
	return _dir.recent_ids.back() if not _dir.recent_ids.is_empty() else &""


func test_a_corrupted_directive_has_its_own_stamp_and_the_others_the_plain_one() -> void:
	for id: StringName in AudioVarietyRoutes.CORRUPTED_DIRECTIVES:
		_dir.gate.clear()
		_events.directive_picked.emit(id, 1)
		assert_that(_last()).override_failure_message(String(id)).is_equal(&"draft_pick_corrupted")
	for id: StringName in [&"hot_loads", &"emp_capacitor", &"turret_deploy", &"no_such_directive"]:
		_dir.gate.clear()
		_events.directive_picked.emit(id, 1)
		assert_that(_last()).override_failure_message(String(id)).is_equal(&"draft_pick")


func test_the_mirrored_corrupted_list_holds_every_corrupted_directive_of_the_data() -> void:
	var content: ContentSet = TestContent.variety()
	var found: int = 0
	for def: DirectiveDef in content.directives:
		if def.category == DirectiveDef.Category.CORRUPTED:
			found += 1
			assert_bool(AudioVarietyRoutes.CORRUPTED_DIRECTIVES.has(def.id)).override_failure_message(
				"%s is corrupted in the data but not in AudioVarietyRoutes.CORRUPTED_DIRECTIVES" % String(def.id)
			).is_true()
		else:
			assert_bool(AudioVarietyRoutes.CORRUPTED_DIRECTIVES.has(def.id)).override_failure_message(
				"%s is in the mirrored corrupted list but not corrupted in the data" % String(def.id)
			).is_false()
	assert_int(found).is_greater(0)
	assert_int(AudioVarietyRoutes.CORRUPTED_DIRECTIVES.size()).is_equal(9)  # CONTENT 3.6


func test_the_mirrored_wave_budgets_are_the_budgets_of_the_data() -> void:
	var waves: Array[WaveSlotDef] = TestContent.variety().run.waves
	assert_int(AudioVarietyRoutes.WAVE_BUDGETS.size()).is_equal(AudioVarietyRoutes.WAVES_PER_ACT * 3)
	for i: int in mini(waves.size(), AudioVarietyRoutes.WAVE_BUDGETS.size()):
		assert_float(float(AudioVarietyRoutes.WAVE_BUDGETS[i])).override_failure_message("wave %d" % (i + 1)).is_equal(waves[i].budget)
		var is_boss: bool = waves[i].kind == WaveSlotDef.Kind.BOSS
		assert_bool(is_boss).override_failure_message("wave %d" % (i + 1)).is_equal((i + 1) % AudioVarietyRoutes.WAVES_PER_ACT == 0)


func test_the_drone_follows_the_budget_of_the_wave_inside_its_act() -> void:
	# act I: normal waves 24, 34, 46, 60 and the boss wave
	assert_float(AudioVarietyRoutes.budget_position(1, 1)).is_equal_approx(0.0, 0.0001)
	assert_float(AudioVarietyRoutes.budget_position(1, 2)).is_equal_approx(10.0 / 36.0, 0.0001)
	assert_float(AudioVarietyRoutes.budget_position(1, 3)).is_equal_approx(22.0 / 36.0, 0.0001)
	assert_float(AudioVarietyRoutes.budget_position(1, 4)).is_equal_approx(1.0, 0.0001)
	assert_float(AudioVarietyRoutes.budget_position(1, 5)).is_equal_approx(1.0, 0.0001)  # the boss wave: its budget is lower, it is the top
	assert_float(AudioVarietyRoutes.budget_position(3, 15)).is_equal_approx(1.0, 0.0001)
	# the levels stay inside the band of the act and rise from act to act
	for wave: int in range(1, 16):
		var act: int = clampi(floori(float(wave - 1) / 5.0) + 1, 1, 3)
		var span: Vector2 = AudioVarietyRoutes.ACT_INTENSITY[act - 1]
		assert_float(AudioVarietyRoutes.intensity_for_act(act, wave)).override_failure_message("wave %d" % wave).is_between(span.x, span.y)
	assert_float(AudioVarietyRoutes.intensity_for_act(2, 6)).is_greater(AudioVarietyRoutes.intensity_for_act(1, 5) + 0.04)
	# a heavier wave of the same act is never quieter, and the boss wave is the loudest of its act
	assert_float(AudioVarietyRoutes.intensity_for_act(2, 9)).is_greater(AudioVarietyRoutes.intensity_for_act(2, 8))
	assert_float(AudioVarietyRoutes.intensity_for_act(2, 10)).is_greater_equal(AudioVarietyRoutes.intensity_for_act(2, 9))


func test_a_reroll_has_its_own_sound_and_the_old_drawer_sound_is_gone_from_the_draft() -> void:
	var offer: Array[StringName] = [&"hot_loads", &"cyclic_tuning", &"glass_cannon"]
	_events.draft_offered.emit(offer)
	_dir.gate.clear()
	_events.draft_offered.emit(offer)
	assert_that(_last()).is_equal(&"draft_reroll")
	assert_array(_dir.recent_ids).is_equal([&"draft_open", &"draft_reroll"])
	assert_that(AudioVarietyRoutes.REROLL_SOUND).is_not_equal(&"ui_drawer")


func test_the_salvage_opens_with_the_crate_and_ends_with_a_stamp_once() -> void:
	_events.await_changed.emit(RunApi.AWAIT_SALVAGE)
	assert_int(_dir.started_total).is_equal(0)  # the await itself is silent
	_events.salvage_offered.emit()
	assert_that(_last()).is_equal(&"salvage_open")
	_dir.gate.clear()
	_events.await_changed.emit(RunApi.AWAIT_DRAFT)  # the crate was taken or scrapped, the draft is next
	assert_that(_last()).is_equal(&"draft_pick")
	var after: int = _dir.started_total
	_events.await_changed.emit(RunApi.AWAIT_NONE)  # a draft that ends is not a salvage that ends
	assert_int(_dir.started_total).is_equal(after)
	assert_array(_dir.recent_ids).is_equal([&"salvage_open", &"draft_pick"])


func test_a_new_run_forgets_the_await_so_the_first_end_of_a_wait_is_silent() -> void:
	_events.await_changed.emit(RunApi.AWAIT_SALVAGE)
	_events.run_started.emit("r", 9)
	var before: int = _dir.started_total
	_events.await_changed.emit(RunApi.AWAIT_NONE)
	assert_int(_dir.started_total).is_equal(before)
	await VarietyGKit.settle(self, _dir)


func test_the_archive_the_acts_and_the_crate_on_the_field() -> void:
	_events.unlock_purchased.emit(&"u_w_torch")
	assert_that(_last()).is_equal(&"unlock_buy")
	_events.act_started.emit(1)  # act 1 begins with the run: the wave horn is its sound
	assert_int(_dir.started_total).is_equal(1)
	assert_int(_dir.router.variety.act).is_equal(1)
	_events.act_started.emit(2)
	assert_that(_last()).is_equal(&"act_start")
	_dir.gate.clear()
	_events.act_started.emit(3)
	assert_int(VarietyGKit.count_id(_dir, &"act_start")).is_equal(2)
	_events.crate_dropped.emit(2.0, -3.0)
	assert_that(_last()).is_equal(&"crate_land")
	_events.crate_secured.emit()
	assert_that(_last()).is_equal(&"crate_secured")
	_dir.gate.clear()
	_events.crate_lost.emit()
	assert_that(_last()).is_equal(&"crate_lost")


func test_the_interface_sounds_play_while_the_game_is_paused_and_the_game_sounds_do_not() -> void:
	# a resumed run comes up paused with its overlay: the interface must be heard then
	_dir.pause_all()
	for id: StringName in VarietyGKit.UI_IDS:
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message("%s while paused" % String(id)).is_true()
	for id: StringName in [&"crate_land", &"act_start", &"warn_harm", &"shot_lmg", &"lance_charge"]:
		_dir.gate.clear()
		assert_bool(_dir.try_play(id)).override_failure_message("%s while paused" % String(id)).is_false()
	_dir.resume_all()
	await VarietyGKit.settle(self, _dir)


func test_the_resume_link_is_played_by_name_and_is_an_interface_sound() -> void:
	assert_bool(AudioCatalog.has_sound(&"resume_link")).is_true()
	assert_int(AudioCatalog.voice_class(&"resume_link")).is_equal(AudioCatalog.CLASS_UI)
	assert_bool(_dir.try_play(&"resume_link")).is_true()  # what `Sfx.play(&"resume_link")` does for the RESUME RUN button
	assert_that(_last()).is_equal(&"resume_link")
