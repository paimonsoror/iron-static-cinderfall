class_name FxGhosts
extends RefCounted
## The ghost swarm (VARIETY_SPEC 10.3 `fx_ghost_swarm`; V4-X): a cosmetic crowd of dark CHORUS silhouettes massing OUTSIDE the playable
## rectangle, beyond the spawn edges, so a wave feels bigger than the 50 + 40 bodies the sim and the pools allow. One transform-only
## MultiMesh of 80 (limited to none / 40 / 80 by the tier), one draw call. A ghost is nothing the sim knows: it has NO optic (one red optic
## per enemy and nothing else glows, so the survivors of a chain stay countable), never enters the playable rectangle, is not a target and
## has no health. How many show follows the pressure (living enemies over 40, clamped) so they thin out between waves. Each ghost owns a
## fixed place beyond one spawn region and sways a little on the spot. First in the cut order of the performance plan (ARCH 13.2).

const CAP_HIGH: int = 80
const DEPTH_MIN_M: float = 1.4  ## closest to the spawn edge
const DEPTH_MAX_M: float = 6.5
const FULL_AT_ALIVE: float = 40.0
const BODY_Y: float = 0.18

var node: MultiMeshInstance3D

var _mm: MultiMesh
var _ctx: FxContext
var _base: PackedVector3Array = PackedVector3Array()  ## resting place of every ghost (x, scale, z)
var _yaw: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _limit: int = CAP_HIGH
var _shown: int = 0
var _t: float = 0.0
var _hold: bool = false  ## Reduced Flash: the ghosts stand still (nothing flickers or crawls)


func setup(parent: Node3D, bounds: AABB, ctx: FxContext) -> void:
	_ctx = ctx
	_base.resize(CAP_HIGH)
	_yaw.resize(CAP_HIGH)
	_phase.resize(CAP_HIGH)
	var regions: Array[SpawnRegionDef] = ctx.content.arena.spawn_regions
	var center: Vector2 = Vector2(
		(ctx.content.arena.min_x + ctx.content.arena.max_x) * 0.5, (ctx.content.arena.min_z + ctx.content.arena.max_z) * 0.5
	)
	for i: int in CAP_HIGH:
		var region: SpawnRegionDef = regions[i % regions.size()] if not regions.is_empty() else null
		var spot: Vector2 = center + Vector2(14.0, 0.0)
		var outward: Vector2 = Vector2.RIGHT
		if region != null:
			var along: float = ctx.rng.randf()
			var on_edge: Vector2 = Vector2(lerpf(region.x0, region.x1, along), lerpf(region.z0, region.z1, along))
			var edge: Vector2 = Vector2(region.x1 - region.x0, region.z1 - region.z0)
			outward = Vector2(-edge.y, edge.x).normalized()
			if outward.dot(on_edge - center) < 0.0:
				outward = -outward
			spot = on_edge + outward * ctx.rng.randf_range(DEPTH_MIN_M, DEPTH_MAX_M) + edge.normalized() * ctx.rng.randf_range(-1.5, 1.5)
		_base[i] = Vector3(spot.x, ctx.rng.randf_range(0.8, 1.25), spot.y)
		_yaw[i] = atan2(-outward.y, -outward.x) + ctx.rng.randf_range(-0.5, 0.5)
		_phase[i] = ctx.rng.randf_range(0.0, TAU)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false
	_mm.use_custom_data = false
	_mm.mesh = _mesh()
	_mm.instance_count = CAP_HIGH
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = "GhostSwarm"
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func set_quality(tier: int) -> void:
	_limit = VisualQuality.ghost_swarm(tier)
	if _limit == 0:
		_shown = 0
		_mm.visible_instance_count = 0


func set_reduced(on: bool) -> void:
	_hold = on


## Places the ghosts of this frame. Call once per rendered frame.
func step(delta: float) -> void:
	if _limit == 0:
		return
	_t += delta
	var pressure: float = 0.0
	if _ctx.sim != null:
		pressure = clampf(float(_ctx.sim.alive_count()) / FULL_AT_ALIVE, 0.0, 1.0)
	_shown = roundi(float(_limit) * pressure)
	for i: int in _shown:
		var sway: float = 0.0 if _hold else sin(_t * 1.3 + _phase[i]) * 0.22
		var b: Vector3 = _base[i]
		var basis_i: Basis = Basis(Vector3.UP, _yaw[i]) * Basis.from_scale(Vector3.ONE * b.y)
		var bob: float = 0.0 if _hold else absf(sin(_t * 2.1 + _phase[i])) * 0.06
		_mm.set_instance_transform(i, Transform3D(basis_i, Vector3(b.x + sway, BODY_Y + bob, b.z)))
	_mm.visible_instance_count = _shown


func shown() -> int:
	return _shown


func limit() -> int:
	return _limit


## Where ghost `i` rests (x, z); tests check that none is inside the playable rectangle.
func resting_place(i: int) -> Vector2:
	return Vector2(_base[i].x, _base[i].z)


func clear() -> void:
	_shown = 0
	_mm.visible_instance_count = 0


## A hunched silhouette of about 20 triangles: a wedge body on a low bar. Dark red, no emission, no optic.
func _mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.prism(Vector3(0.55, 0.4, 0.8), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0)), &"steel_red")
	mb.box(Vector3(0.7, 0.08, 0.14), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.3)), &"steel_red")
	return mb.build()
