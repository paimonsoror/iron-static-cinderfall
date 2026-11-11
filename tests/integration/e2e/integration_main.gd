class_name IntegrationMain
extends RefCounted
## Test helper (W3-A): boots the real `scenes/main.tscn` against the real `Game` autoload, the way the engine does at
## launch (src/core/main.gd calls `Game.boot`), with the debug arguments and an in-memory profile injected first.
## The engine is not allowed to drive the run (a test steps it by hand, one tick per frame), and `shutdown` puts the
## autoload back to its never-booted state so the next suite finds it clean.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const DT: float = 1.0 / 60.0

var main: Node
var fs: IntegrationCountingFs
var events_log: GameSignalLog
var peak_alive: int = 0  ## most enemies alive at once (the cap is 50)
var max_pending: int = 0  ## most spawns waiting behind the cap

var _saved_results_delay: float = 0.0


## `arg_list` are the user arguments after `--`. Never pass --quit-after-run (it would quit the test process).
static func boot(suite: GdUnitTestSuite, arg_list: PackedStringArray) -> IntegrationMain:
	var m: IntegrationMain = IntegrationMain.new()
	m.fs = IntegrationCountingFs.new()
	Save.use_fs(m.fs)
	Save.load_profile()
	GameRewards.flush_pending = false
	m.events_log = GameSignalLog.new()
	m.events_log.attach()
	m._saved_results_delay = Game.results_delay_s
	Game.args = DebugArgs.parse(arg_list)
	Game.results_delay_s = 0.0
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	m.main = packed.instantiate()
	suite.add_child(m.main)  # _ready runs here: Game.boot(main)
	m.freeze()
	return m


func rc() -> RunController:
	return Game.run


## The engine must not also drive the run.
func freeze() -> void:
	if Game.run != null:
		Game.run.set_process(false)


## Steps the run one tick per frame until it is over (pressing CONTINUE in every intermission). Returns the frames
## used, or -1 when `max_frames` were not enough.
func play_to_the_end(max_frames: int) -> int:
	freeze()
	var r: RunController = Game.run
	for i: int in max_frames:
		if r.sim.is_over():
			return i
		if r.sim.phase == GameState.Id.INTERMISSION:
			r.api.skip_intermission()
		r.step_frame(DT)
		peak_alive = maxi(peak_alive, r.sim.alive_count())
		max_pending = maxi(max_pending, r.api.pending_spawn_count())
	return max_frames if r.sim.is_over() else -1


func find_in(layer: String, script_class: StringName) -> Node:
	var parent: Node = main.get_node_or_null("UI/" + layer)
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var s: Script = child.get_script()
		if s != null and s.get_global_name() == script_class:
			return child
	return null


## Leaves the battlefield, frees the scene and resets the autoload to what it was before `boot`.
func shutdown() -> void:
	events_log.detach()
	if Game.state() == GameState.Id.BOOT or Game.run == null:
		pass
	else:
		Game.quit_to_menu()
	if is_instance_valid(main):
		main.free()  # takes World, RunHost, MobileShell and the UI layers with it
	for pair: Array in [[Events.run_finished, "_on_run_finished"], [Events.settings_changed, "_on_settings_changed"]]:
		var sig: Signal = pair[0]
		var method: String = pair[1]
		if sig.is_connected(Callable(Game, method)):
			sig.disconnect(Callable(Game, method))
	var size_changed: Signal = Game.get_viewport().size_changed
	if size_changed.is_connected(Callable(Game, "_refit_later")):
		size_changed.disconnect(Callable(Game, "_refit_later"))
	for member: String in ["_layers", "_perf", "_warm_view", "_pause_overlay", "_settings_overlay"]:
		Game.set(member, null)
	Game.run = null
	Game.battle_view = null
	Game.hud = null
	Game.args = null
	Game.content = null
	Game.last_summary = null
	Game.machine = GameStateMachine.new()
	var used_ids: Dictionary[String, bool] = {}
	Game.set(&"_used_run_ids", used_ids)
	Game.set(&"_boot_logged", false)
	Game.results_delay_s = _saved_results_delay
	Sfx.disabled = false
	GameRunKit.reset_save()
