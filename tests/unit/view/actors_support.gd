class_name ActorsTestKit
extends RefCounted
## Shared builders for the actors_* and vfx_* suites. Not a suite itself.


## A fresh sim world on the frozen baseline content.
static func world() -> SimWorld:
	return TestContent.world(1)


## An ActorLayer set up on the world's content and added under `host`.
static func actor_layer(host: Node, w: SimWorld) -> ActorLayer:
	MatLib.configure(w.content.tokens)
	var layer: ActorLayer = ActorLayer.new()
	host.add_child(layer)
	layer.setup(w.content)
	return layer


## A CameraRig plus a VfxLayer wired to `layer`, both under `host`.
static func vfx_layer(host: Node, w: SimWorld, layer: ActorLayer) -> VfxLayer:
	var rig: CameraRig = CameraRig.new()
	host.add_child(rig)
	rig.setup(w.content.arena, w.content.tokens)
	var vfx: VfxLayer = VfxLayer.new()
	host.add_child(vfx)
	vfx.setup(w.content, rig, layer)
	return vfx


## Spawns `count` enemies in the store: 60 percent skitters, then hollow wardens, rushers and one hulk.
static func spawn_mixed(w: SimWorld, count: int) -> void:
	for n: int in count:
		var kind: int = Ids.EN_SKITTER
		if n == 0:
			kind = Ids.EN_HULK
		elif n % 5 == 1:
			kind = Ids.EN_HOLLOW
		elif n % 5 == 2:
			kind = Ids.EN_RUSHER
		var i: int = w.spawn_enemy(kind, 2.0 + float(n % 10), -6.0 + float(floori(float(n) / 10.0)) * 2.0)
		assert(i >= 0)


static func count_nodes(root: Node) -> int:
	var n: int = 1
	for c: Node in root.get_children():
		n += count_nodes(c)
	return n


## Visible pooled enemy roots of the layer (a root has exactly one child, a MeshInstance3D).
static func visible_enemy_roots(layer: ActorLayer) -> int:
	var n: int = 0
	for c: Node in layer.get_children():
		var r: Node3D = c as Node3D
		if r != null and r.visible and r.get_child_count() == 1 and r.get_child(0) is MeshInstance3D:
			n += 1
	return n


static func id_at(w: SimWorld, index: int) -> int:
	return w.enemies.id[index]
