class_name MiniSwarm
extends RefCounted
## The minis of one type (mote, shard; VARIETY_SPEC 5.4, 10.2) drawn as ONE transform-only MultiMeshInstance3D: one draw call and
## at most `alive_cap` (40) instances whatever the tier, a 40 triangle mesh with two surfaces. There is no node and no pooled actor
## per mini and nothing is allocated after `setup`: every frame the layer calls `begin_frame`, `add` once per living mini (from the
## store, interpolated like the bodies) and `end_frame`, which sets `visible_instance_count`. A mini hops (a |sin| bounce with a
## phase of its own), turns to face where it walks and pops to 1.35 times its size for three frames when it is hit (a transform
## pop instead of the material flash: per-instance data is unreliable on PowerVR GPUs, ARCH 8). When more minis are alive than
## the cap the extra ones are not drawn (never an effect on the sim).
## The mesh is a private copy of the type's mesh so that the look's materials can be set on its surfaces: a MultiMesh cannot
## override materials per surface. Copies are made at `setup` (and once more the first time the other look class is asked for).

const HOP_RATE: float = 11.0
const HOP_HEIGHT: float = 0.1
const POP_SCALE: float = 0.35
const POP_FRAMES: int = 3

var node: MultiMeshInstance3D
var type_index: int = 0
var capacity: int = 0

var _mm: MultiMesh
var _id: StringName = &""
var _n: int = 0
var _look: int = LookDevStyle.Look.CURRENT
var _tier: int = VisualQuality.Tier.HIGH
var _contrast: bool = false
var _copies: Dictionary[bool, ArrayMesh] = {}  ## by "the hard-surface actors are on": the private mesh with its own surface materials
var _roles: Dictionary[bool, Array] = {}  ## the palette role of each surface of the copy
var _origin: PackedVector3Array = PackedVector3Array()  ## where each instance was drawn last frame (tests: a headless MultiMesh is write-only)
var _size: PackedFloat32Array = PackedFloat32Array()


func setup(
	parent: Node3D, type_idx: int, enemy_id: StringName, cap: int, bounds: AABB, look: int, tier: int
) -> void:
	type_index = type_idx
	capacity = maxi(cap, 1)
	_origin.resize(capacity)
	_size.resize(capacity)
	_id = enemy_id
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = false  # transform only: the baked vertex colours are the look, nothing is per instance
	_mm.use_custom_data = false
	_mm.mesh = _copy_for(look)
	_mm.instance_count = capacity
	_mm.visible_instance_count = 0
	node = MultiMeshInstance3D.new()
	node.name = "Minis_%s" % String(enemy_id)
	node.multimesh = _mm
	node.custom_aabb = bounds
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	apply_look(look, tier, false)


## Dresses the swarm for a look, tier and High Contrast: the mesh of the look and the shared materials on its surfaces.
func apply_look(look: int, tier: int, contrast: bool) -> void:
	_look = look
	_tier = tier
	_contrast = contrast
	var mesh_res: ArrayMesh = _copy_for(look)
	if _mm.mesh != mesh_res:
		_mm.mesh = mesh_res
	var roles: Array = _roles[LookActorsStyle.enabled(look)]
	for s: int in mesh_res.get_surface_count():
		var role: StringName = roles[s]
		var chosen: Material = MatLib.mat(role)
		if LookActorsStyle.enabled(look):
			chosen = LookActorsMat.surface(role, look, tier, true)
		if contrast:
			var variant: Material = ActorContrast.variant_for(role, look, tier, true)
			if variant != null:
				chosen = variant
		mesh_res.surface_set_material(s, chosen)


func begin_frame() -> void:
	_n = 0


## Draws one mini at the ground point (x, z), turned by `yaw`, hopping with `phase` (radians), popped by `pop` (0..POP_FRAMES
## frames left). False when the swarm is full (that mini is not drawn).
func add(x: float, z: float, yaw: float, phase: float, pop: int) -> bool:
	if _n >= capacity:
		return false
	var k: float = 1.0 + POP_SCALE * float(pop) / float(POP_FRAMES)
	var hop: float = absf(sin(phase)) * HOP_HEIGHT
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(k, k, k))
	var at: Vector3 = Vector3(x, hop, z)
	_mm.set_instance_transform(_n, Transform3D(basis, at))
	_origin[_n] = at
	_size[_n] = k
	_n += 1
	return true


func end_frame() -> void:
	_mm.visible_instance_count = _n


func clear() -> void:
	_n = 0
	_mm.visible_instance_count = 0


func drawn_count() -> int:
	return _n


## Where instance `i` was drawn last frame, and its scale (the pop).
func instance_origin(i: int) -> Vector3:
	return _origin[i]


func instance_scale(i: int) -> float:
	return _size[i]


func mesh() -> ArrayMesh:
	return _mm.mesh as ArrayMesh


func _copy_for(look: int) -> ArrayMesh:
	var styled: bool = LookActorsStyle.enabled(look)
	if not _copies.has(styled):
		var copy: ArrayMesh = ActorMeshes.mini_look(_id, look).duplicate() as ArrayMesh
		var roles: Array = []
		for s: int in copy.get_surface_count():
			roles.append(StringName(copy.surface_get_material(s).resource_name))
		_copies[styled] = copy
		_roles[styled] = roles
	return _copies[styled]
