class_name VfxAuras
extends Node3D
## The two persistent effects: the cyan shield dome (with a base ring) over the core and the amber overdrive glow under
## the Warden. Fixed meshes with their own copy of an additive MatLib material each; brightness is the alpha of that
## one material (the Mobile renderer ignores per-instance `transparency`). Reduced Flash dims both and stops the
## shimmer (GDD 10.3).

const DOME_SEGMENTS: int = 14
const GLOW_Y: float = 0.07

var _dome: MeshInstance3D
var _ring: MeshInstance3D
var _glow: MeshInstance3D
var _dome_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _base_alpha: float = 0.6
var _core: Vector3 = Vector3.ZERO
var _dome_radius: float = 2.6
var _reduced: bool = false
var _low: bool = false
var _t: float = 0.0
var _hit: float = 0.0
var _opacity: float = 0.0  ## last dome opacity 0..1 (tests)
var _shield: float = 0.0
var _overdrive: bool = false


func setup(arena: ArenaDef) -> void:
	name = "VfxAuras"
	_core = Vector3(arena.core_x, 0.0, arena.core_z)
	_dome_radius = arena.core_radius * 1.3
	_base_alpha = MatLib.mat(&"add_cyan").albedo_color.a
	_dome_mat = _own(&"add_cyan")
	_ring_mat = _own(&"add_cyan")
	_glow_mat = _own(&"add_amber")
	_dome = _mesh_node("ShieldDome", VfxMeshes.dome(&"add_cyan", DOME_SEGMENTS), _dome_mat)
	_dome.position = _core
	_dome.scale = Vector3(_dome_radius, _dome_radius * 1.45, _dome_radius)
	_ring = _mesh_node("ShieldRing", VfxMeshes.ring(0.82, 28, &"add_cyan", &"add_white"), _ring_mat)
	_ring.position = _core + Vector3(0.0, GLOW_Y, 0.0)
	_ring.scale = Vector3(_dome_radius, 1.0, _dome_radius)
	_glow = _mesh_node("OverdriveGlow", VfxMeshes.disc(1.0, 20, &"add_amber"), _glow_mat)
	_glow.scale = Vector3(1.7, 1.0, 1.7)
	for n: MeshInstance3D in [_dome, _ring, _glow]:
		n.visible = false
		add_child(n)


## `shield_fraction` 0..1 (0 hides the dome), `overdrive_on`, and the Warden's ground position for the glow.
func update(delta: float, shield_fraction: float, overdrive_on: bool, warden_pos: Vector3) -> void:
	_t += delta
	_hit = maxf(0.0, _hit - delta * 4.0)
	_shield = clampf(shield_fraction, 0.0, 1.0)
	_overdrive = overdrive_on
	var shimmer: float = 0.0 if _reduced else 0.5 + 0.5 * sin(_t * 5.0)
	_dome.visible = _shield > 0.0
	_ring.visible = _dome.visible
	if _dome.visible:
		var base: float = 0.14 if _reduced else 0.26
		_opacity = clampf(base + 0.12 * shimmer + 0.1 * _shield + (0.0 if _reduced else 0.3 * _hit), 0.05, 0.7)
		_dome_mat.albedo_color.a = _base_alpha * _opacity
		_ring_mat.albedo_color.a = _base_alpha * clampf(_opacity + 0.25, 0.1, 0.9)
		var wobble: float = 1.0 + (0.0 if _low or _reduced else 0.012 * sin(_t * 3.0))
		_dome.scale = Vector3(_dome_radius, _dome_radius * 1.45, _dome_radius) * wobble
	_glow.visible = _overdrive
	if _glow.visible:
		_glow.position = Vector3(warden_pos.x, GLOW_Y, warden_pos.z)
		var beat: float = 0.0 if _reduced else 0.5 + 0.5 * sin(_t * 9.0)
		var glow_opacity: float = (0.25 if _reduced else 0.6) - 0.12 * beat
		_glow_mat.albedo_color.a = _base_alpha * clampf(glow_opacity, 0.05, 0.7)
		var s: float = 1.7 * (1.0 + 0.08 * beat)
		_glow.scale = Vector3(s, 1.0, s)


## A shield hit: the dome flares briefly.
func pulse() -> void:
	_hit = 1.0


func set_reduced(on: bool) -> void:
	_reduced = on


func set_quality(tier: int) -> void:
	_low = tier == VisualQuality.Tier.LOW


func dome_visible() -> bool:
	return _dome.visible


func glow_visible() -> bool:
	return _glow.visible


## Opacity (0..1) the dome was last drawn with.
func dome_opacity() -> float:
	return _opacity


func hit_amount() -> float:
	return _hit


func clear() -> void:
	_hit = 0.0
	_dome.visible = false
	_ring.visible = false
	_glow.visible = false


## A private copy of a MatLib material, so one effect can fade without touching the shared one.
func _own(mat_id: StringName) -> StandardMaterial3D:
	return MatLib.mat(mat_id).duplicate() as StandardMaterial3D


func _mesh_node(node_name: String, mesh_res: ArrayMesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh_res
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
