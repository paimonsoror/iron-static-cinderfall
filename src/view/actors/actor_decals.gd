class_name ActorDecals
extends RefCounted
## Blob shadows, world health bars and the red rings under elites: transform-only MultiMeshInstance3Ds, one draw call each (ARCH 8; no
## per-instance data, which is unreliable on some PowerVR GPUs). Fill the frame with begin_frame, add_*, end_frame.

const SHADOW_CAPACITY: int = 120
const BAR_CAPACITY: int = 32
const RING_CAPACITY: int = 4  ## elites alive (VARIETY_SPEC 5.5)
const RING_Y: float = 0.045
const SHADOW_Y: float = 0.03
const BAR_W: float = 1.0
const BAR_H: float = 0.13

var shadow_node: MultiMeshInstance3D
var bar_bg_node: MultiMeshInstance3D
var bar_fill_node: MultiMeshInstance3D
var ring_node: MultiMeshInstance3D

var _shadow_mm: MultiMesh
var _bg_mm: MultiMesh
var _fill_mm: MultiMesh
var _ring_mm: MultiMesh
var _shadows: int = 0
var _bars: int = 0
var _rings: int = 0
var _bar_basis: Basis = Basis.IDENTITY


func setup(parent: Node3D, arena: ArenaDef) -> void:
	var bounds: AABB = AABB(
		Vector3(arena.min_x - 20.0, -2.0, arena.min_z - 20.0),
		Vector3(arena.max_x - arena.min_x + 40.0, 10.0, arena.max_z - arena.min_z + 40.0)
	)
	shadow_node = _make(parent, "Shadows", ActorMeshes.shadow_disc(), SHADOW_CAPACITY, bounds)
	bar_bg_node = _make(parent, "BarBack", ActorMeshes.bar_quad(&"rubber"), BAR_CAPACITY, bounds)
	bar_fill_node = _make(parent, "BarFill", ActorMeshes.bar_quad(&"emit_red"), BAR_CAPACITY, bounds)
	ring_node = _make(parent, "EliteRings", ActorMeshes.elite_ring(), RING_CAPACITY, bounds)
	_ring_mm = ring_node.multimesh
	_shadow_mm = shadow_node.multimesh
	_bg_mm = bar_bg_node.multimesh
	_fill_mm = bar_fill_node.multimesh
	# a quad facing the camera: the camera basis (CameraFit) turned so the quad normal (+Y) points back at it
	var pitch: float = deg_to_rad(arena.pitch_down_deg)
	var cam: Basis = Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.UP, deg_to_rad(arena.yaw_deg))
	_bar_basis = cam * Basis(Vector3.RIGHT, PI * 0.5)


## High Contrast thickens the red ring of an elite (GDD 10.3): the same transform-only pool draws a wider band.
func set_high_contrast(on: bool) -> void:
	if _ring_mm != null:
		_ring_mm.mesh = ActorMeshes.elite_ring(on)


func begin_frame() -> void:
	_shadows = 0
	_bars = 0
	_rings = 0


## A round shadow of `radius` meters under (x, z).
func add_shadow(x: float, z: float, radius: float) -> void:
	if _shadows >= SHADOW_CAPACITY:
		return
	_shadow_mm.set_instance_transform(
		_shadows, Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), Vector3(x, SHADOW_Y, z))
	)
	_shadows += 1


## A health bar at `world_pos` (the bar's center), `fraction` full (0..1).
func add_bar(world_pos: Vector3, fraction: float) -> void:
	if _bars >= BAR_CAPACITY:
		return
	var f: float = clampf(fraction, 0.0, 1.0)
	var back: Basis = _bar_basis * Basis.from_scale(Vector3(BAR_W, 1.0, BAR_H))
	_bg_mm.set_instance_transform(_bars, Transform3D(back, world_pos))
	var fill_w: float = maxf(BAR_W * f - 0.06, 0.001)
	var fill: Basis = _bar_basis * Basis.from_scale(Vector3(fill_w, 1.0, BAR_H * 0.6))
	var left: Vector3 = _bar_basis.x * (-(BAR_W - 0.06 - fill_w) * 0.5)
	_fill_mm.set_instance_transform(_bars, Transform3D(fill, world_pos + left + _bar_basis.y * 0.02))
	_bars += 1


## The red ring of an elite (radius in meters) under (x, z); the pool holds `RING_CAPACITY`, the rest are not drawn.
func add_ring(x: float, z: float, radius: float) -> void:
	if _rings >= RING_CAPACITY:
		return
	_ring_mm.set_instance_transform(
		_rings, Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), Vector3(x, RING_Y, z))
	)
	_rings += 1


func end_frame() -> void:
	_ring_mm.visible_instance_count = _rings
	_shadow_mm.visible_instance_count = _shadows
	_bg_mm.visible_instance_count = _bars
	_fill_mm.visible_instance_count = _bars


func shadow_count() -> int:
	return _shadows


func bar_count() -> int:
	return _bars


func ring_count() -> int:
	return _rings


func clear() -> void:
	begin_frame()
	end_frame()


func _make(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, bounds: AABB) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = mesh_res
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
