class_name FxTelegraph
extends RefCounted
## What is about to happen, drawn on the ground before it does (VARIETY_SPEC 7.2, 5.6 rule 4, 12.3 `fx_telegraph`).
## `event_warned(id, ticks, x, z)`: a ring at the event's radius with a second ring that contracts onto it for exactly `ticks`. By the
## colour rule of 5.6: a zone that can hurt the player's side (`EventDef.harmful`) is a RED HATCHED disc with a red shrinking outline;
## everything that hurts enemies or helps (the Deadfall Strike, a supply drop) is a CYAN ring with no hatch, so the rule survives
## colour blindness (shape differs, not only colour). `delayed_hit(kind, x, z, ticks)`: a cyan column of light falling onto a strike
## target, a small cyan ring for our shells and missiles, a red hatched ring for a spitter bolt aimed at the core.
## V4-X: the ten events of CONTENT 6 each get the decal of SPEC 7.2 ("lane, ring, cracks, edge arrows"): a LANE (two edge bars that close in,
## on the rail line the freight crosses), CRACKS (a hatched disc with a cracked floor at every breach point), a BAND (a red hatched strip
## along the spawn edge a recount enters from), the PADS (a cyan ring on each turret pad before a core surge) and the CORE (the reach of a
## core vent); a relay window and a static front have no ground decal (the static front's warning is the screen-edge overlay, `FxStatic`).
## Which look an event has is a table by id (`LOOKS`); the data's `harmful` flag decides hatch or cyan, so a harmful event is never cyan.
## Telegraphs, danger zones and enemy projectiles are NEVER tier-gated or dimmed by Reduced Flash: the pools are 8 slots on every tier
## (`VisualQuality.telegraph_decals`) and drop their oldest when full. High Contrast thickens the red outline and the lane bars.

const RING_Y: float = 0.06
const HATCH_Y: float = 0.05
const LANE_Y: float = 0.055
const FLAT_RADIUS_DEFAULT_M: float = 2.0
const CONTRACT: float = 1.7
const SHELL_RADIUS_M: float = 2.0
const MISSILE_RADIUS_M: float = 1.0
const BOLT_RADIUS_M: float = 1.0
const COLUMN_HEIGHT_M: float = 14.0
const COLUMN_WIDTH_M: float = 0.55
const LANE_CAP: int = 4
const CRACK_CAP: int = 8
const LANE_OVERSHOOT_M: float = 4.0  ## the lane runs this far past the yard's edges
const LANE_HALF_WIDTH_M: float = 1.3
const LANE_CLOSE: float = 1.9
const BAND_ASPECT: float = 8.0  ## a recount band is this many times as long as it is wide (the hatch keeps square stripes)
const BREACH_RADIUS_M: float = 1.4
const CORE_VENT_RADIUS_M: float = 6.0
const OUTLINE_INNER: float = 0.88
const OUTLINE_INNER_CONTRAST: float = 0.72
const LANE_THICK: float = 0.14
const LANE_THICK_CONTRAST: float = 0.26

enum Look { RING, LANE, CRACKS, BAND, PADS, CORE, NONE }

## Event id -> its decal. An id that is not here is a plain ring at its `radius_m` (what the slice already did).
const LOOKS: Dictionary = {
	&"runaway_freight": Look.LANE,
	&"freight_call": Look.LANE,
	&"floor_breach": Look.CRACKS,
	&"recount": Look.BAND,
	&"power_surge": Look.PADS,
	&"core_vent": Look.CORE,
	&"accord_window": Look.NONE,
	&"static_front": Look.NONE,
}

var rings_cyan: VfxPool
var rings_red: VfxPool
var hatches: VfxPool
var columns: VfxPool
var lanes_cyan: VfxPool
var lanes_red: VfxPool
var bands: VfxPool
var cracks: VfxPool

var _content: ContentSet
var _lit_outline: ArrayMesh
var _bold_outline: ArrayMesh
var _lit_lane: ArrayMesh
var _bold_lane: ArrayMesh
var _lit_lane_red: ArrayMesh
var _bold_lane_red: ArrayMesh


func setup(parent: Node3D, content: ContentSet, bounds: AABB) -> void:
	_content = content
	var cap: int = VisualQuality.TELEGRAPH_CAP[VisualQuality.Tier.HIGH]
	_lit_outline = VfxMeshes.ring(OUTLINE_INNER, 48, &"add_red", &"add_red")
	_bold_outline = VfxMeshes.ring(OUTLINE_INNER_CONTRAST, 48, &"add_red", &"add_red")
	_lit_lane = VfxMeshes.lane_frame(&"add_cyan", LANE_THICK)
	_bold_lane = VfxMeshes.lane_frame(&"add_cyan", LANE_THICK_CONTRAST)
	_lit_lane_red = VfxMeshes.lane_frame(&"add_red", LANE_THICK)
	_bold_lane_red = VfxMeshes.lane_frame(&"add_red", LANE_THICK_CONTRAST)
	rings_cyan = _make(parent, "TelegraphCyan", VfxMeshes.ring(0.9, 48, &"add_cyan", &"add_white"), cap, VfxPool.Mode.FLAT, bounds)
	rings_red = _make(parent, "TelegraphRed", _lit_outline, cap, VfxPool.Mode.FLAT, bounds)
	hatches = _make(parent, "TelegraphHatch", VfxMeshes.hatch_disc(&"hatch_red"), cap, VfxPool.Mode.FLAT, bounds)
	columns = _make(parent, "TelegraphColumn", VfxMeshes.bolt(&"add_cyan", &"add_white"), 4, VfxPool.Mode.SEGMENT, bounds)
	lanes_cyan = _make(parent, "TelegraphLanes", _lit_lane, LANE_CAP, VfxPool.Mode.STRIP, bounds)
	lanes_red = _make(parent, "TelegraphLanesRed", _lit_lane_red, LANE_CAP, VfxPool.Mode.STRIP, bounds)
	bands = _make(parent, "TelegraphBands", VfxMeshes.hatch_strip(&"hatch_red", BAND_ASPECT), LANE_CAP, VfxPool.Mode.STRIP, bounds)
	cracks = _make(parent, "TelegraphCracks", VfxMeshes.cracks(&"add_red"), CRACK_CAP, VfxPool.Mode.FLAT, bounds)


func pools() -> Array[VfxPool]:
	return [rings_cyan, rings_red, hatches, columns, lanes_cyan, lanes_red, bands, cracks]


## High Contrast thickens the red outline of a danger decal and the bars of a lane (SPEC 12.3 c).
func set_contrast(on: bool) -> void:
	rings_red.set_mesh(_bold_outline if on else _lit_outline)
	lanes_cyan.set_mesh(_bold_lane if on else _lit_lane)
	lanes_red.set_mesh(_bold_lane_red if on else _lit_lane_red)


## The decal of an event (`Look`); RING for an id that has no entry.
static func look_of(event_id: StringName) -> int:
	var look: int = LOOKS.get(event_id, Look.RING)
	return look


## The ground warning of an event that starts in `ticks`.
func warned(event_id: StringName, ticks: int, x: float, z: float) -> void:
	var radius: float = FLAT_RADIUS_DEFAULT_M
	var harmful: bool = false
	var has_radius: bool = false
	var index: int = _content.event_index(event_id)
	if index >= 0:
		var def: EventDef = _content.events[index]
		harmful = def.harmful
		has_radius = def.params.has(&"radius_m")
		radius = def.param(&"radius_m", FLAT_RADIUS_DEFAULT_M)
	var life: float = maxf(float(ticks) * SimWorld.DT, 0.05)
	match look_of(event_id):
		Look.LANE:
			lane(z, life, harmful)
		Look.CRACKS:
			danger(Vector3(x, 0.0, z), BREACH_RADIUS_M, life)
			var _crack: int = cracks.spawn(Vector3(x, RING_Y, z), Vector3.ZERO, BREACH_RADIUS_M * 1.15, BREACH_RADIUS_M * 1.15, life, float(index))
		Look.BAND:
			band(x, z, life)
		Look.PADS:
			for p: Vector2 in _content.arena.turret_pads:
				friendly(Vector3(p.x, 0.0, p.y), 1.7, life)
		Look.CORE:
			friendly(Vector3(_content.arena.core_x, 0.0, _content.arena.core_z), radius if has_radius else CORE_VENT_RADIUS_M, life)
		Look.NONE:
			pass
		_:
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


## The lane along the rail line nearest to `z`: two bars at the lane's edges and a wider pair that closes in onto them over `life`. A lane
## that hurts the player's side (`harmful`) is red; a freight car only hurts enemies, so it is cyan. Returns the rail line's z.
func lane(z: float, life: float, harmful: bool) -> float:
	var arena: ArenaDef = _content.arena
	var rail_z: float = z
	var half_width: float = LANE_HALF_WIDTH_M
	var best: float = INF
	for k: int in arena.rail_z.size():
		if absf(arena.rail_z[k] - z) < best:
			best = absf(arena.rail_z[k] - z)
			rail_z = arena.rail_z[k]
			half_width = arena.rail_half_width[k]
	var half_len: float = (arena.max_x - arena.min_x) * 0.5 + LANE_OVERSHOOT_M
	var at: Vector3 = Vector3((arena.min_x + arena.max_x) * 0.5, LANE_Y, rail_z)
	var pool: VfxPool = lanes_red if harmful else lanes_cyan
	var _outline: int = pool.spawn(at, Vector3(half_len, 0.0, 0.0), half_width, half_width, life)
	var _closing: int = pool.spawn(at, Vector3(half_len, 0.0, 0.0), half_width * LANE_CLOSE, half_width, life)
	return rail_z


## The red hatched band along the spawn edge nearest to (x, z), with a red frame that closes in on it (a recount enters from there).
func band(x: float, z: float, life: float) -> void:
	var region: SpawnRegionDef = _nearest_region(x, z)
	if region == null:
		return
	var mid: Vector2 = Vector2((region.x0 + region.x1) * 0.5, (region.z0 + region.z1) * 0.5)
	var half_len: float = maxf(Vector2(region.x1 - region.x0, region.z1 - region.z0).length() * 0.5, 2.0)
	var yaw: float = 0.0 if absf(region.x1 - region.x0) >= absf(region.z1 - region.z0) else PI * 0.5
	var half_width: float = half_len / BAND_ASPECT
	var at: Vector3 = Vector3(mid.x, HATCH_Y, mid.y)
	var _fill: int = bands.spawn(at, Vector3(half_len, 0.0, 0.0), half_width, half_width, life, yaw)
	var _outline: int = lanes_red.spawn(Vector3(at.x, LANE_Y, at.z), Vector3(half_len, 0.0, 0.0), half_width, half_width, life, yaw)
	var _closing: int = lanes_red.spawn(Vector3(at.x, LANE_Y, at.z), Vector3(half_len, 0.0, 0.0), half_width * LANE_CLOSE, half_width, life, yaw)


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
	return (
		rings_cyan.live_count() + rings_red.live_count() + hatches.live_count() + columns.live_count()
		+ lanes_cyan.live_count() + lanes_red.live_count() + bands.live_count() + cracks.live_count()
	)


func _nearest_region(x: float, z: float) -> SpawnRegionDef:
	var best: SpawnRegionDef = null
	var best_d: float = INF
	for r: SpawnRegionDef in _content.arena.spawn_regions:
		var d: float = Geometry2D.get_closest_point_to_segment(Vector2(x, z), Vector2(r.x0, r.z0), Vector2(r.x1, r.z1)).distance_to(Vector2(x, z))
		if d < best_d:
			best_d = d
			best = r
	return best


func _make(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, pool_mode: int, bounds: AABB) -> VfxPool:
	var pool: VfxPool = VfxPool.new()
	pool.setup(parent, node_name, mesh_res, cap, pool_mode, bounds)
	return pool
