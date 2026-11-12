class_name FxTelegraph
extends RefCounted
## What is about to happen, drawn on the ground before it does (VARIETY_SPEC 7.2, 5.6 rule 4, 12.3 `fx_telegraph`).
## `event_warned(id, ticks, x, z)`: a ring at the event's radius with a second ring that contracts onto it for exactly `ticks`. By the
## colour rule of 5.6: a zone that can hurt the player's side (`EventDef.harmful`) is a RED HATCHED disc with a red shrinking outline;
## everything that hurts enemies or helps (the Deadfall Strike, a supply drop) is a CYAN ring with no hatch, so the rule survives
## colour blindness (shape differs, not only colour). `delayed_hit(kind, x, z, ticks)`: a cyan column of light falling onto a strike
## target, a small cyan ring for our shells and missiles, a red hatched ring for a spitter bolt aimed at the core.
## Telegraphs, danger zones and enemy projectiles are NEVER tier-gated or dimmed by Reduced Flash: the pools are 8 slots on every tier
## (`VisualQuality.telegraph_decals`) and drop their oldest when full. Four pooled MultiMeshes (cyan ring, red outline, red hatch, column).

const RING_Y: float = 0.06
const HATCH_Y: float = 0.05
const FLAT_RADIUS_DEFAULT_M: float = 2.0
const CONTRACT: float = 1.7
const SHELL_RADIUS_M: float = 2.0
const MISSILE_RADIUS_M: float = 1.0
const BOLT_RADIUS_M: float = 1.0
const COLUMN_HEIGHT_M: float = 14.0
const COLUMN_WIDTH_M: float = 0.55

var rings_cyan: VfxPool
var rings_red: VfxPool
var hatches: VfxPool
var columns: VfxPool

var _content: ContentSet


func setup(parent: Node3D, content: ContentSet, bounds: AABB) -> void:
	_content = content
	var cap: int = VisualQuality.TELEGRAPH_CAP[VisualQuality.Tier.HIGH]
	rings_cyan = _make(parent, "TelegraphCyan", VfxMeshes.ring(0.9, 48, &"add_cyan", &"add_white"), cap, VfxPool.Mode.FLAT, bounds)
	rings_red = _make(parent, "TelegraphRed", VfxMeshes.ring(0.88, 48, &"add_red", &"add_red"), cap, VfxPool.Mode.FLAT, bounds)
	hatches = _make(parent, "TelegraphHatch", VfxMeshes.hatch_disc(&"hatch_red"), cap, VfxPool.Mode.FLAT, bounds)
	columns = _make(parent, "TelegraphColumn", VfxMeshes.bolt(&"add_cyan", &"add_white"), 4, VfxPool.Mode.SEGMENT, bounds)


func pools() -> Array[VfxPool]:
	return [rings_cyan, rings_red, hatches, columns]


## The ground warning of an event that starts in `ticks`.
func warned(event_id: StringName, ticks: int, x: float, z: float) -> void:
	var radius: float = FLAT_RADIUS_DEFAULT_M
	var harmful: bool = false
	var index: int = _content.event_index(event_id)
	if index >= 0:
		var def: EventDef = _content.events[index]
		harmful = def.harmful
		radius = def.param(&"radius_m", FLAT_RADIUS_DEFAULT_M)
	var life: float = maxf(float(ticks) * SimWorld.DT, 0.05)
	if harmful:
		danger(Vector3(x, 0.0, z), radius, life)
	else:
		friendly(Vector3(x, 0.0, z), radius, life)


## A cyan outline at `radius` and a ring contracting onto it over `life` seconds.
func friendly(at: Vector3, radius: float, life: float) -> void:
	var p: Vector3 = Vector3(at.x, RING_Y, at.z)
	var _outline: int = rings_cyan.spawn(p, Vector3.ZERO, radius, radius, life)
	var _closing: int = rings_cyan.spawn(p, Vector3.ZERO, radius * CONTRACT, radius, life)


## A red hatched disc at `radius` with a red outline that shrinks onto it: the one look of a zone that can hurt the player's side.
func danger(at: Vector3, radius: float, life: float) -> void:
	var _fill: int = hatches.spawn(Vector3(at.x, HATCH_Y, at.z), Vector3.ZERO, radius, radius, life)
	var p: Vector3 = Vector3(at.x, RING_Y, at.z)
	var _outline: int = rings_red.spawn(p, Vector3.ZERO, radius, radius, life)
	var _closing: int = rings_red.spawn(p, Vector3.ZERO, radius * 1.6, radius, life)


## A delayed hit (`HazardState.K_*`) that lands in `ticks`.
func delayed(kind: int, x: float, z: float, ticks: int) -> void:
	var life: float = maxf(float(ticks) * SimWorld.DT, 0.05)
	match kind:
		HazardState.K_STRIKE:
			var _col: int = columns.spawn(Vector3(x, COLUMN_HEIGHT_M, z), Vector3(x, 0.1, z), COLUMN_WIDTH_M, COLUMN_WIDTH_M * 0.7, life)
		HazardState.K_SHELL:
			friendly(Vector3(x, 0.0, z), SHELL_RADIUS_M * 0.5, life)
		HazardState.K_MISSILE:
			friendly(Vector3(x, 0.0, z), MISSILE_RADIUS_M * 0.5, life)
		HazardState.K_BOLT:
			danger(Vector3(x, 0.0, z), BOLT_RADIUS_M, life)


func live_count() -> int:
	return rings_cyan.live_count() + rings_red.live_count() + hatches.live_count() + columns.live_count()


func _make(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, pool_mode: int, bounds: AABB) -> VfxPool:
	var pool: VfxPool = VfxPool.new()
	pool.setup(parent, node_name, mesh_res, cap, pool_mode, bounds)
	return pool
