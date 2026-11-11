class_name GameViewBuilder
extends RefCounted
## Builds the BattleView for `Game`: the scene in the World layer, set up on the content, plus the debug overlay node
## when `--debug-overlay` asks. The caller applies the player's view settings (GameViewSettings).

const SCENE_VIEW: String = "res://src/view/battle_view.tscn"


## Null (and an error in the log) when the scene does not load.
static func build(layers: GameLayers, content: ContentSet, args: DebugArgs) -> BattleView:
	var view: BattleView = layers.add_scene(layers.world, SCENE_VIEW) as BattleView
	if view == null:
		return null
	view.setup(content)
	if args.debug_overlay != "":
		GameDebugTools.add_overlay(view, content.arena)
	return view
