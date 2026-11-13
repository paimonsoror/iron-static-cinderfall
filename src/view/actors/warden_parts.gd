class_name WardenParts
extends RefCounted
## The mesh instances of the Warden and the look that dresses them (W3-C). Legs, torso and the two weapons exist in every
## look (the old meshes in CURRENT); the hard-surface looks add the arms, the pack, the antenna and the cable, which
## stay hidden in CURRENT. Switching a look swaps meshes and surface override materials on the same nodes (no node is
## created or freed), and the meshes and materials are shared caches, so switching never leaks.
## One MeshInstance3D per body part; the pivot of each extra part is its position in the Body frame.

## Where the holstered weapon's grip sits in pack space and the length it is scaled to.
const HOLSTER_AT: Vector3 = Vector3(0.34, 0.02, 0.2)
const HOLSTER_LENGTH: float = 0.62

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
var weapons: Array[MeshInstance3D] = []  ## the three mounts: pistol, smg and the third (`ActorMeshes.WARDEN_WEAPON_NODES`; their Muzzle markers are children)
var holster: MeshInstance3D  ## the other slot's weapon on the pack: a sibling of the Warden (made by `attach_holster`), MID and HIGH, hard-surface looks only
var holster_local: Transform3D = Transform3D.IDENTITY  ## where the holster sits on the pack part, in the pack part's frame
var extras: Array[MeshInstance3D] = []  ## in EXTRAS order
var look: int = LookDevStyle.Look.CURRENT
var tier: int = VisualQuality.Tier.HIGH

var _mount_weapon: PackedInt32Array = PackedInt32Array([Ids.WP_PISTOL, Ids.WP_SMG, Ids.WP_ARC_PROJECTOR])  ## the weapon each mount shows
var _holster_weapon: int = -1


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
	for w: int in weapons.size():
		_dress(weapons[w], Ids.WEAPONS[_mount_weapon[w]])
	for i: int in extras.size():
		var part: StringName = EXTRAS[i][1]
		extras[i].visible = styled
		if styled:
			_dress(extras[i], part)
	_dress_holster()


## Mount `mount` now shows weapon `weapon` (`Ids.WP_*`). Only the third mount changes: the pistol and the SMG keep their own.
func set_mount_weapon(mount: int, weapon: int) -> void:
	if mount != WeaponMeshes.THIRD_MOUNT or mount >= weapons.size() or _mount_weapon[mount] == weapon:
		return
	_mount_weapon[mount] = weapon
	_dress(weapons[mount], Ids.WEAPONS[weapon])


## Makes the holster node as a child of `parent` (once; the Warden's own subtree stays the pinned set of mesh instances).
func attach_holster(parent: Node) -> void:
	if holster != null and is_instance_valid(holster):
		return
	holster = MeshInstance3D.new()
	holster.name = "WardenHolster"
	holster.visible = false
	holster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holster)
	_dress_holster()


## Which weapon (`Ids.WP_*`) rides on the pack.
func set_holster(weapon: int) -> void:
	_holster_weapon = weapon
	_dress_holster()


func hide_holster() -> void:
	if holster != null and is_instance_valid(holster):
		holster.visible = false


func free_holster() -> void:
	if holster != null and is_instance_valid(holster) and not holster.is_queued_for_deletion():
		holster.queue_free()
	holster = null


## Puts the holster on the pack part for this frame (the pack springs and breathes, the weapon rides with it).
func sync_holster() -> void:
	if holster == null or not holster.visible or not holster.is_inside_tree() or extras.is_empty():
		return
	var pack: MeshInstance3D = extras[index_of(&"pack")]
	holster.global_transform = pack.global_transform * holster_local


## True when the holster is drawn: a hard-surface look (it has a pack) at MID or HIGH.
static func holster_shown(look_value: int, tier_value: int) -> bool:
	return LookDevStyle.styled_geometry(look_value) and tier_value >= VisualQuality.Tier.MID


## Where a weapon of mesh `m` rides in pack space: its barrel up, out and back along the pack's right flank, scaled so that a long
## weapon is not longer than the pack is tall (0.5 to 0.9 of its size).
static func holster_transform(m: ArrayMesh) -> Transform3D:
	var length: float = maxf(m.get_aabb().size.z, 0.1)
	var s: float = clampf(HOLSTER_LENGTH / length, 0.5, 0.9)
	var dir: Vector3 = Vector3(0.22, 0.82, 0.52).normalized()
	var basis: Basis = Basis.looking_at(dir, Vector3.RIGHT).scaled(Vector3(s, s, s))
	return Transform3D(basis, HOLSTER_AT)


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


func _dress_holster() -> void:
	if holster == null or not is_instance_valid(holster):
		return
	var shown: bool = holster_shown(look, tier) and _holster_weapon >= 0 and _holster_weapon < Ids.WEAPONS.size()
	holster.visible = shown
	if not shown:
		return
	_dress(holster, Ids.WEAPONS[_holster_weapon])
	holster_local = holster_transform(holster.mesh as ArrayMesh)


func _dress(mi: MeshInstance3D, part: StringName) -> void:
	var mesh: ArrayMesh = ActorMeshes.warden_part(part, look)
	mi.mesh = mesh
	for s: int in mesh.get_surface_count():
		if look == LookDevStyle.Look.CURRENT:
			mi.set_surface_override_material(s, null)
			continue
		var base: StringName = StringName(mesh.surface_get_material(s).resource_name)
		mi.set_surface_override_material(s, LookDevMat.surface(base, look, tier))
