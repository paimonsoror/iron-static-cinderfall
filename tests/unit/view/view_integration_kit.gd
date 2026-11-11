class_name ViewIntegrationKit
extends RefCounted
## Builders for the view_* suites of W2-E: a whole BattleView on a live puppet world, node counting, tree searches.
## Not a suite itself.


## A BattleView from the real scene, set up on `content` and added under `host` (freed with the suite).
static func battle_view(host: GdUnitTestSuite, content: ContentSet) -> BattleView:
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	var node: Node = packed.instantiate()
	host.auto_free(node)
	var view: BattleView = node as BattleView
	host.add_child(view)
	view.setup(content)
	return view


## A SimPuppet running `scenario_name` on `content`, added under `host`.
static func puppet(host: GdUnitTestSuite, content: ContentSet, scenario_name: String) -> SimPuppet:
	var p: SimPuppet = SimPuppet.new()
	host.auto_free(p)
	host.add_child(p)
	p.setup(content, scenario_name, 1)
	return p


## Every descendant of `root` plus `root` itself.
static func count_nodes(root: Node) -> int:
	var n: int = 1
	for c: Node in root.get_children():
		n += count_nodes(c)
	return n


## Every node under `root` (root included) that is of class `type_name`.
static func nodes_of(root: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_class(type_name):
		out.append(root)
	for c: Node in root.get_children():
		out.append_array(nodes_of(c, type_name))
	return out


## Steps the puppet `ticks` ticks and renders the view after every one, like a running game at 60 fps.
static func run(view: BattleView, p: SimPuppet, ticks: int) -> void:
	for _t: int in ticks:
		p.step_once()
		view.render(1.0, SimPuppet.TICK_DT)
