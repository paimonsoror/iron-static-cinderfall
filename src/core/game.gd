extends Node
## `Game` autoload (ARCH 7.4): the application state machine, the screens, and the life of a run.
## Flow: BOOT -> MENU -> BRIEFING -> a run (PREPARING .. VICTORY or DEFEAT, mirrored from the sim) -> results -> retry or
## menu. PAUSED exists only here (the sim is not stepped). `_begin_run` builds a run (RunController, BattleView, CombatHud,
## GameFeedback) and `_teardown_run` leaves no node, Events connection or sim reference behind. The BattleView is built
## once per battlefield visit and reused by retries; the first one is built during the boot screen (ShaderWarmup, ARCH 8)
## and waits hidden in `_warm_view`. Debug arguments (ARCH 11, DebugArgs): --autoplay and --scenario=hold<N> skip the
## menus and deploy at once. The variety entry points delegate to GameRunFlow (this file is at the line cap).

const SCREEN_BOOT: String = "res://src/ui/screens/boot_screen.tscn"
const SCREEN_MENU: String = "res://src/ui/screens/main_menu_screen.tscn"
const SCREEN_BRIEFING: String = "res://src/ui/screens/briefing_screen.tscn"
const SCREEN_RESULTS: String = "res://src/ui/screens/results_screen.tscn"
const SCREEN_SETTINGS: String = "res://src/ui/screens/settings_screen.tscn"
const SCENE_HUD: String = "res://src/ui/combat/combat_hud.tscn"
const SCENE_PAUSE: String = "res://src/ui/combat/pause_overlay.tscn"
const BOOT_MAX_S: float = 2.0  ## the boot screen never holds the game longer than this (GDD 10.2: at most 3 s)
const RESULTS_DELAY_S: float = 1.2  ## the last moments of the battle stay visible before the results appear
const WARM_VIEW_DELAY_S: float = 0.1  ## the boot screen is on screen before the (slow) first BattleView is built
const FLUSH_RETRY_S: float = 5.0  ## a failed profile flush is retried this often
const QUIT_WINDOW_MS: int = 2000  ## a second back gesture within this time quits from the menu
const QUIT_CONFIRM_KEY: String = "menu.quit_confirm"

var machine: GameStateMachine = GameStateMachine.new()
var run: RunController  ## null outside a run
var battle_view: BattleView  ## null outside a run
var hud: CombatHud  ## null outside a run
var content: ContentSet  ## Content.db unless a test injects another before `boot`
var args: DebugArgs  ## the user arguments unless a test injects others before `boot`
var results_delay_s: float = RESULTS_DELAY_S
## Optional `func(config: SimConfig) -> void`, called on every new run before it starts (tests and tools set debug flags).
var sim_config_hook: Callable = Callable()
var last_summary: RunSummary  ## summary of the run that ended last

var _layers: GameLayers
var _perf: PerfHud  ## --debug-perf only
var _warm_view: BattleView  ## built during the boot screen, adopted by the first deploy
var _pause_overlay: PauseOverlay
var _settings_overlay: Control
var _feedback: GameFeedback = GameFeedback.new()
var _used_run_ids: Dictionary[String, bool] = {}
var _boot_logged: bool = false
var _quit_armed_until: int = 0
var _flush_timer: float = 0.0


## Called once by src/core/main.gd; builds layers; BOOT -> MENU.
func boot(root: Node) -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	Log.info("Game", "game boot version=%s renderer=%s" % [version, RendererInfo.current()])
	Log.info("Game", "gpu adapter=%s" % RendererInfo.adapter())
	if args == null:
		args = DebugArgs.from_os()
	if content == null:
		content = Content.db
	if content == null:
		Log.error("Game", "no content loaded, cannot start")
		return
	GameViewSettings.apply_look(args)  # before any BattleView is built (W3-C look; `--look=` overrides)
	GameAudioDebug.apply(args)  # --mute and the audio debug switches
	Sfx.apply_settings()
	_layers = GameLayers.build(root, content.tokens, GameViewSettings.bool_setting(&"high_contrast", false))
	_layers.shell.app_paused.connect(pause_run)
	_layers.shell.back_requested.connect(request_back)
	Events.run_finished.connect(_on_run_finished)
	Events.settings_changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_refit_later)
	GameViewSettings.apply_fps_cap()
	if args.debug_perf:
		_perf = GameDebugTools.add_perf_hud(_layers.debug_root, Callable(self, "_alive_enemies"))
	if GameLaunch.wants_autostart(args):
		_autostart()
		return
	var boot_screen: BootScreen = _layers.swap_screen(SCREEN_BOOT) as BootScreen
	boot_screen.setup(version)
	boot_screen.finished.connect(goto_menu)
	get_tree().create_timer(BOOT_MAX_S).timeout.connect(_boot_timeout)
	get_tree().create_timer(WARM_VIEW_DELAY_S).timeout.connect(_prebuild_view)


func _process(delta: float) -> void:
	if GameRewards.flush_pending:
		_flush_timer += delta
		if _flush_timer >= FLUSH_RETRY_S:
			_flush_timer = 0.0
			GameRewards.retry_pending()


func _exit_tree() -> void:
	if Events.run_finished.is_connected(_on_run_finished):
		Events.run_finished.disconnect(_on_run_finished)
	if Events.settings_changed.is_connected(_on_settings_changed):
		Events.settings_changed.disconnect(_on_settings_changed)
	_feedback.detach()


# --- screens ---


## Any state that may legally go to the menu: boot, briefing, pause, results. An open run is abandoned (no reward).
func goto_menu() -> void:
	if _layers == null or not GameStateMachine.can_transition(machine.current, GameState.Id.MENU):
		return
	_teardown_run(true)
	_layers.clear_screen()
	if _warm_view != null:
		_warm_view.visible = false  # warmed up; it costs nothing while the menus are up
	if not _set_state(GameState.Id.MENU):
		return
	var menu: MainMenuScreen = _layers.swap_screen(SCREEN_MENU) as MainMenuScreen
	GameRunFlow.setup_menu(self, menu)
	menu.start_pressed.connect(goto_briefing)
	menu.settings_pressed.connect(open_settings)
	menu.quit_pressed.connect(_quit_app)
	if not _boot_logged:
		_boot_logged = true
		Log.info("Game", "boot ok")


func goto_briefing() -> void:
	if _layers == null or machine.current != GameState.Id.MENU or not _set_state(GameState.Id.BRIEFING):
		return
	var briefing: BriefingScreen = _layers.swap_screen(SCREEN_BRIEFING) as BriefingScreen
	briefing.setup(content)
	briefing.deploy_pressed.connect(start_run)
	briefing.back_pressed.connect(goto_menu)


## Deploys from the briefing. -1 = the fixed `--seed`, else a time-based seed. `kit_id`: a KitDef id; `daily`: Daily Run.
func start_run(run_seed: int = -1, kit_id: StringName = &"", daily: bool = false) -> void:
	if machine.current == GameState.Id.BRIEFING:
		GameRunFlow.set_launch(kit_id, daily)
		_begin_run(run_seed)


func resume_run_from_disk() -> bool:
	return GameRunFlow.resume_from_disk(self)


func open_archive() -> bool:
	return GameRunFlow.open_archive(self)


## Retry: from the pause overlay (restart) or the results screen.
func restart_run() -> void:
	var s: int = machine.current
	if s == GameState.Id.PAUSED or GameState.is_terminal(s):
		_begin_run(-1)


func pause_run() -> void:
	if run != null and GameState.is_run_phase(machine.current) and not GameState.is_terminal(machine.current):
		run.api.pause()  # RunController.paused_changed does the rest, whoever paused


func resume_run() -> void:
	if run != null and machine.current == GameState.Id.PAUSED:
		run.api.resume()


## From the pause overlay or the results screen: abandons the run and shows the menu.
func quit_to_menu() -> void:
	if run != null and GameState.is_run_phase(machine.current) and not GameState.is_terminal(machine.current):
		pause_run()
	goto_menu()


func open_settings() -> void:
	if _layers == null or _settings_overlay != null:
		return
	_settings_overlay = _layers.add_scene(_layers.overlay_root, SCREEN_SETTINGS)
	if _settings_overlay == null:
		return
	var screen: SettingsScreen = _settings_overlay as SettingsScreen
	screen.setup()
	screen.closed.connect(_close_settings)


## Android back (and Escape on desktop), by BackPolicy.
func request_back() -> void:
	var drawer: bool = hud != null and hud.is_drawer_open()
	match BackPolicy.decide(machine.current, drawer, _settings_overlay != null, GameRunFlow.choice_open(run)):
		BackPolicy.Action.CLOSE_OVERLAY:
			_close_settings()
		BackPolicy.Action.CLOSE_DRAWER:
			hud.close_drawer()
		BackPolicy.Action.PAUSE:
			pause_run()
		BackPolicy.Action.RESUME:
			resume_run()
		BackPolicy.Action.TO_MENU:
			goto_menu()
		BackPolicy.Action.CONFIRM_QUIT:
			_confirm_quit()


func state() -> int:
	return machine.current


# --- runs ---


func _begin_run(run_seed: int) -> void:
	if _layers == null or not GameStateMachine.can_transition(machine.current, GameState.Id.PREPARING):
		return
	_teardown_run(false)
	_layers.clear_screen()
	if battle_view == null and not _create_view():
		return
	var seed_value: int = GameLaunch.pick_seed(run_seed, args)
	var config: SimConfig = SimConfig.create(content, seed_value)
	GameRunFlow.apply_launch(config, content, args)
	run = RunController.new()
	run.name = "RunController"
	_layers.run_host.add_child(run)
	GameLaunch.configure(config, run, args, seed_value)
	if sim_config_hook.is_valid():
		sim_config_hook.call(config)
	run.paused_changed.connect(_on_paused_changed)
	run.phase_changed.connect(_on_sim_phase)
	_set_state(GameState.Id.PREPARING)
	_feedback.attach(content)
	var run_id: String = GameRunFlow.run_id_for(seed_value, _used_run_ids)
	Log.info("Game", "run started id=%s seed=%d autoplay=%s scenario=%s" % [run_id, seed_value, args.autoplay, args.scenario])
	GameRunFlow.start(self, config, run_id)
	GameDebugTools.bind(battle_view, run, _perf, args.debug_overlay)
	hud = _layers.add_scene(_layers.hud_root, SCENE_HUD) as CombatHud
	hud.setup(run.api, content, battle_view)
	hud.pause_requested.connect(pause_run)
	hud.resized.connect(_refit_later)
	Sfx.start_ambience()
	_refit_camera()


## The BattleView of a battlefield visit: built once, with the player's view settings applied. The one that was
## warmed up during the boot screen is adopted first (settings may have changed since, hence applied here).
func _create_view() -> bool:
	battle_view = _warm_view if is_instance_valid(_warm_view) else GameViewBuilder.build(_layers, content, args)
	_warm_view = null
	if battle_view != null:
		battle_view.visible = true
		GameViewSettings.apply_to_view(battle_view, args)
	return battle_view != null


## Boot screen is up: build the first BattleView now so ShaderWarmup runs before the player can deploy.
func _prebuild_view() -> void:
	if machine.current == GameState.Id.BOOT and battle_view == null and _warm_view == null and _layers != null:
		_warm_view = GameViewBuilder.build(_layers, content, args)
		if _warm_view != null:
			GameViewSettings.apply_to_view(_warm_view, args)
			Log.info("Game", "battle view warmed up during boot")


## The live enemy count for the PerfHud.
func _alive_enemies() -> int:
	return run.sim.alive_count() if run != null and run.sim != null else 0


## Frees the run and everything built for it. `free_view` also frees the BattleView (leaving the battlefield).
func _teardown_run(free_view: bool) -> void:
	_feedback.detach()
	_close_settings()
	GameLayers.release(_pause_overlay)
	_pause_overlay = null
	GameLayers.release(hud)
	hud = null
	GameDebugTools.unbind(battle_view)
	if run != null:
		if run.paused_changed.is_connected(_on_paused_changed):
			run.paused_changed.disconnect(_on_paused_changed)
		if run.phase_changed.is_connected(_on_sim_phase):
			run.phase_changed.disconnect(_on_sim_phase)
		run.abandon()
		GameLayers.release(run)
		run = null
		Sfx.resume_all()
		Sfx.stop_ambience()
	if free_view:
		GameLayers.release(battle_view)
		battle_view = null


func _on_sim_phase(_previous: int, current: int) -> void:
	_set_state(current)


func _on_paused_changed(is_paused: bool) -> void:
	if is_paused:
		if not _set_state(GameState.Id.PAUSED):
			return
		Sfx.pause_all()
		_pause_overlay = _layers.add_scene(_layers.overlay_root, SCENE_PAUSE) as PauseOverlay
		_pause_overlay.setup()
		_pause_overlay.resume_pressed.connect(resume_run)
		_pause_overlay.restart_pressed.connect(restart_run)
		_pause_overlay.settings_pressed.connect(open_settings)
		_pause_overlay.quit_pressed.connect(quit_to_menu)
	elif machine.current == GameState.Id.PAUSED:
		_close_settings()
		GameLayers.release(_pause_overlay)
		_pause_overlay = null
		_set_state(machine.paused_from)
		Sfx.resume_all()


func _on_run_finished(result: int, run_id: String) -> void:
	if run == null or run.run_id != run_id:
		return
	last_summary = run.summary
	Log.info("Game", "run finished result=%s waves=%d core=%d data=+%d granted=%s" % [
		RunResult.Id.keys()[result], last_summary.waves_completed, last_summary.core_hp, last_summary.data_reward,
		str(run.reward_granted)])
	if results_delay_s > 0.0:
		get_tree().create_timer(results_delay_s).timeout.connect(_show_results.bind(run_id))
	else:
		_show_results(run_id)


func _show_results(run_id: String) -> void:
	if run == null or run.run_id != run_id or not GameState.is_terminal(machine.current):
		return
	GameLayers.release(hud)  # the HUD is drawn above the screens
	hud = null
	var screen: ResultsScreen = _layers.swap_screen(SCREEN_RESULTS) as ResultsScreen
	screen.setup(last_summary, content, Save.profile, run.reward_granted)
	screen.retry_pressed.connect(restart_run)
	screen.menu_pressed.connect(goto_menu)
	Log.info("Game", "results shown")
	if args.quit_after_run:
		Log.info("Game", "quit after run")
		get_tree().quit(0)


# --- state, settings, camera ---


func _set_state(to: int) -> bool:
	var previous: int = machine.current
	if not machine.transition(to):
		Log.warn("Game", "illegal state change %s -> %s" % [GameState.name_of(previous), GameState.name_of(to)])
		return false
	Events.state_changed.emit(previous, to)
	GameRewards.retry_pending()
	return true


func _on_settings_changed(key: StringName) -> void:
	if GameViewSettings.VIEW_KEYS.has(key):
		GameViewSettings.apply_to_view(battle_view, args)
	if key == &"high_contrast" and _layers != null:
		_layers.apply_theme(content.tokens, GameViewSettings.bool_setting(&"high_contrast", false))
	if key == &"fps_cap":
		GameViewSettings.apply_fps_cap()
	if key == &"sound_on" or key == &"music_on":
		Sfx.apply_settings()


func _refit_later() -> void:
	_refit_camera.call_deferred()


func _refit_camera() -> void:
	if battle_view != null and is_inside_tree():
		GameCameraFit.refit(battle_view, hud, get_viewport().get_visible_rect().size, content.tokens)


## --autoplay and --scenario: BOOT -> MENU -> BRIEFING -> deploy, with no screens in between.
func _autostart() -> void:
	_set_state(GameState.Id.MENU)
	_set_state(GameState.Id.BRIEFING)
	Log.info("Game", "boot ok")
	_boot_logged = true
	start_run()


func _boot_timeout() -> void:
	if machine.current == GameState.Id.BOOT:
		goto_menu()


func _close_settings() -> void:
	GameLayers.release(_settings_overlay)
	_settings_overlay = null


func _confirm_quit() -> void:
	var now: int = Time.get_ticks_msec()
	if now <= _quit_armed_until:
		_quit_app()
		return
	_quit_armed_until = now + QUIT_WINDOW_MS
	var key: String = QUIT_CONFIRM_KEY if content.strings.has(QUIT_CONFIRM_KEY) else "menu.quit"
	_layers.show_toast(Strings.t(key), float(QUIT_WINDOW_MS) / 1000.0)


func _quit_app() -> void:
	GameRewards.flush_now()
	get_tree().quit()
