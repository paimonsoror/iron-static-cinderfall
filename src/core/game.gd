extends Node
## `Game` autoload (ARCH 7.4). Wave 0 stub: boot builds the layer tree, shows the stub BootScreen over the
## view sandbox, logs `game boot ...` and `boot ok`. Every other method logs and does nothing.
## TODO(W2-A): the real state machine, screens, runs.

var machine: GameStateMachine = GameStateMachine.new()
var run: RunController  ## null outside a run
var battle_view: BattleView  ## null outside a run

var _world_root: Node
var _screen_root: Control


## Called once by src/core/main.gd; builds layers; BOOT -> MENU.
func boot(root: Node) -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	Log.info("Game", "game boot version=%s renderer=%s" % [version, RendererInfo.current()])
	Log.info("Game", "gpu adapter=%s" % RendererInfo.adapter())
	var args: DebugArgs = DebugArgs.from_os()
	Sfx.disabled = args.mute
	_build_layers(root)
	var sandbox: PackedScene = load("res://src/debug/view_sandbox.tscn") as PackedScene
	_world_root.add_child(sandbox.instantiate())
	var boot_scene: PackedScene = load("res://src/ui/screens/boot_screen.tscn") as PackedScene
	var boot_screen: BootScreen = boot_scene.instantiate() as BootScreen
	_screen_root.add_child(boot_screen)
	boot_screen.setup(version)
	boot_screen.finished.connect(boot_screen.queue_free)
	machine.transition(GameState.Id.MENU)
	Log.info("Game", "boot ok")


func goto_menu() -> void:
	_stub("goto_menu")


func goto_briefing() -> void:
	_stub("goto_briefing")


func start_run(_run_seed: int = -1) -> void:
	_stub("start_run")


func restart_run() -> void:
	_stub("restart_run")


func pause_run() -> void:
	_stub("pause_run")


func resume_run() -> void:
	_stub("resume_run")


func quit_to_menu() -> void:
	_stub("quit_to_menu")


func open_settings() -> void:
	_stub("open_settings")


## Android back, via BackPolicy.
func request_back() -> void:
	_stub("request_back")


func state() -> int:
	return machine.current


func _stub(what: String) -> void:
	Log.info("Game", "%s (stub, TODO(W2-A))" % what)


## The runtime tree of ARCH 7.4: World, RunHost, MobileShell, UI/{ScreenRoot, HudRoot, OverlayRoot, DebugRoot}.
func _build_layers(root: Node) -> void:
	_world_root = Node.new()
	_world_root.name = "World"
	root.add_child(_world_root)
	var run_host: Node = Node.new()
	run_host.name = "RunHost"
	root.add_child(run_host)
	var shell: MobileShell = MobileShell.new()
	shell.name = "MobileShell"
	root.add_child(shell)
	var ui: CanvasLayer = CanvasLayer.new()
	ui.name = "UI"
	root.add_child(ui)
	var theme: Theme = UiTheme.build(Content.db.tokens, false)
	for layer_name: String in ["ScreenRoot", "HudRoot", "OverlayRoot", "DebugRoot"]:
		var c: Control = Control.new()
		c.name = layer_name
		c.theme = theme
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if layer_name == "ScreenRoot":
			_screen_root = c
