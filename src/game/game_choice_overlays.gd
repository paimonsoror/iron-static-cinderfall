class_name GameChoiceOverlays
extends Node
## The life of the intermission choice screens (VARIETY_SPEC 13.4): salvage, draft, route and boss briefing are HUD
## overlays inside INTERMISSION, not application states. While the sim waits for a choice (`Events.await_changed`,
## `RunApi.awaiting()`), the overlay scene of that step is shown above the HUD; when the wait ends it is removed.
## The overlays (`src/ui/run/*_overlay.tscn`, contract `setup(api, content)`) send the commands themselves.
##
## The node is a child of the RunController, so it leaves with the run and takes its overlay and its Events
## connection with it. A choice can never be dismissed: the back gesture pauses (BackPolicy), and the pause overlay
## sits in a layer above this one.

const SCENES: Dictionary[int, String] = {
	RunApi.AWAIT_SALVAGE: "res://src/ui/run/salvage_overlay.tscn",
	RunApi.AWAIT_DRAFT: "res://src/ui/run/draft_overlay.tscn",
	RunApi.AWAIT_ROUTE: "res://src/ui/run/route_overlay.tscn",
	RunApi.AWAIT_BOSS_BRIEF: "res://src/ui/run/boss_brief_overlay.tscn",
}

var overlay: Control  ## the overlay on screen, or null
var shown_kind: int = RunApi.AWAIT_NONE

var _api: RunApi
var _content: ContentSet
var _parent: Node


## `parent` is the layer the overlays go into (Game: HudRoot, so they draw above the HUD that was added before them).
func setup(api: RunApi, content: ContentSet, parent: Node) -> void:
	_api = api
	_content = content
	_parent = parent
	if not Events.await_changed.is_connected(_on_await_changed):
		Events.await_changed.connect(_on_await_changed)


## Shows what the run waits for right now (a resumed run can start inside a choice, with no signal to announce it).
func sync() -> void:
	if _api != null and _api.awaiting() != shown_kind:
		_show(_api.awaiting())


func _exit_tree() -> void:
	if Events.await_changed.is_connected(_on_await_changed):
		Events.await_changed.disconnect(_on_await_changed)
	_clear()


func _on_await_changed(kind: int) -> void:
	_show(kind)


func _show(kind: int) -> void:
	_clear()
	shown_kind = kind
	if not SCENES.has(kind) or _parent == null or not is_instance_valid(_parent):
		return
	var packed: PackedScene = load(SCENES[kind]) as PackedScene
	if packed == null:
		Log.error("Game", "cannot load the overlay of await %d" % kind)
		return
	overlay = packed.instantiate() as Control
	if overlay == null:
		return
	_parent.add_child(overlay)
	overlay.call(&"setup", _api, _content)


func _clear() -> void:
	GameLayers.release(overlay)
	overlay = null
	shown_kind = RunApi.AWAIT_NONE
