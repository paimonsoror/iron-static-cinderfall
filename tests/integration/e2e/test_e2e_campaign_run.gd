extends GdUnitTestSuite
## The 15-wave game end to end through the real Game on the shipped data (WORK_PLAN card V5-A): the real sim,
## RunController, BattleView, CombatHud and the choice overlays.
##  - a victory: `--autoplay=balanced --seed=1 --unlock=all` with debug_damage_mult x4 (the debug build of the card: fast
##    and certain, whatever the balance of the day is) plays the three acts to the end, answering every await (salvage,
##    draft, route, boss briefing);
##  - a defeat: `--autoplay=none --seed=2` falls in act I.
##    For both: each await shows exactly one overlay (the right one, above the HUD), the run ends on the results screen,
##    is paid once and leaves no run file; the two runs are visibly different games. Both are played once in before().
##  - a run driven by hand is killed in the background at every kind of boundary (mid-wave, mid-draft, at the act
##    boundary after a boss wave, in the first wave of the next act, during a boss wave) and comes back from the menu's
##    RESUME RUN button, paused, at the same tick with the same state and the same choice on screen; the back gesture
##    pauses on a choice and never dismisses it; the run then ends once and is paid once.

const OVERLAYS: Dictionary[int, StringName] = {
	RunApi.AWAIT_SALVAGE: &"SalvageOverlay", RunApi.AWAIT_DRAFT: &"DraftOverlay",
	RunApi.AWAIT_ROUTE: &"RouteOverlay", RunApi.AWAIT_BOSS_BRIEF: &"BossBriefOverlay",
}
const WAVES: int = 15
const BOSS_WAVES: Array[int] = [5, 10, 15]
const WIN_ARGS: PackedStringArray = ["--autoplay=balanced", "--seed=1", "--unlock=all"]
const LOSS_ARGS: PackedStringArray = ["--autoplay=none", "--seed=2"]

var _h: GameHarness
var _win: Facts
var _loss: Facts
var _awaits: Dictionary[int, int] = {}  ## await kind -> times it opened in the run being played
var _problems: PackedStringArray = PackedStringArray()


## What a player could see of one finished run.
class Facts:
	extends RefCounted
	var frames: int = 0
	var state: int = 0
	var result: int = 0
	var waves: int = 0
	var act: int = 0
	var state_hash: String = ""
	var plan: String = ""
	var packs: String = ""
	var stacks: Array = []
	var first_offer: Array = []
	var awaits: Dictionary[int, int] = {}
	var problems: String = ""
	var results_title: String = ""
	var waves_text: String = ""
	var hud_gone: bool = false
	var hud_children: int = -1
	var reward: int = 0
	var banked: int = 0
	var profile_data: int = 0
	var runs_played: int = 0
	var awarded: int = 0
	var finished: int = 0
	var run_file: bool = true
	var regrant: bool = true
	var data_after_regrant: int = 0
	var routes: int = 0
	var picks: int = 0
	var salvage: int = 0
	var acts_started: int = 0
	var bosses_spawned: int = 0
	var slot_two: int = -1
	var armed: int = 0
	var bursters: int = 0  ## bursters that spawned


func before() -> void:
	_win = _play_autoplay(WIN_ARGS, IntegrationKit.boost_x4)
	_loss = _play_autoplay(LOSS_ARGS, Callable())


func after_test() -> void:
	_end_process()


# --- the bot runs ---


## Plays one whole `--autoplay` run through Game and returns what a player could see of it.
func _play_autoplay(args: PackedStringArray, hook: Callable) -> Facts:
	_awaits = {}
	_problems = PackedStringArray()
	_h = GameHarness.create(self, args, Callable(), HarnessKit.shipped())
	if hook.is_valid():
		_h.game.set(&"sim_config_hook", hook)
	_h.boot()
	Events.await_changed.connect(_on_await)
	var f: Facts = Facts.new()
	f.frames = _h.frames_until_over(SimHarness.VARIETY_MAX_TICKS)
	Events.await_changed.disconnect(_on_await)
	var sim: SimWorld = _h.rc().sim
	var results: ResultsScreen = _h.find_in("ScreenRoot", &"ResultsScreen") as ResultsScreen
	var packs: PackedStringArray = PackedStringArray()
	for wave_number: int in range(1, sim.plan.wave_count() + 1):
		var option: RouteOption = sim.plan.option(wave_number)
		packs.append("-" if option.pack_index < 0 else String(sim.content.run.packs[option.pack_index].id))
	var plan_hash: StateHasher = StateHasher.new()
	sim.plan.hash_into(plan_hash)
	f.state = _h.state()
	f.result = sim.result()
	f.waves = sim.waves_completed
	f.act = sim.stats.act_reached
	f.state_hash = sim.state_hash()
	f.plan = plan_hash.finish()
	f.packs = "/".join(packs)
	f.stacks = Array(sim.draft.stacks)
	f.first_offer = _h.events_log.first_args(&"draft_offered")
	f.awaits = _awaits.duplicate()
	f.problems = "\n".join(_problems)
	if results != null:
		f.results_title = results.title_label.text
		f.waves_text = results.waves_cell.value.text
	f.hud_gone = _h.hud() == null
	f.hud_children = _h.child_count("UI/HudRoot")
	f.reward = _h.summary().data_reward
	f.banked = sim.stats.data
	f.profile_data = Save.profile.data
	f.runs_played = Save.profile.runs_played
	f.awarded = Save.profile.awarded_run_ids.size()
	f.finished = _h.events_log.count(&"run_finished")
	f.run_file = RunStore.exists(_h.fs)
	f.regrant = GameRewards.grant(_h.summary())
	f.data_after_regrant = Save.profile.data
	f.routes = _h.events_log.count(&"route_picked")
	f.picks = _h.events_log.count(&"directive_picked")
	f.salvage = _h.events_log.count(&"salvage_offered")
	f.acts_started = _h.events_log.count(&"act_started")
	f.bosses_spawned = _h.events_log.count(&"boss_spawned")
	f.slot_two = sim.arsenal.slot_weapon[1]
	f.armed = _h.events_log.count(&"burster_armed")
	for row: Dictionary in _h.events_log.rows:
		var row_args: Array = row["args"]
		if row["name"] == &"enemy_spawned" and row_args[1] == &"burster":
			f.bursters += 1
	_end_process()
	return f


## Every change of the await: exactly the overlay of that choice is in the HUD layer (none when the wait ended), above
## the HUD.
func _on_await(kind: int) -> void:
	var seen: int = _awaits.get(kind, 0)
	_awaits[kind] = seen + 1
	var found: Array[StringName] = _overlays_on_screen()
	var expected: Array[StringName] = []
	if OVERLAYS.has(kind):
		expected.append(OVERLAYS[kind])
	if found != expected:
		_problems.append("await %d shows %s, expected %s" % [kind, str(found), str(expected)])
	var hud: CombatHud = _h.hud()
	if hud == null:
		_problems.append("await %d without a HUD" % kind)
	elif hud.get_index() != 0:
		_problems.append("the HUD is not the lowest node of its layer")


func _overlays_on_screen() -> Array[StringName]:
	var out: Array[StringName] = []
	var layer: Node = _h.node("UI/HudRoot")
	for child: Node in layer.get_children():
		var script: Script = child.get_script()
		var global_name: StringName = script.get_global_name() if script != null else &""
		if OVERLAYS.values().has(global_name):
			out.append(global_name)
	return out


## Waves 2 to `last` that have a route choice (normal waves) or a boss briefing.
func _count_waves(last: int, boss: bool) -> int:
	var n: int = 0
	for wave_number: int in range(2, mini(last, WAVES) + 1):
		n += 1 if BOSS_WAVES.has(wave_number) == boss else 0
	return n


func test_the_debug_build_finishes_a_winning_fifteen_wave_run_on_the_results_screen() -> void:
	assert_int(_win.frames).is_greater(0)
	assert_int(_win.state).is_equal(GameState.Id.VICTORY)
	assert_int(_win.result).is_equal(RunResult.Id.VICTORY)
	assert_int(_win.waves).is_equal(WAVES)
	assert_int(_win.act).is_equal(3)
	assert_int(_win.acts_started).is_equal(3)
	assert_int(_win.bosses_spawned).is_greater_equal(3)
	assert_str(_win.results_title).is_equal(Strings.t("results.victory"))
	assert_str(_win.waves_text).is_equal("%d/%d" % [WAVES, WAVES])
	assert_bool(_win.hud_gone).is_true()
	assert_int(_win.hud_children).is_equal(0)
	assert_int(_win.slot_two).is_greater(0)  # the crates brought a second weapon


func test_the_bot_that_does_nothing_ends_on_the_defeat_screen_in_act_one() -> void:
	assert_int(_loss.state).is_equal(GameState.Id.DEFEAT)
	assert_int(_loss.result).is_equal(RunResult.Id.DEFEAT)
	assert_int(_loss.waves).is_less(5)
	assert_int(_loss.act).is_equal(1)
	assert_str(_loss.results_title).is_equal(Strings.t("results.defeat"))
	assert_str(_loss.waves_text).is_equal("%d/%d" % [_loss.waves, WAVES])
	assert_bool(_loss.hud_gone).is_true()
	assert_int(_loss.hud_children).is_equal(0)
	assert_int(_loss.slot_two).is_equal(-1)  # it scrapped every crate


func test_every_await_was_answered_and_showed_exactly_its_own_overlay() -> void:
	for f: Facts in [_win, _loss]:
		assert_str(f.problems).is_empty()
		var drafts: int = f.awaits.get(RunApi.AWAIT_DRAFT, 0)
		var routes: int = f.awaits.get(RunApi.AWAIT_ROUTE, 0)
		var crates: int = f.awaits.get(RunApi.AWAIT_SALVAGE, 0)
		var briefs: int = f.awaits.get(RunApi.AWAIT_BOSS_BRIEF, 0)
		var ended: int = f.awaits.get(RunApi.AWAIT_NONE, 0)
		assert_int(drafts).is_equal(mini(f.waves, WAVES - 1))  # one draft after every cleared wave but the last
		assert_int(routes).is_equal(_count_waves(f.waves + 1, false))  # before every normal wave that was reached
		assert_int(briefs).is_equal(_count_waves(f.waves + 1, true))  # before every boss wave that was reached
		assert_int(crates).is_greater_equal(1 if f.waves >= 2 else 0)  # the guaranteed crate after wave 2
		assert_int(ended).is_greater_equal(mini(f.waves, WAVES - 1))  # every wait ended
		assert_int(f.routes).is_equal(routes)
		assert_int(f.picks).is_greater_equal(drafts if f == _win else 0)
		assert_int(f.salvage).is_equal(crates)
	assert_int(_win.awaits.get(RunApi.AWAIT_ROUTE, 0)).is_equal(11)  # waves 2 to 4, 6 to 9, 11 to 14
	assert_int(_win.awaits.get(RunApi.AWAIT_BOSS_BRIEF, 0)).is_equal(3)
	assert_int(_win.awaits.get(RunApi.AWAIT_SALVAGE, 0)).is_greater_equal(3)  # and the boss crates of acts I and II


func test_the_reward_is_granted_once_and_the_run_file_is_gone() -> void:
	for f: Facts in [_win, _loss]:
		assert_int(f.finished).is_equal(1)
		assert_int(f.reward).is_greater(0)
		assert_int(f.profile_data).is_equal(f.reward)  # the debug win records no milestone, the loss earned none
		assert_int(f.runs_played).is_equal(1)
		assert_int(f.awarded).is_equal(1)
		assert_bool(f.regrant).is_false()  # a second finish of the same run pays nothing
		assert_int(f.data_after_regrant).is_equal(f.reward)
		assert_bool(f.run_file).is_false()
	assert_int(_loss.reward).is_equal(6 * _loss.waves)  # CONTENT 10: 6 Data per cleared wave
	assert_int(_loss.banked).is_equal(_loss.reward)
	assert_int(_win.banked).is_greater_equal(WAVES * 6 + 30 + 45)  # the waves and the two act bosses
	assert_int(_win.reward - _win.banked).is_between(100, 150)  # the victory: 100 + up to 50 for the core


func test_the_two_runs_are_visibly_different_games() -> void:
	assert_str(_win.plan).is_not_equal(_loss.plan)  # other spawn lists
	assert_str(_win.state_hash).is_not_equal(_loss.state_hash)
	assert_int(_win.result).is_not_equal(_loss.result)  # another outcome
	var differences: int = 0
	differences += 1 if _win.packs != _loss.packs else 0  # other packs on the routes
	differences += 1 if _win.first_offer != _loss.first_offer else 0  # another first draft
	differences += 1 if _win.stacks != _loss.stacks else 0  # another build
	assert_int(differences).is_greater_equal(2)


func test_a_burster_that_reached_its_slot_announced_its_fuse() -> void:
	# `Events.burster_armed` comes from the real relay: at most once per burster, and never without one.
	for f: Facts in [_win, _loss]:
		assert_int(f.armed).is_less_equal(f.bursters)

# --- kill and resume, driven by hand ---


func _boost(config: SimConfig) -> void:
	config.debug_damage_mult = 50.0
	config.debug_invulnerable_core = true


## A fresh Game (a new process) on `files` (path -> text), at the menu.
func _launch(files: Dictionary = {}) -> void:
	_h = GameHarness.create(self, PackedStringArray(["--seed=5"]), Callable(), HarnessKit.shipped())
	for path: String in files:
		_h.fs.files[path] = files[path]
	Save.load_profile()
	_h.game.set(&"sim_config_hook", _boost)
	_h.boot()
	(_h.find_in("ScreenRoot", &"BootScreen") as BootScreen).finished.emit()


func _end_process() -> void:
	if _h == null:
		return
	var old_root: Node = _h.root
	_h.dispose()
	_h = null
	if is_instance_valid(old_root) and old_root.get_parent() != null:
		old_root.get_parent().remove_child(old_root)


## The app goes to the background, then the process dies: returns the files it left.
func _background_and_kill() -> Dictionary:
	(_h.node("MobileShell") as MobileShell).on_app_paused()
	var files: Dictionary = _h.fs.files.duplicate()
	_end_process()
	return files


func _menu() -> MainMenuScreen:
	return _h.find_in("ScreenRoot", &"MainMenuScreen") as MainMenuScreen


func _pause_overlay() -> PauseOverlay:
	return _h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay


func _frames_until_await(kind: int, limit: int) -> bool:
	for i: int in limit:
		if _h.rc().api.awaiting() == kind:
			return true
		_h.frames(1)
	return _h.rc().api.awaiting() == kind


## Plays on (answering every choice the way a player with no plan does) until the run is `ticks_in` ticks into wave
## `wave_number` (`in_combat`), or waits for the first choice after wave `wave_number` was cleared.
func _play_to(wave_number: int, in_combat: bool, ticks_in: int = 240) -> bool:
	var rc: RunController = _h.rc()
	for i: int in 40000:
		var sim: SimWorld = rc.sim
		if sim.is_over():
			return false
		if in_combat:
			if sim.wave == wave_number and GameState.is_combat(sim.phase) and sim.tick - sim.stats.wave_start_tick[wave_number] >= ticks_in:
				return true
		elif sim.waves_completed == wave_number and rc.api.awaiting() != RunApi.AWAIT_NONE:
			return true
		GameHarness.play_intermission(rc)
		rc.step_frame(GameHarness.DT)
	return false


## Kills the process in the background and resumes from the menu: the run is back, paused, at the same tick with the
## same state, the same act and the same choice on screen. Leaves the run going again.
func _kill_and_resume(where: String) -> void:
	var sim: SimWorld = _h.rc().sim
	var run_id: String = _h.rc().run_id
	var tick: int = sim.tick
	var state_hash: String = sim.state_hash()
	var awaiting: int = _h.rc().api.awaiting()
	var act: int = sim.phase_state.act
	var wave: int = sim.wave
	var cleared: int = sim.waves_completed
	var banked: int = sim.stats.data
	var files: Dictionary = _background_and_kill()
	_launch(files)
	assert_bool(_menu().resume_button.visible).override_failure_message(where + ": no RESUME RUN").is_true()
	assert_str(_menu().resume_button.text).is_equal(Strings.tf("menu.resume", [cleared + 1]))
	_menu().resume_button.pressed.emit()
	_h.freeze()
	assert_int(_h.state()).override_failure_message(where + ": not paused after the resume").is_equal(GameState.Id.PAUSED)
	assert_object(_pause_overlay()).is_not_null()
	var back: SimWorld = _h.rc().sim
	assert_str(_h.rc().run_id).is_equal(run_id)
	assert_int(back.tick).override_failure_message(where + ": tick").is_equal(tick)
	assert_str(back.state_hash()).override_failure_message(where + ": state hash").is_equal(state_hash)
	assert_int(_h.rc().api.awaiting()).is_equal(awaiting)
	assert_int(back.phase_state.act).is_equal(act)
	assert_int(back.wave).is_equal(wave)
	assert_int(back.stats.data).override_failure_message(where + ": the banked Data").is_equal(banked)
	var expected: Array[StringName] = []
	if OVERLAYS.has(awaiting):
		expected.append(OVERLAYS[awaiting])
	assert_array(_overlays_on_screen()).override_failure_message(where + ": overlays").is_equal(expected)
	assert_int(_h.frames(10)).is_equal(0)  # paused: nothing moves
	_pause_overlay().resume_pressed.emit()
	assert_bool(GameState.is_run_phase(_h.state())).is_true()


func test_a_run_killed_at_every_kind_of_boundary_resumes_from_the_menu_and_is_paid_once() -> void:
	_launch()
	assert_bool(_menu().resume_button.visible).is_false()  # nothing to resume on a fresh profile
	_menu().start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.freeze()
	_h.frames(_h.content.mission.prepare_ticks + 400)
	var run_id: String = _h.rc().run_id
	assert_bool(GameState.is_combat(_h.rc().sim.phase)).is_true()
	assert_int(_h.rc().sim.wave).is_equal(1)
	_kill_and_resume("mid-wave 1")
	assert_bool(GameState.is_combat(_h.state())).is_true()

	# on to the first draft: the sim waits, the draft overlay is up, the back gesture pauses and does not dismiss it
	assert_bool(_frames_until_await(RunApi.AWAIT_DRAFT, 20000)).is_true()
	assert_array(_overlays_on_screen()).is_equal([&"DraftOverlay"])
	var offer: Array = Array(_h.rc().api.draft_offer())
	assert_int(offer.size()).is_equal(3)
	_h.hud().refresh()  # the HUD re-reads the run 10 times a second; the test steps the run by hand
	assert_bool(_h.hud().intermission.visible).is_false()  # the breather panel is not under the choice
	_h.game.call(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.PAUSED)
	assert_array(_overlays_on_screen()).is_equal([&"DraftOverlay"])
	var refused: int = _h.events_log.count(&"command_rejected")
	_h.rc().api.pick_directive(_h.rc().api.next_command_id(), 0)  # a tap that slips through while paused is refused
	assert_int(_h.events_log.count(&"command_rejected")).is_equal(refused + 1)
	_h.game.call(&"request_back")
	assert_int(_h.state()).is_equal(GameState.Id.INTERMISSION)
	assert_array(_overlays_on_screen()).is_equal([&"DraftOverlay"])
	_kill_and_resume("mid-draft after wave 1")
	assert_int(_h.state()).is_equal(GameState.Id.INTERMISSION)
	assert_array(Array(_h.rc().api.draft_offer())).is_equal(offer)  # the same three directives
	_h.rc().api.pick_directive(_h.rc().api.next_command_id(), 0)
	_h.frames(2)
	assert_int(_h.rc().api.awaiting()).is_equal(RunApi.AWAIT_ROUTE)
	assert_array(_overlays_on_screen()).is_equal([&"RouteOverlay"])
	assert_int(_h.rc().api.route_option_count()).is_equal(2)
	_h.rc().api.pick_route(_h.rc().api.next_command_id(), 1)
	_h.frames(2)
	assert_int(_h.rc().api.awaiting()).is_equal(RunApi.AWAIT_NONE)
	assert_array(_overlays_on_screen()).is_empty()
	_h.hud().refresh()
	assert_bool(_h.hud().intermission.visible).is_true()  # the breather countdown

	# across the acts: during the act I boss wave, at the act boundary behind it (the boss crate is on offer), in the
	# first wave of act II, during the act II boss wave, at the second act boundary, in act III and during the last boss wave
	assert_bool(_play_to(5, true)).is_true()
	assert_bool(_h.rc().sim.boss_store_index() >= 0 or _h.rc().sim.stats.boss_ids.size() >= 1).is_true()
	_kill_and_resume("during the boss wave 5")
	assert_bool(_play_to(5, false)).is_true()
	assert_int(_h.rc().api.awaiting()).is_equal(RunApi.AWAIT_SALVAGE)  # the boss crate of act I
	assert_int(_h.rc().sim.phase_state.act).is_equal(1)
	_kill_and_resume("at the act boundary after wave 5")
	assert_bool(_play_to(6, true)).is_true()
	assert_int(_h.rc().sim.phase_state.act).is_equal(2)
	_kill_and_resume("mid-wave 6, the first of act II")
	assert_bool(_play_to(10, true)).is_true()
	_kill_and_resume("during the boss wave 10")
	assert_bool(_play_to(10, false)).is_true()
	_kill_and_resume("at the act boundary after wave 10")
	assert_bool(_play_to(11, true)).is_true()
	assert_int(_h.rc().sim.phase_state.act).is_equal(3)
	_kill_and_resume("mid-wave 11, the first of act III")
	assert_bool(_play_to(15, true)).is_true()
	_kill_and_resume("during the boss wave 15")

	# to the end: one finish, one payment, nothing left to resume
	assert_int(_h.frames_until_over(SimHarness.VARIETY_MAX_TICKS)).is_greater(0)
	assert_int(_h.state()).is_equal(GameState.Id.VICTORY)
	assert_int(_h.rc().sim.waves_completed).is_equal(WAVES)
	assert_object(_h.find_in("ScreenRoot", &"ResultsScreen")).is_not_null()
	assert_str(_h.summary().run_id).is_equal(run_id)
	assert_int(Save.profile.data).is_equal(_h.summary().data_reward)
	assert_int(_h.summary().data_reward).is_greater_equal(WAVES * 6 + 30 + 45 + 100)
	assert_int(Save.profile.runs_played).is_equal(1)
	assert_int(Save.profile.awarded_run_ids.size()).is_equal(1)
	assert_int(_h.events_log.count(&"run_finished")).is_equal(1)
	assert_bool(RunStore.exists(_h.fs)).is_false()
	assert_bool(_h.game.call(&"resume_run_from_disk")).is_false()
	var files: Dictionary = _h.fs.files.duplicate()
	_end_process()
	_launch(files)
	assert_bool(_menu().resume_button.visible).is_false()
	assert_int(Save.profile.runs_played).is_equal(1)
	await _h.settle(get_tree(), 2)


func test_quitting_to_the_menu_gives_the_run_up_and_a_new_mission_replaces_a_saved_run() -> void:
	_launch()
	_menu().start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.freeze()
	_h.frames(_h.content.mission.prepare_ticks + 200)
	var first_id: String = _h.rc().run_id
	var files: Dictionary = _background_and_kill()

	# a new mission from the menu overwrites the run that could have been resumed
	_launch(files)
	assert_bool(_menu().resume_button.visible).is_true()
	_menu().start_pressed.emit()
	(_h.find_in("ScreenRoot", &"BriefingScreen") as BriefingScreen).deploy_pressed.emit()
	_h.freeze()
	_h.frames(30)
	assert_int(_h.rc().resume_mode).is_equal(-1)  # a fresh run, not the saved one (its id may repeat: same second, same seed)
	assert_int(_h.rc().sim.tick).is_equal(30)
	assert_bool(first_id.is_empty()).is_false()
	assert_str(RunFile.id_of(Save.load_run())).is_equal(_h.rc().run_id)
	assert_int(RunFile.target_tick(Save.load_run())).is_equal(0)  # the file is the new run's: its start snapshot
	# quit to the menu from the pause overlay: the run in progress is deleted and pays nothing
	_h.hud().pause_requested.emit()
	_pause_overlay().quit_pressed.emit()
	assert_int(_h.state()).is_equal(GameState.Id.MENU)
	assert_bool(RunStore.exists(_h.fs)).is_false()
	assert_bool(_menu().resume_button.visible).is_false()
	assert_int(Save.profile.runs_played).is_equal(0)
	assert_int(Save.profile.data).is_equal(0)
	await _h.settle(get_tree(), 2)
