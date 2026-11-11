class_name CombatHudTestKit
extends RefCounted
## Helpers shared by the combat HUD tests (not a suite itself).

const HUD_SCENE: String = "res://src/ui/combat/combat_hud.tscn"


## A plain top-left anchored Control of `view_size` inside the suite: a stand-in for the screen. Children that
## use a full-rect preset (the HUD, the pause overlay) take its size, as they do under Game's layers.
static func screen(suite: GdUnitTestSuite, view_size: Vector2) -> Control:
	var node: Node = suite.auto_free(Control.new())
	var host: Control = node as Control
	host.size = view_size
	suite.add_child(host)
	return host


## A CombatHud on a `view_size` screen, set up on the frozen baseline content with `api`.
static func make_hud(suite: GdUnitTestSuite, api: RunApi, view_size: Vector2 = Vector2(1080.0, 1920.0)) -> CombatHud:
	var packed: PackedScene = load(HUD_SCENE) as PackedScene
	var hud: CombatHud = packed.instantiate() as CombatHud
	screen(suite, view_size).add_child(hud)
	hud.setup(api, TestContent.baseline(), null)
	return hud


## Lets layout and deferred calls run.
static func settle(tree: SceneTree, frames: int = 3) -> void:
	for i: int in frames:
		await tree.process_frame


## Waits real time, e.g. for the 0.18 s drawer slide to finish.
static func wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout


static func buttons(root: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	_collect_buttons(root, out)
	return out


static func labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	_collect_labels(root, out)
	return out


## Every Label that is visible in the tree and has no text (what "no label is empty" forbids).
static func empty_visible_labels(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for l: Label in labels(root):
		if l.is_visible_in_tree() and l.text.strip_edges() == "":
			bad.append(str(l.get_path()))
	return bad


## Puts the HUD into state `n` (0 = untouched .. 5): drawer, max and locked cards, boss and low core with
## abilities and reload, intermission, deploying. Cumulative, so call 0..5 in order.
static func drive(hud: CombatHud, api: FakeRunApi, n: int) -> void:
	match n:
		1:
			hud.open_drawer()
		2:
			api.fake_upgrade_level[&"fire_rate"] = 5
			api.fake_upgrade_cost[&"fire_rate"] = -1
			api.fake_purchase_block[&"fire_rate"] = Reason.Id.MAX_LEVEL
			api.fake_purchase_block[&"smg_unlock"] = Reason.Id.PREREQ_NOT_MET
		3:
			api.fake_boss_hp = 100.0
			api.fake_shield_hp = 50.0
			api.set_core(100.0)
			api.fake_ability_active_left[&"shield"] = 90
			api.fake_ability_cooldown_left[&"emp"] = 700
			api.fake_magazine = 0
			api.fake_reload_ticks_left = 20
			Events.wave_started.emit(5)
			Events.hint_requested.emit("hint.intermission")
		4:
			api.fake_phase = GameState.Id.INTERMISSION
			api.fake_phase_ticks_left = 1
			Events.intermission_started.emit(4, 480)
		5:
			api.fake_phase = GameState.Id.PREPARING
			api.fake_phase_ticks_left = 0


static func calls_of(api: FakeRunApi, cmd: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in api.calls:
		var name_of_cmd: String = c["cmd"]
		if name_of_cmd == cmd:
			out.append(c)
	return out


static func _collect_buttons(node: Node, out: Array[BaseButton]) -> void:
	var b: BaseButton = node as BaseButton
	if b != null:
		out.append(b)
	for child: Node in node.get_children():
		_collect_buttons(child, out)


static func _collect_labels(node: Node, out: Array[Label]) -> void:
	var l: Label = node as Label
	if l != null:
		out.append(l)
	for child: Node in node.get_children():
		_collect_labels(child, out)
