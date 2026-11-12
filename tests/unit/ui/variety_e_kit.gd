class_name VarietyEKit
extends RefCounted
## Helpers shared by the variety UI tests of task V2-E (the draft, route, boss briefing and salvage overlays and the variety
## combat HUD). Not a suite. Everything runs on TestContent.variety() and a FakeRunApi filled by FakeRunPresets.

const DRAFT: String = "res://src/ui/run/draft_overlay.tscn"
const ROUTE: String = "res://src/ui/run/route_overlay.tscn"
const BOSS: String = "res://src/ui/run/boss_brief_overlay.tscn"
const SALVAGE: String = "res://src/ui/run/salvage_overlay.tscn"
const HUD: String = "res://src/ui/combat/combat_hud.tscn"
const SIZES: Array[Vector2] = [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 1120.0)]
const STATES: PackedStringArray = ["draft", "route", "boss_brief", "salvage"]
const SCENES: Dictionary[String, String] = {"draft": DRAFT, "route": ROUTE, "boss_brief": BOSS, "salvage": SALVAGE}


## A plain Control of `view_size` inside the suite: the stand-in for a screen layer.
static func host(suite: GdUnitTestSuite, view_size: Vector2) -> Control:
	var node: Control = Control.new()
	suite.auto_free(node)
	node.size = view_size
	suite.add_child(node)
	return node


## A FakeRunApi in the FakeRunPresets state `state`.
static func api_for(state: String) -> FakeRunApi:
	var api: FakeRunApi = FakeRunApi.new()
	var ok: bool = FakeRunPresets.apply(api, TestContent.variety(), state)
	assert(ok)
	return api


## The overlay of preset `state` on `api`, set up on the variety fixture under a `view_size` host.
static func overlay(suite: GdUnitTestSuite, state: String, api: FakeRunApi, view_size: Vector2 = SIZES[0]) -> RunOverlayBase:
	var packed: PackedScene = load(SCENES[state]) as PackedScene
	var node: RunOverlayBase = packed.instantiate() as RunOverlayBase
	host(suite, view_size).add_child(node)
	node.call("setup", api, TestContent.variety())
	return node


static func hud(suite: GdUnitTestSuite, api: RunApi, view_size: Vector2 = SIZES[0]) -> CombatHud:
	var packed: PackedScene = load(HUD) as PackedScene
	var node: CombatHud = packed.instantiate() as CombatHud
	host(suite, view_size).add_child(node)
	node.setup(api, TestContent.variety(), null)
	return node


static func settle(tree: SceneTree, frames: int = 4) -> void:
	for i: int in frames:
		await tree.process_frame


static func calls_of(api: FakeRunApi, cmd: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in api.calls:
		var name_of_cmd: String = c["cmd"]
		if name_of_cmd == cmd:
			out.append(c)
	return out


static func nodes_of(root: Node, kind: Variant) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, kind, out)
	return out


## Every Button (and RunSelectable panel) that is visible in the tree and narrower or lower than `min_px` once laid out.
static func small_touch(root: Node, min_px: float = 132.0) -> Array[String]:
	var bad: Array[String] = []
	for n: Node in nodes_of(root, BaseButton):
		var b: BaseButton = n as BaseButton
		if b.is_visible_in_tree() and (b.size.x < min_px or b.size.y < min_px):
			bad.append("%s %s" % [b.get_path(), b.size])
	for n: Node in nodes_of(root, RunSelectable):
		var s: RunSelectable = n as RunSelectable
		if s.is_visible_in_tree() and (s.size.x < min_px or s.size.y < min_px):
			bad.append("%s %s" % [s.get_path(), s.size])
	return bad


## Every visible Label or Button text drawn below 30 px.
static func small_text(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for n: Node in nodes_of(root, Label):
		var l: Label = n as Label
		if l.is_visible_in_tree() and l.text != "" and l.get_theme_font_size(&"font_size") < 30:
			bad.append("%s %d '%s'" % [l.get_path(), l.get_theme_font_size(&"font_size"), l.text])
	for n: Node in nodes_of(root, Button):
		var b: Button = n as Button
		if b.is_visible_in_tree() and b.text != "" and b.get_theme_font_size(&"font_size") < 30:
			bad.append("%s %d '%s'" % [b.get_path(), b.get_theme_font_size(&"font_size"), b.text])
	return bad


## Visible Labels and Buttons whose text is empty-looking or a "#key#" marker.
static func bad_texts(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for n: Node in nodes_of(root, Label):
		var l: Label = n as Label
		if l.is_visible_in_tree() and _is_bad(l.text):
			bad.append("%s '%s'" % [l.get_path(), l.text])
	for n: Node in nodes_of(root, Button):
		var b: Button = n as Button
		if b.is_visible_in_tree() and b.text.begins_with("#") and b.text.ends_with("#"):
			bad.append("%s '%s'" % [b.get_path(), b.text])
	return bad


## Global rect of a control.
static func rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


static func _is_bad(text: String) -> bool:
	var t: String = text.strip_edges()
	return t.begins_with("#") and t.ends_with("#") and t.length() > 2


static func _collect(node: Node, kind: Variant, out: Array[Node]) -> void:
	if is_instance_of(node, kind):
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, kind, out)
