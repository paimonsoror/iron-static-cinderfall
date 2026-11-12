extends GdUnitTestSuite
## V2-D: when the run file is written (VARIETY_SPEC 2.8): at the start and at every wave clear (a new boundary, an empty
## tail), after a command outside combat (the tail grows), on a pause or when the app goes to the background (the tail
## with the running wave's commands and `resume_tick`); and when it is deleted (the run ended or was given up).

var _fs: MemorySaveFs
var _content: ContentSet


func before_test() -> void:
	_fs = GameRunKit.fresh_save()
	_content = TestContent.baseline()


func after_test() -> void:
	GameRunKit.reset_save()


func _controller(run_seed: int = 3, waves: int = 3) -> RunController:
	return GameRunKit.controller(self, VarietyDKit.config(_content, run_seed, waves), null, "700-%d" % run_seed)


func _boundary() -> Dictionary:
	return RunFile.boundary_of(VarietyDKit.doc())


func _rows(key: String) -> Array:
	var rows: Array = VarietyDKit.doc().get(key, [])
	return rows


func test_the_start_of_a_run_writes_the_file_with_the_snapshot_of_tick_zero() -> void:
	var rc: RunController = _controller()
	var doc: Dictionary = VarietyDKit.doc()
	assert_int(RunFile.check(doc, _content)).is_equal(RunFile.Verdict.RESUMABLE)
	assert_str(RunFile.id_of(doc)).is_equal("700-3")
	assert_int(RunFile.whole(doc["seed"], -1)).is_equal(3)
	assert_int(RunFile.waves_cleared(doc)).is_equal(0)
	assert_int(RunFile.whole(_boundary()["tick"], -1)).is_equal(0)
	assert_str(str(_boundary()["state_hash"])).is_equal(SimWorld.new(rc.sim.config).state_hash())
	assert_int(_rows("tail").size()).is_equal(0)
	assert_bool(doc.has("resume_tick")).is_false()
	assert_int(rc.files.writes).is_equal(1)


func test_every_wave_clear_writes_a_new_boundary_with_an_empty_tail() -> void:
	var rc: RunController = _controller(3, 3)
	for cleared: int in [1, 2]:
		assert_int(VarietyDKit.play_until_cleared(rc, cleared, 20000)).is_greater(0)
		var b: Dictionary = _boundary()
		var clear_tick: int = rc.sim.stats.wave_clear_tick[cleared]
		assert_int(RunFile.whole(b["wave"], -1)).is_equal(cleared)
		assert_int(RunFile.whole(b["tick"], -1)).is_equal(clear_tick)  # the tick that cleared the wave, not a later one
		assert_int(_rows("tail").size()).is_equal(0)
		assert_bool(VarietyDKit.doc().has("resume_tick")).is_false()
		# the saved hash is the hash an independent replay of the log has at that tick
		var oracle: SimWorld = Replay.run(rc.sim.config, RunFile.commands(VarietyDKit.doc(), "log"), clear_tick)
		assert_str(str(b["state_hash"])).is_equal(oracle.state_hash())
	assert_int(rc.files.boundaries).is_equal(3)  # the start and two wave clears


func test_a_30_fps_frame_still_snapshots_the_tick_of_the_wave_clear() -> void:
	var rc: RunController = _controller(4, 2)
	for i: int in 20000:
		if rc.sim.waves_completed >= 1:
			break
		VarietyDKit.decide(rc)
		rc.step_frame(4.0 / 60.0)  # four ticks per frame: the clear can fall on any of them
	assert_int(rc.sim.waves_completed).is_equal(1)
	assert_int(RunFile.whole(_boundary()["tick"], -1)).is_equal(rc.sim.stats.wave_clear_tick[1])
	var oracle: SimWorld = Replay.run(rc.sim.config, RunFile.commands(VarietyDKit.doc(), "log"), rc.sim.stats.wave_clear_tick[1])
	assert_str(str(_boundary()["state_hash"])).is_equal(oracle.state_hash())


func test_a_command_in_the_intermission_makes_the_tail_grow() -> void:
	var rc: RunController = _controller()
	VarietyDKit.play_until_cleared(rc, 1, 20000)
	assert_int(rc.sim.phase).is_equal(GameState.Id.INTERMISSION)
	var writes: int = rc.files.writes
	rc.api.purchase_upgrade(rc.api.next_command_id(), &"damage")
	rc.step_frame(VarietyDKit.DT)
	assert_int(_rows("tail").size()).is_equal(1)
	assert_int(rc.files.writes).is_equal(writes + 1)
	rc.step_frame(VarietyDKit.DT)  # a frame without a command writes nothing
	assert_int(rc.files.writes).is_equal(writes + 1)
	rc.api.skip_intermission()
	rc.step_frame(VarietyDKit.DT)
	var tail: Array = _rows("tail")
	assert_int(tail.size()).is_equal(2)
	var last: Dictionary = tail[1]
	assert_int(RunFile.whole(last["kind"], -1)).is_equal(SimCommand.Kind.SKIP_INTERMISSION)
	assert_int(RunFile.whole(last["tick"], -1)).is_equal(rc.sim.tick)
	assert_bool(VarietyDKit.doc().has("resume_tick")).is_false()
	assert_int(RunFile.target_tick(VarietyDKit.doc())).is_equal(rc.sim.tick)


func test_a_command_during_a_wave_is_written_by_the_next_pause_with_the_resume_tick() -> void:
	var rc: RunController = _controller()
	GameRunKit.frames(rc, _content.mission.prepare_ticks + 200)
	var writes: int = rc.files.writes
	rc.api.activate_ability(rc.api.next_command_id(), &"emp")
	GameRunKit.frames(rc, 30)
	assert_int(rc.files.writes).is_equal(writes)  # no disk work in a combat frame
	assert_int(_rows("tail").size()).is_equal(0)
	rc.set_paused(true)
	var doc: Dictionary = VarietyDKit.doc()
	assert_int(_rows("tail").size()).is_equal(1)
	assert_int(RunFile.whole(doc["resume_tick"], -1)).is_equal(rc.sim.tick)
	assert_int(rc.files.writes).is_equal(writes + 1)
	rc.set_paused(true)  # already paused: nothing more
	rc.set_paused(false)
	rc.set_paused(true)  # the same tick and the same log: the file is already right
	assert_int(rc.files.writes).is_equal(writes + 1)


func test_app_pause_writes_the_resume_tick() -> void:
	var rc: RunController = _controller()
	GameRunKit.frames(rc, _content.mission.prepare_ticks + 333)
	rc.api.activate_ability(rc.api.next_command_id(), &"shield")
	GameRunKit.frames(rc, 5)
	assert_bool(VarietyDKit.doc().has("resume_tick")).is_false()
	var shell: MobileShell = MobileShell.new()
	auto_free(shell)
	add_child(shell)
	shell.lifecycle_enabled = true
	shell.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var doc: Dictionary = VarietyDKit.doc()
	assert_int(RunFile.whole(doc["resume_tick"], -1)).is_equal(rc.sim.tick)
	assert_int(rc.sim.tick).is_equal(_content.mission.prepare_ticks + 338)
	assert_int(_rows("tail").size()).is_equal(1)  # the wave's own command is in the tail
	assert_bool(rc.paused).is_false()  # the shell only writes; Game pauses on `app_paused`
	# the same through the focus notification, after more play
	GameRunKit.frames(rc, 40)
	shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(RunFile.whole(VarietyDKit.doc()["resume_tick"], -1)).is_equal(rc.sim.tick)


func test_app_pause_without_a_run_writes_no_run_file() -> void:
	var shell: MobileShell = MobileShell.new()
	auto_free(shell)
	add_child(shell)
	shell.on_app_paused()
	assert_dict(VarietyDKit.doc()).is_empty()
	assert_bool(RunController.save_active_on_pause()).is_false()


func test_the_file_is_deleted_when_the_run_ends() -> void:
	var rc: RunController = _controller(5, 1)
	assert_dict(VarietyDKit.doc()).is_not_empty()
	assert_int(VarietyDKit.play_to_end(rc, 20000)).is_greater(0)
	assert_dict(VarietyDKit.doc()).is_empty()
	assert_bool(RunStore.exists(_fs)).is_false()
	assert_bool(rc.reward_granted).is_true()
	rc.set_paused(true)  # a finished run never writes again
	assert_bool(RunController.save_active_on_pause()).is_false()
	assert_dict(VarietyDKit.doc()).is_empty()


func test_giving_a_run_up_deletes_the_file_and_a_plain_stop_keeps_it() -> void:
	var rc: RunController = _controller()
	GameRunKit.frames(rc, 50)
	rc.stop()  # the process going down: the file must survive
	assert_dict(VarietyDKit.doc()).is_not_empty()
	var again: RunController = _controller(6)
	GameRunKit.frames(again, 50)
	again.abandon()  # restart or quit to the menu
	assert_dict(VarietyDKit.doc()).is_empty()
	assert_object(again.sim).is_null()
	assert_int(Save.profile.runs_played).is_equal(0)  # giving up pays nothing


func test_a_debug_scenario_and_a_switched_off_controller_write_no_file() -> void:
	var rc: RunController = RunController.new()
	auto_free(rc)
	add_child(rc)
	rc.scenario = GameHoldScenario.new(5, 1)
	rc.start(VarietyDKit.config(_content, 1), "700-1", null)
	rc.set_process(false)
	assert_object(rc.files).is_null()
	assert_dict(VarietyDKit.doc()).is_empty()
	var off: RunController = RunController.new()
	auto_free(off)
	add_child(off)
	off.write_run_file = false
	off.start(VarietyDKit.config(_content, 1), "700-1", null)
	off.set_process(false)
	off.set_paused(true)
	assert_dict(VarietyDKit.doc()).is_empty()


func test_a_failed_write_is_counted_and_the_next_occasion_writes_again() -> void:
	var rc: RunController = _controller()
	GameRunKit.frames(rc, _content.mission.prepare_ticks + 100)
	_fs.fail_writes = true
	rc.set_paused(true)
	assert_int(rc.files.failed_writes).is_equal(1)
	assert_bool(VarietyDKit.doc().has("resume_tick")).is_false()  # the file of the start is still there
	_fs.fail_writes = false
	rc.set_paused(false)
	GameRunKit.frames(rc, 10)
	rc.set_paused(true)
	assert_int(RunFile.whole(VarietyDKit.doc()["resume_tick"], -1)).is_equal(rc.sim.tick)


func test_the_variety_content_writes_the_same_kind_of_file() -> void:
	var content: ContentSet = TestContent.variety()
	var rc: RunController = GameRunKit.controller(self, VarietyDKit.config(content, 2, 2), null, "700-2")
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	var doc: Dictionary = VarietyDKit.doc()
	assert_int(RunFile.check(doc, content)).is_equal(RunFile.Verdict.RESUMABLE)
	assert_str(str(doc["kit"])).is_equal("k_standard")
	assert_int(RunFile.waves_cleared(doc)).is_equal(1)
	assert_int(RunFile.resume_wave(doc)).is_equal(2)
	assert_int(_fs.read(RunStore.PATH_MAIN).length()).is_less(400000)


func test_a_boundary_write_is_cheap_enough_for_a_wave_clear() -> void:
	# A wave clear writes once: the snapshot, its hash, the JSON text and the file. Measured here on the larger
	# (variety) store; the limit is generous because the machine is shared. The phone number is V2-P's to take.
	var content: ContentSet = TestContent.variety()
	var world: SimWorld = SimWorld.new(VarietyDKit.config(content, 2))
	assert_bool(VarietyDKit.step_until_cleared(world, 2, 40000)).is_true()
	var head: Dictionary = RunFile.header(world.config, "700-2")
	var best: int = 1 << 40
	for i: int in 5:
		var t0: int = Time.get_ticks_usec()
		var doc: Dictionary = RunFile.compose(head, RunFile.boundary(world), world.command_log.to_dicts(), -1)
		assert_bool(Save.save_run(doc)).is_true()
		best = mini(best, Time.get_ticks_usec() - t0)
	var t1: int = Time.get_ticks_usec()
	var result: RunResumeResult = RunResume.rebuild(Save.load_run(), content)
	var resume_usec: int = Time.get_ticks_usec() - t1
	assert_bool(result.ok()).is_true()
	var t2: int = Time.get_ticks_usec()
	ContentFingerprint.of(content)
	var hash_usec: int = Time.get_ticks_usec() - t2
	print("[V2-D] boundary write %.2f ms, file %d bytes, load+rebuild %.2f ms, content hash %.2f ms" % [
		float(best) / 1000.0, _fs.read(RunStore.PATH_MAIN).length(), float(resume_usec) / 1000.0, float(hash_usec) / 1000.0])
	assert_int(best).is_less(60000)
