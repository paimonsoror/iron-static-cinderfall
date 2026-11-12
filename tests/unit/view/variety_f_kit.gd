class_name VarietyFKit
extends RefCounted
## Builders and small readers of the V2-F suites (`actors_variety_*`, `vfx_variety_*`). Not a suite itself.

const BOUNDS: AABB = AABB(Vector3(-50.0, -5.0, -50.0), Vector3(100.0, 40.0, 100.0))


## A SimWorld on the frozen variety content.
static func world(run_seed: int = 1) -> SimWorld:
	return TestContent.variety_world(run_seed)


## An ActorLayer set up on the world's content under `host`, bound to the world.
static func bound_layer(host: GdUnitTestSuite, w: SimWorld) -> ActorLayer:
	var layer: ActorLayer = ActorsTestKit.actor_layer(host, w)
	host.auto_free(layer)
	layer.bind(w)
	return layer


## A bound ActorLayer plus a VfxLayer wired to it: [world, layer, vfx].
static func rig(host: GdUnitTestSuite) -> Array:
	var w: SimWorld = world()
	var layer: ActorLayer = bound_layer(host, w)
	var vfx: VfxLayer = ActorsTestKit.vfx_layer(host, w, layer)
	host.auto_free(vfx)
	vfx.bind(w)
	layer.render(1.0, 0.016)
	vfx.render(1.0, 0.016)
	return [w, layer, vfx]


## Spawns `count` bodies of `type_index` on a grid at x 0..9, z from `z0`; returns the store ids.
static func spawn(w: SimWorld, type_index: int, count: int, z0: float = -6.0) -> Array[int]:
	var ids: Array[int] = []
	for n: int in count:
		var i: int = w.spawn_enemy(type_index, float(n % 10) * 0.8, z0 + float(floori(float(n) / 10.0)) * 0.8)
		assert(i >= 0)
		ids.append(w.enemies.id[i])
	return ids


## Roles (palette material ids) of the surfaces of a mesh, in surface order.
static func roles(mesh: ArrayMesh) -> Array[StringName]:
	return LookActorsTestKit.roles(mesh)


## Surfaces of `mesh` whose role is `role`.
static func surfaces_with(mesh: ArrayMesh, role: StringName) -> int:
	var n: int = 0
	for r: StringName in roles(mesh):
		if r == role:
			n += 1
	return n


## Ages the layer by `seconds` in 0.1 s frames (the first draw of an effect does not age it).
static func age(vfx: VfxLayer, seconds: float) -> void:
	vfx.render(1.0, 0.0)
	var left: float = seconds
	while left > 0.0:
		vfx.render(1.0, 0.1)
		left -= 0.1


## Live objects in the engine (a counter test: nothing may be allocated in a steady state).
static func objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


## A bare VfxPool of `cap` slots under `host`.
static func pool(host: GdUnitTestSuite, cap: int, mode: int) -> VfxPool:
	var parent: Node3D = Node3D.new()
	host.add_child(parent)
	host.auto_free(parent)
	var p: VfxPool = VfxPool.new()
	p.setup(parent, "VarietyFPool", VfxMeshes.streak(&"add_amber"), cap, mode, BOUNDS)
	return p
