class_name GameLayers
extends RefCounted
## The runtime tree of ARCH 7.4, built in code under the Main node by `Game.boot`:
##
##   World (Node)                 BattleView during a run
##   RunHost (Node)               RunController during a run
##   MobileShell (Node)           lifecycle and back gesture
##   UI (CanvasLayer)
##     ScreenRoot / HudRoot / OverlayRoot / DebugRoot   full-rect Controls, drawn in this order
##
## Also the small helpers Game uses to put scenes into those layers and to take them out again.

const UI_LAYER_NAMES: Array[String] = ["ScreenRoot", "HudRoot", "OverlayRoot", "DebugRoot"]

var world: Node
var run_host: Node
var shell: MobileShell
var ui: CanvasLayer
var screen_root: Control
var hud_root: Control
var overlay_root: Control
var debug_root: Control


static func build(root: Node, tokens: VisualTokens, high_contrast: bool) -> GameLayers:
	var l: GameLayers = GameLayers.new()
	l.world = _plain_node(root, "World")
	l.run_host = _plain_node(root, "RunHost")
	l.shell = MobileShell.new()
	l.shell.name = "MobileShell"
	root.add_child(l.shell)
	l.ui = CanvasLayer.new()
	l.ui.name = "UI"
	root.add_child(l.ui)
	var theme: Theme = UiTheme.build(tokens, high_contrast)
	for layer_name: String in UI_LAYER_NAMES:
		var c: Control = Control.new()
		c.name = layer_name
		c.theme = theme
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.ui.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.screen_root = l.ui.get_node("ScreenRoot") as Control
	l.hud_root = l.ui.get_node("HudRoot") as Control
	l.overlay_root = l.ui.get_node("OverlayRoot") as Control
	l.debug_root = l.ui.get_node("DebugRoot") as Control
	return l


## The High Contrast setting changed: rebuild the theme of every UI layer.
func apply_theme(tokens: VisualTokens, high_contrast: bool) -> void:
	var theme: Theme = UiTheme.build(tokens, high_contrast)
	for c: Control in [screen_root, hud_root, overlay_root, debug_root]:
		c.theme = theme


## Replaces whatever screen is showing with `scene_path`. Returns the new root node.
func swap_screen(scene_path: String) -> Node:
	clear_screen()
	return add_scene(screen_root, scene_path)


func clear_screen() -> void:
	for child: Node in screen_root.get_children():
		release(child)


## Instantiates `scene_path` under `parent`. Null (and an error) if the scene does not load.
func add_scene(parent: Node, scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		Log.error("Game", "cannot load scene %s" % scene_path)
		return null
	var node: Node = packed.instantiate()
	parent.add_child(node)
	return node


## A one-line message near the bottom of the screen that removes itself after `seconds`.
func show_toast(text: String, seconds: float) -> Label:
	var toast: Label = Label.new()
	toast.text = text
	toast.add_theme_font_size_override(&"font_size", UiTheme.FONT_LARGE)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position.y -= 220.0
	var timer: Timer = Timer.new()  # a child of the toast, so both go together even if the layer is freed first
	timer.one_shot = true
	timer.wait_time = seconds
	timer.autostart = true
	timer.timeout.connect(toast.queue_free)
	toast.add_child(timer)
	return toast


## Takes a node out of the tree at once (so the tree is clean this frame) and frees it at the end of the frame.
## Safe from inside one of the node's own signals.
static func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


static func _plain_node(root: Node, node_name: String) -> Node:
	var n: Node = Node.new()
	n.name = node_name
	root.add_child(n)
	return n
