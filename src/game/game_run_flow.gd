class_name GameRunFlow
extends RefCounted
## The variety entry points of `Game` (VARIETY_SPEC 13.4): how a run is launched with a kit and the profile's unlocks,
## the resume of a run that survived a process kill (2.8), the choice overlays, and the Archive. `Game` keeps one-line
## delegates (its file is at the line cap); the logic lives here. `Game` has no class_name (it is an autoload), so its
## members are reached through get and call.
## V5-A: the Daily Run and SAME SEED starts, the milestone lines of the results screen, the back gesture on a screen's
## own overlay.

const OVERLAYS_NAME: String = "ChoiceOverlays"

## What the next `Game.start_run` asked for; consumed by `apply_launch`.
static var pending_kit: StringName = &""
static var pending_daily: bool = false
## The run file (and its rebuilt world) that the next `_begin_run` continues instead of starting a new run.
static var pending_resume: Dictionary = {}
static var pending_rebuild: RunResumeResult = null


## Remembers the kit and the daily flag of the run that is about to start.
static func set_launch(kit_id: StringName, daily: bool) -> void:
	pending_kit = kit_id
	pending_daily = daily


## Fills the variety fields of a new run's SimConfig (kit_index, unlocked, daily) from the pending launch and clears it.
## The kit is the one asked for, else `--kit=<id>`, else the profile's (the kit selector writes `Save.profile.kit`); an
## unknown or empty kit is the standard kit (index 0); a Daily Run always takes GameLaunch.DAILY_KIT. The unlock list is the profile's (`--unlock=all|none|<id,id>` replaces it), sorted.
static func apply_launch(config: SimConfig, content: ContentSet, args: DebugArgs = null) -> void:
	var kit_id: StringName = pending_kit
	if kit_id == &"" and args != null and args.kit != "":
		kit_id = StringName(args.kit)
	if kit_id == &"":
		kit_id = Save.profile.kit
	config.daily = pending_daily or (args != null and args.daily)
	if config.daily:
		kit_id = GameLaunch.DAILY_KIT  # the Daily Run is the same for everyone: one seed, one kit, the full pool
	config.kit_index = maxi(0, content.kit_index(kit_id))
	config.unlocked = unlocked_for(content, args.unlock if args != null else "")
	pending_kit = &""
	pending_daily = false


## The unlock ids a run counts, sorted. `spec` is the `--unlock` argument: "" = the profile's unlocks that this
## content knows (ids of a newer build are ignored), "all", "none", or a comma list of ids.
static func unlocked_for(content: ContentSet, spec: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if spec == "none":
		return out
	var wanted: PackedStringArray = spec.split(",", false) if spec != "" and spec != "all" else Save.profile.unlocks
	for u: UnlockDef in content.unlocks:
		var id: String = String(u.id)
		if (spec == "all" or wanted.has(id)) and not out.has(id):
			out.append(id)
	out.sort()
	return out


## The run id of the run `_begin_run` is about to start: the saved one for a resume (a resumed run keeps its id, so it
## is rewarded once however often it is resumed), else a new "<unix>-<seed>".
static func run_id_for(seed_value: int, used: Dictionary[String, bool]) -> String:
	if pending_resume.is_empty():
		return GameLaunch.make_run_id(seed_value, used, Save.profile.awarded_run_ids)
	var id: String = RunFile.id_of(pending_resume)
	used[id] = true
	return id


## Starts the run of `_begin_run`: a new one, or the pending resume. Also gives the run its choice overlays.
static func start(game: Node, config: SimConfig, run_id: String) -> void:
	var run: RunController = _run(game)
	var view_o: Object = game.get(&"battle_view")
	var view: BattleView = view_o as BattleView
	if pending_resume.is_empty():
		run.start(config, run_id, view)
	else:
		run.start_resumed(pending_resume, view, config.content, pending_rebuild)
	pending_resume = {}
	pending_rebuild = null
	var feedback_o: Object = game.get(&"_feedback")
	var feedback: GameFeedback = feedback_o as GameFeedback
	if feedback != null:
		feedback.api = run.api  # the hint of the second weapon asks the run
	var layers_o: Object = game.get(&"_layers")
	var layers: GameLayers = layers_o as GameLayers
	if layers != null and run.sim != null:
		var overlays: GameChoiceOverlays = GameChoiceOverlays.new()
		overlays.name = OVERLAYS_NAME
		run.add_child(overlays)
		overlays.setup(run.api, config.content, layers.hud_root)


## The wave RESUME RUN would continue (0 = nothing to resume). A run file of another build or other content is closed
## here: paid once as a defeat at its last saved wave and deleted.
static func resumable_wave(content: ContentSet) -> int:
	var doc: Dictionary = Save.load_run()
	match RunFile.check(doc, content):
		RunFile.Verdict.RESUMABLE:
			return RunFile.resume_wave(doc)
		RunFile.Verdict.STALE:
			RunResume.close(doc, content)
	return 0


## Sets the main menu up: closes a stale run file first (so the menu shows the Data it paid), then tells the menu
## which wave can be resumed and listens to its RESUME RUN button.
static func setup_menu(game: Node, menu: MainMenuScreen) -> void:
	var content_o: Object = game.get(&"content")
	var wave: int = resumable_wave(content_o as ContentSet) if content_o != null else 0
	menu.setup(Save.profile)
	menu.set_resume_wave(wave)  # 0 hides RESUME RUN
	menu.set_daily_today(GameLaunch.utc_date())  # the UI never reads the clock
	menu.resume_pressed.connect(Callable(game, &"resume_run_from_disk"))
	menu.daily_pressed.connect(start_daily.bind(game))


## DAILY RUN (from the menu; VARIETY_SPEC 8.5): deploys today's run at once: the seed of the UTC date, the standard kit,
## the full pool. False when the game is not on the menu.
static func start_daily(game: Node) -> bool:
	var state: int = game.call(&"state")
	if state != GameState.Id.MENU:
		return false
	var entered: bool = game.call(&"_set_state", GameState.Id.BRIEFING)
	if not entered:
		return false
	game.call(&"start_run", GameLaunch.daily_seed(GameLaunch.utc_date()), GameLaunch.DAILY_KIT, true)
	return true


## The results screen of the run that just ended: the milestones its reward paid (`Save.last_reward`, only when this
## run was the one granted) and the SAME SEED button.
static func setup_results(game: Node, screen: ResultsScreen) -> void:
	var run: RunController = _run(game)
	var reward: Dictionary = Save.last_reward
	if run != null and run.reward_granted and str(reward.get("run_id", "")) == run.run_id:
		var paid: Variant = reward.get("milestones", [])
		if typeof(paid) == TYPE_ARRAY:
			var items: Array = paid
			screen.show_milestones(items)
	screen.same_seed_pressed.connect(start_same_seed.bind(game))


## SAME SEED (from the results screen): a new run with the seed and the kit of the run that ended. Never a Daily Run.
static func start_same_seed(run_seed: int, game: Node) -> void:
	var state: int = game.call(&"state")
	if not GameState.is_terminal(state) or run_seed < 0:
		return
	var run: RunController = _run(game)
	var kit_id: StringName = &""
	if run != null and run.sim != null and run.sim.content.run != null:
		var kits: Array[KitDef] = run.sim.content.kits
		var kit_index: int = run.sim.config.kit_index
		if kit_index >= 0 and kit_index < kits.size():
			kit_id = kits[kit_index].id
	set_launch(kit_id, false)
	game.call(&"_begin_run", run_seed)


## The back gesture on a screen that has an overlay of its own up (the Archive over the menu or the results screen):
## closes it. True when one was closed; `Game.request_back` then does nothing else.
static func close_screen_overlay(game: Node) -> bool:
	var layers_o: Object = game.get(&"_layers")
	var layers: GameLayers = layers_o as GameLayers
	if layers == null or layers.screen_root == null:
		return false
	for child: Node in layers.screen_root.get_children():
		if child is MainMenuScreen or child is ResultsScreen:
			var closed: bool = child.call(&"close_overlay")
			if closed:
				return true
	return false


## RESUME RUN (from the menu): rebuilds the run of the run file and continues it, paused, with the pause overlay up.
## False when there is nothing to resume; a run that cannot be rebuilt is closed and paid once (RunResume.close).
static func resume_from_disk(game: Node) -> bool:
	if game == null:
		return false
	var content_o: Object = game.get(&"content")
	var content: ContentSet = content_o as ContentSet
	var state: int = game.call(&"state")
	if content == null or state != GameState.Id.MENU or resumable_wave(content) == 0:
		return false
	var doc: Dictionary = Save.load_run()
	var rebuilt: RunResumeResult = RunResume.rebuild(doc, content)
	if not rebuilt.ok():
		Log.warn("Game", "run %s cannot be resumed: %s" % [rebuilt.run_id, rebuilt.reason])
		RunResume.close(doc, content)
		return false
	if rebuilt.world.is_over():  # the process died between the end of the run and the deletion of its file
		GameRewards.grant(rebuilt.world.summary(rebuilt.run_id), rebuilt.config)  # with its Archive facts
		Save.clear_run()
		return false
	var entered: bool = game.call(&"_set_state", GameState.Id.BRIEFING)
	if not entered:
		return false
	pending_resume = doc
	pending_rebuild = rebuilt
	game.call(&"_begin_run", rebuilt.config.run_seed)
	pending_resume = {}
	pending_rebuild = null
	var run: RunController = _run(game)
	if run == null or run.sim == null:
		game.call(&"goto_menu")
		return false
	for phase: int in _phases_up_to(run.sim.phase):
		game.call(&"_set_state", phase)
	var overlays: GameChoiceOverlays = run.get_node_or_null(OVERLAYS_NAME) as GameChoiceOverlays
	if overlays != null:
		overlays.sync()
	run.api.pause()
	Sfx.play(&"resume_link")
	Log.info("Game", "run resumed id=%s wave=%d tick=%d" % [run.run_id, run.sim.wave, run.sim.tick])
	return true


## True while the run waits for a choice (a choice overlay is up; the back gesture pauses then, it never dismisses).
static func choice_open(run: RunController) -> bool:
	return run != null and run.api.awaiting() != RunApi.AWAIT_NONE


## Opens the Archive as an overlay on the menu (the menu's own ARCHIVE button does the same). False when the game is
## not on the menu.
static func open_archive(game: Node) -> bool:
	var layers_o: Object = game.get(&"_layers") if game != null else null
	var layers: GameLayers = layers_o as GameLayers
	if layers == null or layers.screen_root == null:
		return false
	for child: Node in layers.screen_root.get_children():
		var menu: MainMenuScreen = child as MainMenuScreen
		if menu != null:
			return menu.open_archive() != null
	return false


## The application states from PREPARING (where `_begin_run` leaves the machine) to the phase of a resumed sim.
static func _phases_up_to(phase: int) -> Array[int]:
	var order: Array[int] = [GameState.Id.SPAWNING, GameState.Id.CLEARING, GameState.Id.INTERMISSION]
	var at: int = order.find(phase)
	return order.slice(0, at + 1)


static func _run(game: Node) -> RunController:
	var o: Object = game.get(&"run")
	return o as RunController
