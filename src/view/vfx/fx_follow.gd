class_name FxFollow
extends RefCounted
## A transform-only MultiMesh that is refilled EVERY frame (V4-X): the rings under things that move (wards, auras) and the lines between
## things that move (tethers). Unlike a `VfxPool` it has no lifetimes: `begin`, then `add_ring` / `add_line` for what exists this frame,
## then `end`. One draw call (no draw call at all when nothing was added), no per-instance data (ARCH 8). Allocated once at the HIGH size;
## a quality tier sets `limit` and whatever does not fit is simply not drawn (the caller adds the most important things first).

var node: MultiMeshInstance3D
var capacity: int = 0
var limit: int = 0
var dropped: int = 0  ## things offered this frame that did not fit

var _mm: MultiMesh
var _n: int = 0
var _xf: Array[Transform3D] = []  ## what was written (a headless MultiMesh cannot be read back)


func setup(parent: Node3D, node_name: String, mesh_res: Mesh, cap: int, bounds: AABB) -> void:
	capacity = cap
	limit = cap
	_xf.resize(cap)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false
	_mm.use_custom_data = false
	_mm.mesh = mesh_res
	_mm.instance_count = cap
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func set_limit(n: int) -> void:
	limit = clampi(n, 0, capacity)


func set_mesh(mesh_res: Mesh) -> void:
	_mm.mesh = mesh_res


func begin() -> void:
	_n = 0
	dropped = 0


## A ring of `radius` meters lying on the ground at `at`. False when it did not fit.
func add_ring(at: Vector3, radius: float) -> bool:
	if _n >= limit:
		dropped += 1
		return false
	_put(Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), at))
	return true


## A ribbon from `a` to `b`, `width` meters wide. False when it did not fit.
func add_line(a: Vector3, b: Vector3, width: float) -> bool:
	if _n >= limit:
		dropped += 1
		return false
	_put(VfxPool.along(a, b, width))
	return true


func end() -> void:
	_mm.visible_instance_count = _n


func drawn() -> int:
	return _n


## Where the i-th thing of this frame is drawn (tests; the MultiMesh itself is write-only in a headless run).
func transform_of(i: int) -> Transform3D:
	return _xf[i] if i >= 0 and i < _n else Transform3D.IDENTITY


func clear() -> void:
	_n = 0
	_mm.visible_instance_count = 0


func _put(xf: Transform3D) -> void:
	_xf[_n] = xf
	_mm.set_instance_transform(_n, xf)
	_n += 1
