class_name GameDebugTools
extends RefCounted
## The debug wiring of `Game` (ARCH 11): the PerfHud of `--debug-perf` and the BattleDebugOverlay of
## `--debug-overlay[=all|flow,slots,stuck,spawns]`. Static helpers, so Game stays small and the wiring is testable.

const OVERLAY_NODE: String = "BattleDebugOverlay"


## A PerfHud under `parent` (full rect), set up after it is in the tree. The `[PERF]` line starts logging at once.
static func add_perf_hud(parent: Control, enemies_source: Callable) -> PerfHud:
	var perf: PerfHud = PerfHud.new()
	parent.add_child(perf)
	perf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perf.setup(enemies_source, true)
	return perf


## The overlay node under the view (a Node3D in the 3D world). It shows nothing until `bind` gives it a sim.
static func add_overlay(view: BattleView, arena: ArenaDef) -> BattleDebugOverlay:
	var overlay: BattleDebugOverlay = BattleDebugOverlay.new()
	overlay.setup(arena)
	view.add_child(overlay)
	return overlay


## The overlay of `view`, or null (no view, a freed view, or no --debug-overlay).
static func overlay_of(view: BattleView) -> BattleDebugOverlay:
	if view == null or not is_instance_valid(view):
		return null
	return view.get_node_or_null(OVERLAY_NODE) as BattleDebugOverlay


## A run starts: the overlay follows its sim and shows the layers `spec` names; the PerfHud gets the tick times.
static func bind(view: BattleView, controller: RunController, perf: PerfHud, spec: String) -> void:
	var overlay: BattleDebugOverlay = overlay_of(view)
	if overlay != null:
		overlay.bind(controller.sim)
		overlay.apply_spec(spec)
	if perf != null:
		controller.tick_sink = perf.record_tick_usec


## A run ends: the overlay drops its sim reference and its Events connection.
static func unbind(view: BattleView) -> void:
	var overlay: BattleDebugOverlay = overlay_of(view)
	if overlay != null:
		overlay.unbind()
