class_name OverlayMeshes
extends RefCounted
## Meshes and materials of the battle debug overlay (flow arrows, attack slots, stuck enemies, spawn regions). Flat,
## unshaded and slightly transparent so the yard stays readable under them. Debug colors are deliberately outside the
## game palette (they must never be mistaken for a gameplay cue): cyan flow, green/red slots, magenta stuck, orange spawns.

const FLOW_COLOR: Color = Color(0.45, 0.9, 1.0, 0.8)
const SLOT_FREE_COLOR: Color = Color(0.4, 1.0, 0.5, 0.85)
const SLOT_TAKEN_COLOR: Color = Color(1.0, 0.25, 0.2, 0.7)
const STUCK_COLOR: Color = Color(1.0, 0.2, 0.9, 0.9)
const SPAWN_COLOR: Color = Color(1.0, 0.55, 0.1, 0.35)
const Y_OVERLAY: float = 0.09


static func flat_material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	return m


## An arrow of `length` meters lying on the ground and pointing along +X (shaft plus a two-bar head).
static func arrow(length: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var shaft: float = length * 0.78
	mb.box(Vector3(shaft, 0.02, 0.07), Transform3D(Basis.IDENTITY, Vector3(-length * 0.5 + shaft * 0.5, 0.0, 0.0)), &"emit_cyan")
	var tip: Vector3 = Vector3(length * 0.5, 0.0, 0.0)
	var bar: float = length * 0.34
	for sign_z: float in [-1.0, 1.0]:
		var turn: Basis = Basis(Vector3.UP, sign_z * deg_to_rad(150.0))
		mb.box(Vector3(bar, 0.02, 0.07), Transform3D(turn, tip + turn * Vector3(bar * 0.5, 0.0, 0.0)), &"emit_cyan")
	return mb.build()


## A flat ring (or a filled disc when `r_in` is 0) in the XZ plane.
static func ring(r_in: float, r_out: float) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	if r_in <= 0.0:
		mb.disc(r_out, 20, Transform3D.IDENTITY, &"emit_cyan")
	else:
		mb.ring(r_in, r_out, 28, Transform3D.IDENTITY, &"emit_cyan")
	return mb.build()


## A MultiMesh of `capacity` transform-only instances of `mesh`, none visible yet.
static func multimesh(mesh: Mesh, capacity: int) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	return mm


## One band per spawn region (a line segment in the data), 1.4 m thick, with a post at each end.
static func spawn_regions(regions: Array[SpawnRegionDef]) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	for r: SpawnRegionDef in regions:
		var mid: Vector3 = Vector3((r.x0 + r.x1) * 0.5, Y_OVERLAY, (r.z0 + r.z1) * 0.5)
		var span: Vector2 = Vector2(absf(r.x1 - r.x0), absf(r.z1 - r.z0))
		mb.quad(Vector2(span.x + 1.4, span.y + 1.4), Transform3D(Basis.IDENTITY, mid), &"emit_amber")
		for end: Vector2 in [Vector2(r.x0, r.z0), Vector2(r.x1, r.z1)]:
			mb.box(Vector3(0.3, 1.2, 0.3), Transform3D(Basis.IDENTITY, Vector3(end.x, 0.6, end.y)), &"emit_amber")
	return mb.build()
