class_name ShaderWarmup
extends MeshInstance3D
## Draws every material variant once so the first shot of a run does not hitch while the GPU compiles pipelines
## (ARCH 8). One tiny quad per material, nearly invisible (alpha 0.02) for 2 frames, then the node frees itself.
## Attach it where the camera sees it, during the boot screen. `extra` adds materials outside MatLib (the ground
## shader). A single MeshInstance3D, so it costs one node.

const ALPHA: float = 0.02
const FRAMES: int = 2
const QUAD: float = 0.05
const SPACING: float = 0.08

var frames_left: int = FRAMES


## Creates the warm-up node under `parent` at world point `at` and returns it.
static func attach(parent: Node3D, at: Vector3, extra: Array[Material] = []) -> ShaderWarmup:
	var w: ShaderWarmup = ShaderWarmup.new()
	w.name = "ShaderWarmup"
	w.mesh = build_mesh(extra)
	w.transparency = 1.0 - ALPHA
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(w)
	w.position = at
	return w


## One surface per MatLib id, then one per extra material, laid out in a row along X.
static func build_mesh(extra: Array[Material]) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var total: int = MatLib.IDS.size() + extra.size()
	var x0: float = -SPACING * float(total - 1) * 0.5
	for i: int in MatLib.IDS.size():
		var at: Vector3 = Vector3(x0 + SPACING * float(i), 0.0, 0.0)
		mb.quad(Vector2(QUAD, QUAD), Transform3D(Basis.IDENTITY, at), MatLib.IDS[i])
	var mesh: ArrayMesh = mb.build()
	for j: int in extra.size():
		var cx: float = x0 + SPACING * float(MatLib.IDS.size() + j)
		_add_quad_surface(mesh, extra[j], cx)
	return mesh


## Number of distinct materials the warm-up covers (tests).
static func material_count(mesh: ArrayMesh) -> int:
	return mesh.get_surface_count()


func _process(_delta: float) -> void:
	frames_left -= 1
	if frames_left <= 0:
		queue_free()


static func _add_quad_surface(mesh: ArrayMesh, mat: Material, cx: float) -> void:
	var h: float = QUAD * 0.5
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(cx - h, 0.0, -h), Vector3(cx + h, 0.0, -h), Vector3(cx + h, 0.0, h), Vector3(cx - h, 0.0, h)
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
