class_name EnvReactor
extends RefCounted
## Detail for Relay Core B-4 in the gritty yard (W3-E): lit ring bands on the cage, a ring of base lights, lit slits and plated greebles
## on the cage ribs, cable bundles and a crown of lamps. It is a second mesh on the CoreRig (nominal radius 2 m, the rig scales it) that
## sits ON the existing body without changing it: nothing moves, the core's footprint and its label are untouched, CURRENT never
## builds it.

const PAINT: StringName = EnvShapes.PAINT
const AMBER: StringName = EnvShapes.AMBER


static func mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.tint = Color.WHITE
	for y: float in [1.55, 2.9, 4.25]:
		mb.ring(1.36, 1.52, 32, Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), AMBER)
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		mb.box(Vector3(0.36, 0.05, 0.12), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 1.95, 0.47, sin(a) * 1.95)), AMBER)
	for deg: float in [50.0, 75.0, 105.0, 130.0, 160.0]:
		var b: float = deg_to_rad(deg)
		mb.box(Vector3(0.1, 0.26, 0.05), Transform3D(Basis(Vector3.UP, -b), Vector3(cos(b) * 2.16, 0.25, sin(b) * 2.16)), AMBER)
	for i: int in 8:
		var c: float = TAU * float(i) / 8.0 + PI / 8.0
		mb.box(Vector3(0.14, 0.06, 0.14), Transform3D(Basis(Vector3.UP, -c), Vector3(cos(c) * 1.3, 5.3, sin(c) * 1.3)), AMBER)
	var plate: Color = EnvShapes.paint(&"dark_frame", 0.6)
	var steel: Color = EnvShapes.paint(&"gunmetal", 0.6)
	for i: int in 8:
		var d: float = TAU * float(i) / 8.0 + PI / 8.0
		for y2: float in [1.15, 2.2, 3.55, 4.7]:
			mb.tint = plate if i % 2 == 0 else steel
			var at: Transform3D = Transform3D(Basis(Vector3.UP, -d), Vector3(cos(d) * 1.4, y2, sin(d) * 1.4))
			LookDevShapes.bevel_box(mb, Vector3(0.1, 0.42, 0.3), at, PAINT, 0.02)
	mb.tint = EnvShapes.paint(&"rubber", 0.9)
	for k: int in 3:
		var e: float = deg_to_rad(70.0 + 25.0 * float(k))
		mb.cylinder(0.05, 0.05, 4.2, 6, Transform3D(Basis.IDENTITY, Vector3(cos(e) * 1.62, 2.8, sin(e) * 1.62)), PAINT)
	return EnvShapes.finish(mb)
