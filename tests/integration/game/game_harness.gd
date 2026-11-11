class_name GameHarness
extends RefCounted
## Test helper (W2-A): a second instance of the `Game` script (the autoload itself is never touched) booted under a
## plain Node inside the suite, on the frozen baseline content, with an in-memory save and no audio. The real sim,
## the real BattleView and the real HUD and overlays run; the five screens are whatever is on disk (Wave 0 stubs or
## the W2-B screens, same contract). Time is driven by hand through `frames`.
##
## `Game` has no class_name (it would clash with the autoload), so its members are reached through get/set/call.

const GAME_SCRIPT: GDScript = preload("res://src/core/game.gd")
const DT: float = 1.0 / 60.0

var game: Node
var root: Node
var fs: MemorySaveFs
var content: ContentSet
var events_log: GameSignalLog

var _saved_max_fps: int = 0


## `arg_list` are the user arguments after `--`. `content_tweak` (optional) may change the baseline content first.
static func create(suite: GdUnitTestSuite, arg_list: PackedStringArray = PackedStringArray(), content_tweak: Callable = Callable()) -> GameHarness:
	var h: GameHarness = GameHarness.new()
	h._saved_max_fps = Engine.max_fps
	h.fs = GameRunKit.fresh_save()
	h.content = TestContent.baseline()
	if content_tweak.is_valid():
		content_tweak.call(h.content)
	h.events_log = GameSignalLog.new()
	h.events_log.attach()
	h.root = Node.new()
	suite.auto_free(h.root)
	suite.add_child(h.root)
	h.game = GAME_SCRIPT.new()
	var args: DebugArgs = DebugArgs.parse(arg_list)
	args.mute = true
	h.game.set(&"args", args)
	h.game.set(&"content", h.content)
	h.game.set(&"results_delay_s", 0.0)
	h.root.add_child(h.game)
	return h


func boot() -> void:
	game.call(&"boot", root)
	freeze()


## Frees the Game instance and puts the shared singletons back.
func dispose() -> void:
	events_log.detach()
	if is_instance_valid(root):
		root.remove_child(game)
		game.free()
	GameRunKit.reset_save()
	Sfx.disabled = false
	Engine.max_fps = _saved_max_fps


# --- typed access to the Game instance ---


func state() -> int:
	var s: int = game.call(&"state")
	return s


func rc() -> RunController:
	var o: Object = game.get(&"run")
	return o as RunController


func hud() -> CombatHud:
	var o: Object = game.get(&"hud")
	return o as CombatHud


func view() -> BattleView:
	var o: Object = game.get(&"battle_view")
	return o as BattleView


func summary() -> RunSummary:
	var o: Object = game.get(&"last_summary")
	return o as RunSummary


func call_game(method: StringName, a: Variant = null) -> void:
	if a == null:
		game.call(method)
	else:
		game.call(method, a)


func node(path: String) -> Node:
	return root.get_node_or_null(path)


## Children of a layer under UI (ScreenRoot, HudRoot, OverlayRoot, DebugRoot) that are of the given script class.
func find_in(layer: String, script_class: StringName) -> Node:
	var parent: Node = node("UI/" + layer)
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.get_class() == script_class or _script_name(child) == script_class:
			return child
	return null


func child_count(layer: String) -> int:
	var parent: Node = node(layer)
	return parent.get_child_count() if parent != null else -1


func screen_count() -> int:
	return child_count("UI/ScreenRoot")


## The engine must not also drive the run: the tests step it by hand.
func freeze() -> void:
	var r: RunController = rc()
	if r != null:
		r.set_process(false)


## n frames of the current run at 60 FPS. Returns the ticks run.
func frames(n: int, delta: float = DT) -> int:
	freeze()
	var r: RunController = rc()
	var ticks: int = 0
	for i: int in n:
		if r == null or r.sim == null:
			break
		ticks += r.step_frame(delta)
	return ticks


## Steps until the run is over (pressing CONTINUE in every intermission, as a player would). Returns the frames
## used, or -1 when `max_frames` were not enough.
func frames_until_over(max_frames: int) -> int:
	freeze()
	var r: RunController = rc()
	for i: int in max_frames:
		if r.sim.is_over():
			return i
		if r.sim.phase == GameState.Id.INTERMISSION:
			r.api.skip_intermission()
		r.step_frame(DT)
	return max_frames if r.sim.is_over() else -1


## A `content_tweak` for `create`: only the first wave, so a boosted run is over in a couple of seconds.
static func one_wave(c: ContentSet) -> void:
	c.waves = GameRunKit.first_waves(c, 1)


## Lets queue_free calls and deferred calls run.
func settle(tree: SceneTree, count: int = 2) -> void:
	for i: int in count:
		await tree.process_frame


static func _script_name(n: Node) -> StringName:
	var s: Script = n.get_script()
	return s.get_global_name() if s != null else &""
