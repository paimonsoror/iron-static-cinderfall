extends GdUnitTestSuite
## V2-D: resume after a kill (VARIETY_SPEC 2.8): the snapshot plus the command tail lands on the same hash as the run
## that was never interrupted; a snapshot that fails its hash check falls back to the full replay; when that fails
## too, or the build or the content changed, the run is closed and paid once as a defeat at the last saved wave.

var _fs: MemorySaveFs
var _content: ContentSet
var _want: Dictionary = {}  ## the uninterrupted reference run (played once per suite)


func before_test() -> void:
	_fs = GameRunKit.fresh_save()
	_content = TestContent.baseline()


func after_test() -> void:
	GameRunKit.reset_save()


func _config(run_seed: int = 3, waves: int = 2) -> SimConfig:
	return VarietyDKit.config(_content, run_seed, waves)


func _start(run_seed: int = 3, waves: int = 2) -> RunController:
	return GameRunKit.controller(self, _config(run_seed, waves), null, "800-%d" % run_seed)


## The run of `_start()` played to its end without an interruption: its final hashes and numbers.
func _reference() -> Dictionary:
	if _want.is_empty():
		var reference: RunController = _start()
		assert_int(VarietyDKit.play_to_end(reference, 40000)).is_greater(0)
		_want = {
			"hash": reference.sim.state_hash(), "events": reference.sim.events.event_hash, "ticks": reference.sim.tick,
			"reward": reference.summary.data_reward, "kills": Array(reference.summary.kills_by_type),
			"spent": reference.summary.scrap_spent, "commands": reference.sim.command_log.entries.size(),
		}
		VarietyDKit.kill(reference)
		_fs = GameRunKit.fresh_save()
	return _want


## Plays into the second wave and stops in the middle of it.
func _into_wave_two(rc: RunController) -> void:
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	VarietyDKit.play(rc, 400)
	assert_int(rc.sim.wave).is_equal(2)
	assert_bool(GameState.is_combat(rc.sim.phase)).is_true()


## A deep copy of the saved run file with one edit, saved again.
func _tamper(edit: Callable) -> Dictionary:
	var doc: Dictionary = VarietyDKit.doc().duplicate(true)
	edit.call(doc)
	assert_bool(Save.save_run(doc)).is_true()
	return doc


func _edit_scrap(doc: Dictionary) -> void:
	var boundary: Dictionary = doc["boundary"]
	var state: Dictionary = boundary["state"]
	var world_doc: Dictionary = state["world"]
	world_doc["scrap"] = 99999.0  # a damaged snapshot: its hash no longer matches


func _edit_drop_nav(doc: Dictionary) -> void:
	var boundary: Dictionary = doc["boundary"]
	var state: Dictionary = boundary["state"]
	state.erase("nav")


func _edit_state_hash(doc: Dictionary) -> void:
	var boundary: Dictionary = doc["boundary"]
	boundary["state_hash"] = "0".repeat(64)  # neither the snapshot nor the replay can match this


func _edit_build(doc: Dictionary) -> void:
	doc["build"] = "0.0.1"


func _edit_late_command(doc: Dictionary) -> void:
	var tail: Array = doc["tail"]
	tail.append({"tick": 99999999, "id": 4242, "kind": 0, "arg": 0})  # a command from after the resume tick


func _defeat_reward(waves: int) -> int:
	return Formulas.data_reward(RunResult.Id.DEFEAT, waves, 0.0, _content.mission)


func test_a_paused_kill_resumes_at_the_same_tick_with_the_same_hash() -> void:
	var rc: RunController = _start()
	_into_wave_two(rc)
	rc.set_paused(true)
	var tick: int = rc.sim.tick
	var state_hash: String = rc.sim.state_hash()
	var event_hash: int = rc.sim.events.event_hash
	var alive: int = rc.sim.alive_count()
	VarietyDKit.kill(rc)
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_str(back.run_id).is_equal("800-3")
	assert_int(back.sim.tick).is_equal(tick)
	assert_str(back.sim.state_hash()).is_equal(state_hash)
	assert_int(back.sim.events.event_hash).is_equal(event_hash)
	assert_int(back.sim.alive_count()).is_equal(alive)
	assert_bool(back.paused).is_false()  # Game pauses a resumed run; the controller leaves that to it
	assert_int(back.sim.config.run_seed).is_equal(3)
	assert_float(back.sim.config.debug_damage_mult).is_equal(50.0)


func test_a_resume_in_the_middle_of_a_fight_brings_the_enemies_back() -> void:
	var cfg: SimConfig = SimConfig.create(_content, 9)
	cfg.debug_invulnerable_core = true  # normal damage: the wave is alive when the kill comes
	var rc: RunController = GameRunKit.controller(self, cfg, null, "800-9")
	GameRunKit.frames(rc, _content.mission.prepare_ticks + 900)
	rc.api.activate_ability(rc.api.next_command_id(), &"emp")
	GameRunKit.frames(rc, 20)
	assert_int(rc.sim.alive_count()).is_greater(0)
	rc.set_paused(true)
	var twin: SimWorld = Replay.run(cfg, rc.sim.command_log, rc.sim.tick)  # the oracle, stepped on from here
	var state_hash: String = rc.sim.state_hash()
	var alive: int = rc.sim.alive_count()
	VarietyDKit.kill(rc)
	var signals: GameSignalLog = GameSignalLog.new()
	signals.attach()
	var back: RunController = VarietyDKit.resumed(self, _content)
	var announced: int = signals.count(&"enemy_spawned")
	signals.detach()
	assert_str(back.sim.state_hash()).is_equal(state_hash)
	assert_str(twin.state_hash()).is_equal(state_hash)
	assert_int(back.sim.alive_count()).is_equal(alive)
	assert_int(announced).is_equal(alive)  # the relay (and through it the view and the HUD) learns who is on the field
	for i: int in 600:
		twin.step()
		twin.events.drain()
	GameRunKit.frames(back, 600)
	assert_str(back.sim.state_hash()).is_equal(twin.state_hash())
	assert_int(back.sim.events.event_hash).is_equal(twin.events.event_hash)


func test_tail_replay_lands_on_the_same_hash_as_the_uninterrupted_run() -> void:
	var want: Dictionary = _reference()
	var rc: RunController = _start()
	_into_wave_two(rc)
	rc.set_paused(true)
	VarietyDKit.kill(rc)
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(VarietyDKit.play_to_end(back, 40000)).is_greater(0)
	assert_str(back.sim.state_hash()).is_equal(str(want["hash"]))
	assert_int(back.sim.events.event_hash).is_equal(want["events"])
	assert_int(back.summary.result).is_equal(RunResult.Id.VICTORY)
	assert_int(back.summary.duration_ticks).is_equal(want["ticks"])
	assert_int(back.summary.data_reward).is_equal(want["reward"])
	assert_array(Array(back.summary.kills_by_type)).is_equal(want["kills"])
	assert_int(back.summary.scrap_spent).is_equal(want["spent"])
	assert_int(back.sim.command_log.entries.size()).is_equal(want["commands"])


func test_a_crash_without_a_pause_notice_resumes_at_the_last_recorded_choice() -> void:
	var want: Dictionary = _reference()
	var rc: RunController = _start()
	_into_wave_two(rc)
	var killed_at: int = rc.sim.tick
	var wave_start: int = rc.sim.stats.wave_start_tick[2]
	var last_choice: int = RunFile.target_tick(VarietyDKit.doc())
	assert_int(last_choice).is_equal(wave_start)  # the CONTINUE that started the wave is the last recorded choice
	assert_bool(VarietyDKit.doc().has("resume_tick")).is_false()
	VarietyDKit.kill(rc)  # no pause, no notice
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_int(back.sim.tick).is_equal(last_choice)
	assert_int(back.sim.tick).is_less(killed_at)
	assert_int(back.sim.waves_completed).is_equal(1)
	assert_int(back.sim.wave).is_equal(2)  # the wave starts again
	# the wave it gives back is the same wave: the run ends exactly as the uninterrupted one
	assert_int(VarietyDKit.play_to_end(back, 40000)).is_greater(0)
	assert_str(back.sim.state_hash()).is_equal(str(want["hash"]))
	assert_int(back.sim.events.event_hash).is_equal(want["events"])


func test_a_hash_mismatch_falls_back_to_the_full_replay() -> void:
	var want: Dictionary = _reference()
	var rc: RunController = _start()
	_into_wave_two(rc)
	rc.set_paused(true)
	var tick: int = rc.sim.tick
	var state_hash: String = rc.sim.state_hash()
	var event_hash: int = rc.sim.events.event_hash
	VarietyDKit.kill(rc)
	_tamper(_edit_scrap)
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.FULL_REPLAY)
	assert_int(back.sim.tick).is_equal(tick)
	assert_str(back.sim.state_hash()).is_equal(state_hash)
	assert_int(back.sim.events.event_hash).is_equal(event_hash)
	assert_int(Save.profile.runs_played).is_equal(0)  # nothing was closed, nothing was paid
	assert_dict(VarietyDKit.doc()).is_not_empty()
	assert_int(VarietyDKit.play_to_end(back, 40000)).is_greater(0)
	assert_str(back.sim.state_hash()).is_equal(str(want["hash"]))  # and it ends like the uninterrupted run


func test_a_snapshot_of_another_shape_falls_back_to_the_full_replay_too() -> void:
	var rc: RunController = _start()
	_into_wave_two(rc)
	rc.set_paused(true)
	var state_hash: String = rc.sim.state_hash()
	VarietyDKit.kill(rc)
	_tamper(_edit_drop_nav)
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.FULL_REPLAY)
	assert_str(back.sim.state_hash()).is_equal(state_hash)


func test_when_the_full_replay_fails_too_the_run_is_closed_and_paid_once() -> void:
	var rc: RunController = _start()
	_into_wave_two(rc)
	rc.set_paused(true)
	VarietyDKit.kill(rc)
	var bad: Dictionary = _tamper(_edit_state_hash)
	var back: RunController = VarietyDKit.resumed(self, _content)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.FAILED)
	assert_object(back.sim).is_null()
	assert_int(Save.profile.data).is_equal(_defeat_reward(1))  # one wave was saved as cleared
	assert_int(_defeat_reward(1)).is_greater(0)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_bool(Save.profile.awarded_run_ids.has("800-3")).is_true()
	assert_dict(VarietyDKit.doc()).is_empty()  # the file is gone
	# the same file again (a restored backup, a second launch): nothing more is paid
	assert_bool(Save.save_run(bad)).is_true()
	var again: RunController = VarietyDKit.resumed(self, _content)
	assert_int(again.resume_mode).is_equal(RunResume.Mode.FAILED)
	assert_int(Save.profile.data).is_equal(_defeat_reward(1))
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_dict(VarietyDKit.doc()).is_empty()


func test_a_run_file_of_another_build_is_closed_and_paid_once() -> void:
	var rc: RunController = _start(3, 3)
	assert_int(VarietyDKit.play_until_cleared(rc, 2, 30000)).is_greater(0)
	rc.set_paused(true)
	VarietyDKit.kill(rc)
	var old: Dictionary = _tamper(_edit_build)
	assert_int(RunFile.check(old, _content)).is_equal(RunFile.Verdict.STALE)
	assert_int(GameRunFlow.resumable_wave(_content)).is_equal(0)  # what the menu asks at launch
	assert_int(Save.profile.data).is_equal(_defeat_reward(2))
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.missions_completed).is_equal(0)
	assert_dict(VarietyDKit.doc()).is_empty()
	assert_int(GameRunFlow.resumable_wave(_content)).is_equal(0)
	assert_bool(Save.save_run(old)).is_true()
	assert_int(GameRunFlow.resumable_wave(_content)).is_equal(0)  # the id was paid: closed again, not paid again
	var direct: RunController = VarietyDKit.resumed(self, _content)
	assert_int(direct.resume_mode).is_equal(RunResume.Mode.FAILED)
	assert_int(Save.profile.data).is_equal(_defeat_reward(2))
	assert_int(Save.profile.runs_played).is_equal(1)
	# the payment is on disk
	assert_int(ProfileCodec.decode(_fs.read(Save.PATH_MAIN)).profile.data).is_equal(_defeat_reward(2))


func test_a_run_file_made_with_other_content_is_closed_and_paid_once() -> void:
	var rc: RunController = _start()
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	VarietyDKit.kill(rc)
	var tuned: ContentSet = TestContent.baseline()
	tuned.waves = GameRunKit.first_waves(tuned, 2)
	tuned.enemies[0].hp += 1.0  # a balance patch between the kill and the next launch
	var back: RunController = VarietyDKit.resumed(self, tuned)
	assert_int(back.resume_mode).is_equal(RunResume.Mode.FAILED)
	assert_object(back.sim).is_null()
	assert_int(Save.profile.data).is_equal(_defeat_reward(1))
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_dict(VarietyDKit.doc()).is_empty()


func test_the_fixture_file_of_an_old_build_pays_its_three_waves_once() -> void:
	var doc: Dictionary = RunStore.decode(SaveTestData.text("run_other_build"))
	assert_bool(Save.save_run(doc)).is_true()
	assert_int(GameRunFlow.resumable_wave(_content)).is_equal(0)
	assert_int(Save.profile.data).is_equal(_defeat_reward(3))
	assert_bool(Save.save_run(doc)).is_true()
	assert_int(GameRunFlow.resumable_wave(_content)).is_equal(0)
	assert_int(Save.profile.data).is_equal(_defeat_reward(3))
	assert_bool(Save.profile.awarded_run_ids.has("1700000000-4242")).is_true()


func test_a_run_is_rewarded_once_however_often_it_is_resumed() -> void:
	var rc: RunController = _start(4, 2)
	var before_finish: Dictionary = {}
	for round_index: int in 3:
		VarietyDKit.play(rc, 300)
		rc.set_paused(true)
		before_finish = VarietyDKit.doc()
		VarietyDKit.kill(rc)
		rc = VarietyDKit.resumed(self, _content)
		assert_str(rc.run_id).is_equal("800-4")
	assert_int(Save.profile.runs_played).is_equal(0)
	assert_int(VarietyDKit.play_to_end(rc, 40000)).is_greater(0)
	var reward: int = rc.summary.data_reward
	assert_bool(rc.reward_granted).is_true()
	assert_int(Save.profile.data).is_equal(reward)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_dict(VarietyDKit.doc()).is_empty()
	# an old copy of the file comes back (a restored backup): the run can be played out again, but not paid again
	assert_bool(Save.save_run(before_finish)).is_true()
	var replayed: RunController = VarietyDKit.resumed(self, _content)
	assert_int(VarietyDKit.play_to_end(replayed, 40000)).is_greater(0)
	assert_bool(replayed.reward_granted).is_false()
	assert_int(Save.profile.data).is_equal(reward)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(1)
	assert_dict(VarietyDKit.doc()).is_empty()


func test_a_resumed_run_mints_command_ids_it_has_not_used() -> void:
	var rc: RunController = _start()
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	VarietyDKit.play(rc, 3)  # the player buys in the intermission
	rc.set_paused(true)
	var highest: int = 0
	for seen: int in rc.sim.phase_state.seen_command_ids:
		highest = maxi(highest, seen)
	assert_int(highest).is_greater(0)
	VarietyDKit.kill(rc)
	var back: RunController = VarietyDKit.resumed(self, _content)
	var minted: int = back.api.next_command_id()
	assert_int(minted).is_equal(highest + 1)
	var signals: GameSignalLog = GameSignalLog.new()
	signals.attach()
	back.sim.scrap = 9000
	back.api.purchase_upgrade(minted, &"fire_rate")
	back.step_frame(VarietyDKit.DT)
	var resolved: Array = signals.first_args(&"purchase_resolved")
	signals.detach()
	assert_bool(resolved[1]).is_true()  # accepted, not DUPLICATE_COMMAND


func test_a_tail_that_does_not_fit_the_run_closes_it() -> void:
	var rc: RunController = _start()
	assert_int(VarietyDKit.play_until_cleared(rc, 1, 20000)).is_greater(0)
	rc.set_paused(true)
	VarietyDKit.kill(rc)
	_tamper(_edit_late_command)
	var result: RunResumeResult = RunResume.rebuild(VarietyDKit.doc(), _content)
	assert_bool(result.ok()).is_false()
	assert_int(result.mode).is_equal(RunResume.Mode.FAILED)
	assert_str(result.reason).is_not_empty()


func test_a_resume_inside_a_choice_lands_in_the_choice_and_thinking_costs_no_tick() -> void:
	# The sim holds its tick while it waits for a choice. A snapshot taken there, plus the choices made since, gives
	# the same world, however many frames the player spent thinking before the kill.
	var content: ContentSet = TestContent.variety()
	var world: SimWorld = SimWorld.new(VarietyDKit.config(content, 6))
	assert_bool(VarietyDKit.step_until_cleared(world, 1, 40000)).is_true()
	world.phase_state.awaiting = PhaseState.Await.DRAFT  # what the wave clear of task V2-A will do
	var head: Dictionary = RunFile.header(world.config, "800-6")
	var boundary: Dictionary = RunFile.boundary(world)
	for thinking: int in 500:
		world.step()
	assert_int(world.tick).is_equal(RunFile.whole(boundary["tick"], -1))
	world.submit(SimCommand.reroll(71))
	world.step()
	for thinking: int in 200:
		world.step()
	world.submit(SimCommand.pick_directive(72, 1))
	world.step()
	world.events.drain()
	assert_int(world.tick).is_equal(RunFile.whole(boundary["tick"], -1) + 2)
	var doc: Dictionary = RunStore.decode(RunStore.encode(RunFile.compose(head, boundary, world.command_log.to_dicts(), -1)))
	var result: RunResumeResult = RunResume.rebuild(doc, content)
	assert_int(result.mode).is_equal(RunResume.Mode.SNAPSHOT)
	assert_int(result.world.tick).is_equal(world.tick)
	assert_int(result.world.phase_state.awaiting).is_equal(PhaseState.Await.DRAFT)
	assert_str(result.world.state_hash()).is_equal(world.state_hash())
	assert_int(result.world.events.event_hash).is_equal(world.events.event_hash)
	assert_int(result.world.command_log.entries.size()).is_equal(world.command_log.entries.size())
