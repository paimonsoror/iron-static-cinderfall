class_name EnvLight
extends RefCounted
## The light spill of the gritty yard (W3-E): additive camera-facing halos (no real lights beyond ARCH's four omnis) on the reactor, the
## lamp heads and the occupied turret pads, and the dark screen-edge vignette. Built once, shown by (look, tier) through EnvStyle. Every
## halo is a merged quad mesh with ONE shared additive material, so the whole spill is 3 to 4 draw calls; the lamp and reactor halos follow
## the flicker of the lights they belong to (only a material alpha changes per frame).

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform float strength = 0.6;
uniform float inner = 0.55;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.82);
	float v = smoothstep(inner, 1.0, length(p) * 1.9);
	COLOR = vec4(0.0, 0.012, 0.02, v * strength);
}
"""

var _root: Node3D
var _reactor: MeshInstance3D
var _lamps: MeshInstance3D
var _pads: Array[MeshInstance3D] = []
var _vignette: CanvasLayer
var _reactor_mat: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _reactor_peak: float = 0.0
var _lamp_peak: float = 0.0
var _pad_on: Array[bool] = [false, false]


## Builds the nodes under `view` (hidden until `apply`). `lamps` are the ground points under the lamp heads.
func build(view: Node3D, arena: ArenaDef, lamps: Array[Vector3]) -> void:
	_root = Node3D.new()
	_root.name = "EnvSpill"
	view.add_child(_root)
	var pitch: float = deg_to_rad(CameraFit.effective_pitch_deg(arena))
	var face: Basis = Basis(Vector3.RIGHT, PI * 0.5 - pitch)
	_reactor_mat = EnvMat.halo(&"amber", EnvStyle.REACTOR_HALO).duplicate() as StandardMaterial3D
	_reactor_peak = _reactor_mat.albedo_color.a
	var core_at: Vector3 = Vector3(arena.core_x, 3.0, arena.core_z + 1.4)
	_reactor = _node("ReactorHalo", MeshKit.begin().quad(Vector2(11.0, 11.0), Transform3D(face, core_at), &"pool_amber").build(), _reactor_mat)
	_lamp_mat = EnvMat.halo(&"amber", EnvStyle.LAMP_HALO).duplicate() as StandardMaterial3D
	_lamp_peak = _lamp_mat.albedo_color.a
	var mb: MeshBuilder = MeshKit.begin()
	for spot: Vector3 in lamps:
		mb.quad(Vector2(3.4, 3.4), Transform3D(face, spot + Vector3(0.0, EnvDecor.LAMP_H - 0.2, 0.0)), &"pool_amber")
	_lamps = _node("LampHalos", mb.build(), _lamp_mat)
	var cyan: Material = EnvMat.halo(&"cyan", EnvStyle.PAD_HALO)
	for i: int in mini(2, arena.turret_pads.size()):
		var p: Vector2 = arena.turret_pads[i]
		var quad: ArrayMesh = MeshKit.begin().quad(Vector2(3.6, 3.6), Transform3D(face, Vector3(p.x, 1.1, p.y)), &"pool_cyan").build()
		var pad: MeshInstance3D = _node("PadHalo%d" % i, quad, cyan)
		pad.visible = false
		_pads.append(pad)
	_build_vignette(view)
	_root.visible = false


## Shows what `look` at `tier` allows (the nodes stay; only visibility changes).
func apply(look: int, tier: int) -> void:
	var spill: bool = EnvStyle.on(EnvStyle.SPILL, look, tier)
	_root.visible = spill
	_reactor.visible = EnvStyle.on(EnvStyle.REACTOR, look, tier)
	for i: int in _pads.size():
		_pads[i].visible = spill and _pad_on[i]
	_vignette.visible = EnvStyle.on(EnvStyle.VIGNETTE, look, tier)


func set_pad(pad: int, lit: bool) -> void:
	if pad >= 0 and pad < _pad_on.size():
		_pad_on[pad] = lit
		_pads[pad].visible = lit and _root.visible


## Per frame: the halos follow the core pulse and the lamp flicker (0..1.2 and 0.5..1).
func step(core_level: float, lamp_level: float) -> void:
	_reactor_mat.albedo_color.a = _reactor_peak * clampf(core_level, 0.0, 1.2)
	_lamp_mat.albedo_color.a = _lamp_peak * lamp_level


## The materials of the halos (for the boot warm-up).
func materials() -> Array[Material]:
	return [_reactor_mat, _lamp_mat, EnvMat.halo(&"cyan", EnvStyle.PAD_HALO)]


func node_count() -> int:
	return _root.get_child_count() + 2


func _node(node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


func _build_vignette(view: Node3D) -> void:
	_vignette = CanvasLayer.new()
	_vignette.name = "EnvVignette"
	_vignette.layer = -1  # above the 3D picture, below the HUD
	var rect: ColorRect = ColorRect.new()
	rect.name = "Shade"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = VIGNETTE_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	_vignette.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(_vignette)
	_vignette.visible = false
