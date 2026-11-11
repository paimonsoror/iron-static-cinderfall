class_name EnemyMeshes
extends RefCounted
## Procedural merged meshes of the four CHORUS machines (WORK_PLAN 6). Forward is -Z, feet at y = 0.
## Three surfaces each: gunmetal frame, bone-ceramic plates, one emissive red optic bar (GDD 2.4: a single
## optic, never a pair of eyes, never a skull). The optic wraps over the top of the head so it reads from above.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const R: StringName = &"emit_red"


## Low four-legged crawler, 0.9 m high: wedge body, splayed legs, long raised forelimbs, small head, red slit.
static func skitter() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.44, 0.2, 0.72), ActorPrims.at(Vector3(0.0, 0.4, 0.05)), G)
	mb.prism(Vector3(0.5, 0.2, 0.62), ActorPrims.at(Vector3(0.0, 0.6, 0.08)), C)
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.12, 0.3]:
			var hip: Vector3 = Vector3(side * 0.2, 0.42, z)
			var knee: Vector3 = Vector3(side * 0.46, 0.5, z + signf(z) * 0.08)
			var foot: Vector3 = Vector3(side * 0.62, 0.0, z + signf(z) * 0.22)
			ActorPrims.strut(mb, hip, knee, 0.07, G)
			ActorPrims.strut(mb, knee, foot, 0.06, G)
		var shoulder: Vector3 = Vector3(side * 0.16, 0.48, -0.26)
		var elbow: Vector3 = Vector3(side * 0.28, 0.88, -0.52)
		var claw: Vector3 = Vector3(side * 0.2, 0.42, -0.95)
		ActorPrims.strut(mb, shoulder, elbow, 0.07, G)
		ActorPrims.strut(mb, elbow, claw, 0.06, G)
		ActorPrims.blade(mb, claw + Vector3(0.0, 0.1, 0.1), claw + Vector3(0.0, -0.05, -0.1), 0.07, 0.12, C)
	mb.box(Vector3(0.26, 0.17, 0.24), ActorPrims.at(Vector3(0.0, 0.52, -0.48)), C)
	mb.box(Vector3(0.22, 0.06, 0.14), ActorPrims.at(Vector3(0.0, 0.62, -0.52)), R)
	mb.box(Vector3(0.24, 0.16, 0.3), ActorPrims.at(Vector3(0.0, 0.42, 0.46)), G)
	for k: int in 3:
		ActorPrims.blade(mb, Vector3(0.0, 0.68, -0.1 + 0.16 * float(k)), Vector3(0.0, 0.72, 0.0 + 0.16 * float(k)), 0.08, 0.1, C)
	return mb.build()


## Upright broad-shouldered biped, 1.7 m: slab chest plate, shoulder blocks, red visor bar.
static func hollow_warden() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	for side: float in [-1.0, 1.0]:
		mb.box(Vector3(0.22, 0.78, 0.24), ActorPrims.at(Vector3(side * 0.17, 0.43, 0.0)), G)
		mb.box(Vector3(0.28, 0.1, 0.44), ActorPrims.at(Vector3(side * 0.17, 0.05, -0.06)), G)
		mb.box(Vector3(0.3, 0.22, 0.34), ActorPrims.at(Vector3(side * 0.5, 1.46, 0.0)), C)
		mb.box(Vector3(0.16, 0.62, 0.16), ActorPrims.at(Vector3(side * 0.5, 1.0, 0.02)), G)
		mb.box(Vector3(0.22, 0.2, 0.22), ActorPrims.at(Vector3(side * 0.5, 0.6, -0.04)), C)
		mb.box(Vector3(0.24, 0.16, 0.1), ActorPrims.at(Vector3(side * 0.17, 0.46, -0.16)), C)
		mb.box(Vector3(0.2, 0.3, 0.2), ActorPrims.at(Vector3(side * 0.5, 0.9, 0.02)), C)
	mb.box(Vector3(0.58, 0.2, 0.32), ActorPrims.at(Vector3(0.0, 0.9, 0.0)), G)
	mb.box(Vector3(0.62, 0.56, 0.34), ActorPrims.at(Vector3(0.0, 1.2, 0.0)), G)
	mb.box(Vector3(0.66, 0.44, 0.1), ActorPrims.at(Vector3(0.0, 1.24, -0.2)), C)
	mb.box(Vector3(0.5, 0.4, 0.12), ActorPrims.at(Vector3(0.0, 1.24, 0.22)), C)
	mb.box(Vector3(0.2, 0.12, 0.2), ActorPrims.at(Vector3(0.0, 1.45, 0.0)), G)
	mb.box(Vector3(0.62, 0.06, 0.36), ActorPrims.at(Vector3(0.0, 1.0, 0.0)), C)
	mb.box(Vector3(0.28, 0.24, 0.28), ActorPrims.at(Vector3(0.0, 1.57, -0.02)), C)
	mb.box(Vector3(0.3, 0.06, 0.16), ActorPrims.at(Vector3(0.0, 1.69, -0.08)), R)
	return mb.build()


## Lean biped, 1.4 m, torso pitched forward 25 degrees: swept-back spines with a red ridge, spark trail.
static func rusher() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var hip: Vector3 = Vector3(0.0, 0.66, 0.1)
	var frame: Transform3D = ActorPrims.pitch_frame(-25.0, hip)
	for side: float in [-1.0, 1.0]:
		var top: Vector3 = Vector3(side * 0.14, 0.66, 0.1)
		var knee: Vector3 = Vector3(side * 0.16, 0.38, 0.3)
		var foot: Vector3 = Vector3(side * 0.16, 0.0, 0.08)
		ActorPrims.strut(mb, top, knee, 0.1, G)
		ActorPrims.strut(mb, knee, foot, 0.09, G)
		mb.box(Vector3(0.14, 0.06, 0.26), ActorPrims.at(Vector3(side * 0.16, 0.03, 0.0)), G)
		mb.box(Vector3(0.12, 0.22, 0.08), ActorPrims.at(Vector3(side * 0.16, 0.2, 0.2)), C)
		var shoulder: Vector3 = Vector3(side * 0.28, 0.46, 0.0)
		ActorPrims.box_in(mb, Vector3(0.18, 0.16, 0.2), shoulder, C, frame)
		ActorPrims.strut(mb, shoulder, Vector3(side * 0.3, 0.1, -0.28), 0.08, G, frame)
		ActorPrims.strut(mb, Vector3(side * 0.3, 0.1, -0.28), Vector3(side * 0.22, -0.18, -0.4), 0.07, G, frame)
		ActorPrims.blade(mb, Vector3(side * 0.22, -0.18, -0.4), Vector3(side * 0.2, -0.22, -0.7), 0.07, 0.12, C, frame)
	mb.box(Vector3(0.34, 0.18, 0.26), ActorPrims.at(hip), G)
	ActorPrims.box_in(mb, Vector3(0.36, 0.5, 0.26), Vector3(0.0, 0.3, 0.0), G, frame)
	ActorPrims.box_in(mb, Vector3(0.38, 0.32, 0.08), Vector3(0.0, 0.36, -0.16), C, frame)
	ActorPrims.box_in(mb, Vector3(0.2, 0.18, 0.22), Vector3(0.0, 0.62, -0.1), C, frame)
	ActorPrims.box_in(mb, Vector3(0.24, 0.06, 0.12), Vector3(0.0, 0.72, -0.14), R, frame)
	for k: int in 3:
		var y: float = 0.2 + 0.18 * float(k)
		ActorPrims.blade(mb, Vector3(0.0, y, 0.12), Vector3(0.0, y + 0.1, 0.46), 0.14, 0.2, G, frame)
	ActorPrims.strut(mb, Vector3(0.0, 0.62, 0.18), Vector3(0.0, 0.2, 0.5), 0.05, R, frame)
	mb.quad(Vector2(0.1, 0.45), ActorPrims.at(Vector3(0.0, 0.04, 0.72)), R)
	mb.quad(Vector2(0.06, 0.25), ActorPrims.at(Vector3(0.0, 0.04, 1.14)), R)
	return mb.build()


## Hunched 3.4 m brute: huge shoulder blocks, pillar forearms, red chest core, cables.
static func siege_hulk() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var frame: Transform3D = ActorPrims.pitch_frame(-18.0, Vector3(0.0, 1.6, 0.3))
	for side: float in [-1.0, 1.0]:
		# rear legs and hip plates stand in the world frame; the upper body is pitched forward
		mb.box(Vector3(0.8, 1.3, 0.9), ActorPrims.at(Vector3(side * 0.85, 0.65, 0.6)), G)
		mb.box(Vector3(1.0, 0.24, 1.3), ActorPrims.at(Vector3(side * 0.85, 0.12, 0.5)), G)
		mb.box(Vector3(0.7, 0.4, 0.5), ActorPrims.at(Vector3(side * 0.85, 1.05, 0.25)), C)
		ActorPrims.box_in(mb, Vector3(1.1, 0.95, 1.3), Vector3(side * 1.3, 1.05, -0.1), C, frame)
		ActorPrims.blade(mb, Vector3(side * 1.35, 1.45, -0.5), Vector3(side * 1.35, 1.5, 0.5), 0.5, 0.4, C, frame)
		ActorPrims.strut(mb, Vector3(side * 1.45, 0.7, -0.1), Vector3(side * 1.5, -0.7, -1.0), 0.72, G, frame)
		ActorPrims.box_in(mb, Vector3(0.95, 0.55, 0.95), Vector3(side * 1.5, -0.85, -1.05), C, frame)
		ActorPrims.box_in(mb, Vector3(0.6, 0.4, 0.5), Vector3(side * 1.1, 0.35, -1.25), G, frame)
		ActorPrims.box_in(mb, Vector3(0.12, 0.7, 1.0), Vector3(side * 1.9, 1.05, -0.1), G, frame)
		ActorPrims.cable(mb, Vector3(side * 0.55, 1.3, 0.65), Vector3(side * 0.7, 1.62, 1.0), 0.12, 6, G, frame)
	ActorPrims.box_in(mb, Vector3(1.9, 1.3, 1.7), Vector3(0.0, 0.6, 0.0), G, frame)
	ActorPrims.box_in(mb, Vector3(1.5, 0.45, 1.2), Vector3(0.0, 1.3, 0.15), C, frame)
	ActorPrims.box_in(mb, Vector3(1.2, 0.7, 0.2), Vector3(0.0, 0.5, -0.9), C, frame)
	ActorPrims.box_in(mb, Vector3(0.6, 0.45, 0.55), Vector3(0.0, 1.45, -0.6), C, frame)
	ActorPrims.box_in(mb, Vector3(0.5, 0.08, 0.3), Vector3(0.0, 1.7, -0.75), R, frame)
	mb.sphere(0.36, 8, frame * ActorPrims.at(Vector3(0.0, 1.0, -0.95)), R)
	ActorPrims.box_in(mb, Vector3(0.5, 0.18, 0.3), Vector3(0.0, 1.22, -0.92), G, frame)
	for k: int in 3:
		var sx: float = -0.5 + 0.5 * float(k)
		ActorPrims.blade(mb, Vector3(sx, 1.4, 0.0), Vector3(sx, 1.46, 0.6), 0.3, 0.3, C, frame)
	for cx: float in [-0.5, 0.5]:
		ActorPrims.cable(mb, Vector3(cx, 1.6, 0.7), Vector3(cx * 2.0, 1.7, -0.3), 0.09, 6, G, frame)
		ActorPrims.cable(mb, Vector3(cx * 2.0, 1.7, -0.3), Vector3(cx * 2.4, 1.1, -0.7), 0.09, 6, G, frame)
	return mb.build()
