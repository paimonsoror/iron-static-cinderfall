class_name VfxXTestKit
extends RefCounted
## Builders of the V4-X suites (`vfx_tiers`, `vfx_zones`, `vfx_event_decals`, `vfx_air`, `vfx_cosmetic`, `arena_yard`). Not a suite itself.

const TIERS: Array[int] = [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]


## The world, the actor layer and the vfx layer of a rig, typed (an untyped Array of them would make every call unsafe).
class Rig:
	extends RefCounted
	var world: SimWorld
	var layer: ActorLayer
	var vfx: VfxLayer


## A rig on the variety fixture, bound and rendered once (a thin wrapper of the V2-F kit).
static func rig(host: GdUnitTestSuite) -> Rig:
	var parts: Array = VarietyFKit.rig(host)
	var r: Rig = Rig.new()
	r.world = parts[0]
	r.layer = parts[1]
	r.vfx = parts[2]
	return r


static func chaos(vfx: VfxLayer) -> FxChaos:
	return vfx.chaos()


## One enemy of `type_index` at (x, z) with `hp_fraction` of its health; returns the store index.
static func enemy(w: SimWorld, type_index: int, x: float, z: float, hp_fraction: float = 1.0) -> int:
	var i: int = w.spawn_enemy(type_index, x, z)
	assert(i >= 0)
	w.enemies.hp[i] = w.enemies.max_hp[i] * hp_fraction
	return i


## Ages the layer by `seconds` in 0.1 s frames (the first draw of an effect does not age it).
static func age(vfx: VfxLayer, seconds: float) -> void:
	VarietyFKit.age(vfx, seconds)


## The affix bit of `affix_id` in the content (-1 when unknown).
static func affix_bit(content: ContentSet, affix_id: StringName) -> int:
	for a: AffixDef in content.affixes:
		if a.id == affix_id:
			return a.index
	return -1


## Triangles of a node's mesh (MeshInstance3D) or of the mesh of a MultiMeshInstance3D.
static func triangles_of(node: Node) -> int:
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		return VfxMeshes.triangles(mi.mesh)
	var mm: MultiMeshInstance3D = node as MultiMeshInstance3D
	return VfxMeshes.triangles(mm.multimesh.mesh) if mm != null else 0
