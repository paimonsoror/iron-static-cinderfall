class_name WardenParts
extends RefCounted
## The mesh instances of the Warden and the look that dresses them (W3-C). Legs, torso and the two weapons exist in every
## look (the old meshes in CURRENT); the hard-surface looks add the arms, the pack, the antenna and the cable, which
## stay hidden in CURRENT. Switching a look swaps meshes and surface override materials on the same nodes (no node is
## created or freed), and the meshes and materials are shared caches, so switching never leaks.
## One MeshInstance3D per body part; the pivot of each extra part is its position in the Body frame.

## Extra parts: name, ActorMeshes part id, pivot in torso space.
const EXTRAS: Array = [
	["ArmRU", &"arm_ru", LookDevWarden.SHOULDER_R],
	["ArmRF", &"arm_rf", Vector3(0.43, 0.38, -0.12)],
	["ArmLU", &"arm_lu", LookDevWarden.SHOULDER_L],
	["ArmLF", &"arm_lf", Vector3(-0.43, 0.38, -0.12)],
	["Pack", &"pack", LookDevWarden.PACK_PIVOT],
	["Antenna", &"antenna", LookDevWarden.ANTENNA_PIVOT],
	["Cable", &"cable", LookDevWarden.CABLE_PIVOT],
]

var legs: MeshInstance3D
var torso: MeshInstance3D
var weapons: Array[MeshInstance3D] = []  ## pistol, smg (their Muzzle markers are children)
var extras: Array[MeshInstance3D] = []  ## in EXTRAS order
var look: int = LookDevStyle.Look.CURRENT
var tier: int = VisualQuality.Tier.HIGH


## Index in `extras` of a part by its ActorMeshes id (-1 when unknown).
static func index_of(part: StringName) -> int:
	for i: int in EXTRAS.size():
		if EXTRAS[i][1] == part:
			return i
	return -1


## Creates the extra part nodes under `body` (hidden) and remembers the always-present ones.
func attach(legs_node: MeshInstance3D, torso_node: MeshInstance3D, weapon_nodes: Array[MeshInstance3D], body: Node3D) -> void:
	legs = legs_node
	torso = torso_node
	weapons = weapon_nodes
	for spec: Array in EXTRAS:
		var node_name: String = spec[0]
		var pivot: Vector3 = spec[2]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = node_name
		mi.position = pivot
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		extras.append(mi)


## Dresses every part for `new_look` at quality `new_tier`: meshes, override materials, visibility of the extras.
func apply(new_look: int, new_tier: int) -> void:
	look = new_look
	tier = new_tier
	var styled: bool = LookDevStyle.styled_geometry(look)
	_dress(legs, &"legs")
	_dress(torso, &"torso")
	_dress(weapons[0], &"pistol")
	_dress(weapons[1], &"smg")
	for i: int in extras.size():
		var part: StringName = EXTRAS[i][1]
		extras[i].visible = styled
		if styled:
			_dress(extras[i], part)


## The shared emissive accent material of the current look (the visor, belt, lights), or null in CURRENT.
func accent_material() -> StandardMaterial3D:
	if look == LookDevStyle.Look.CURRENT:
		return null
	return LookDevMat.surface(&"emit_cyan", look, tier) as StandardMaterial3D


## Every part node that is drawn in the current look.
func visible_parts() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = [legs, torso, weapons[0], weapons[1]]
	for mi: MeshInstance3D in extras:
		if mi.visible:
			out.append(mi)
	return out


func _dress(mi: MeshInstance3D, part: StringName) -> void:
	var mesh: ArrayMesh = ActorMeshes.warden_part(part, look)
	mi.mesh = mesh
	for s: int in mesh.get_surface_count():
		if look == LookDevStyle.Look.CURRENT:
			mi.set_surface_override_material(s, null)
			continue
		var base: StringName = StringName(mesh.surface_get_material(s).resource_name)
		mi.set_surface_override_material(s, LookDevMat.surface(base, look, tier))
