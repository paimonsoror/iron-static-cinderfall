class_name EnemyMeshes2
extends RefCounted
## The CURRENT look of the variety enemies (V2-F): plain box and prism meshes in the flat palette, like `EnemyMeshes`, for
## `--look=current` (the hard-surface versions are `LookActorsBurster` and `LookActorsMote`). Three surfaces at most, one red
## optic each, forward is -Z, feet at y = 0. The old four machines are not touched by this file.

const G: StringName = &"gunmetal"
const C: StringName = &"ceramic"
const H: StringName = &"hazard"
const R: StringName = &"emit_red"


## Biped, 1.5 m: a boxy torso, a hazard-coloured tank and shoulders (amber, so the flat look needs no stripes), a small head forward of
## the torso with a red slab on top. Gunmetal, hazard, emit_red: three surfaces.
static func burster() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	for side: float in [-1.0, 1.0]:
		mb.box(Vector3(0.2, 0.7, 0.22), ActorPrims.at(Vector3(side * 0.16, 0.35, 0.0)), G)
		mb.box(Vector3(0.24, 0.1, 0.4), ActorPrims.at(Vector3(side * 0.16, 0.05, -0.08)), G)
		mb.box(Vector3(0.22, 0.2, 0.3), ActorPrims.at(Vector3(side * 0.34, 1.12, -0.04)), H)
	mb.box(Vector3(0.5, 0.5, 0.34), ActorPrims.at(Vector3(0.0, 0.95, -0.02)), G)
	mb.cylinder(0.34, 0.34, 0.8, 10, ActorPrims.at(Vector3(0.0, 1.04, 0.3)), H)
	mb.cylinder(0.3, 0.3, 0.12, 10, ActorPrims.at(Vector3(0.0, 1.5, 0.3)), G)
	mb.box(Vector3(0.26, 0.24, 0.26), ActorPrims.at(Vector3(0.0, 1.12, -0.36)), H)
	mb.box(Vector3(0.32, 0.08, 0.26), ActorPrims.at(Vector3(0.0, 1.28, -0.36)), R)  # on top of the head: it reads from above whichever way it faces
	return mb.build()


## Hand-sized tripod, 0.4 m: a pale cap on three thin legs with a red slab on top.
static func mote() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.box(Vector3(0.3, 0.16, 0.32), ActorPrims.at(Vector3(0.0, 0.28, 0.0)), C)
	for k: int in 3:
		var a: float = PI * 1.5 + TAU * float(k) / 3.0
		ActorPrims.blade(mb, Vector3(cos(a) * 0.08, 0.2, sin(a) * 0.08), Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2), 0.05, 0.05, G)
	mb.quad(Vector2(0.24, 0.2), ActorPrims.at(Vector3(0.0, 0.365, -0.02)), R)  # on top of the cap
	return mb.build()
