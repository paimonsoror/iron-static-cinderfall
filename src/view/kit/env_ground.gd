class_name EnvGround
extends RefCounted
## The floor material of the gritty yard (W3-E): one ShaderMaterial on `env_ground.gdshader` shared by every tier. Tier gates
## (EnvStyle): FLOOR is the shader without the reflection loop (`wet_on` 0: darker asphalt, seams, cracks, patches, painted stripes,
## puddles as darker tone: no extra cost over the old floor shader); WET adds the reflection streaks of the lit sources; RIPPLES (HIGH)
## adds rain rings on the puddles. The light sources are pushed once as uniform arrays; only four intensities change per frame
## (the core, the lamps, the two pads). Colours come from the palette tokens.

const SHADER_PATH: String = "res://src/view/kit/env_ground.gdshader"
const MAX_SOURCES: int = 12
const GROUP_CORE: int = 0
const GROUP_LAMP: int = 1
const GROUP_PAD0: int = 2
const GROUP_PAD1: int = 3
const GROUP_STEADY: int = 4

static var _shader: Shader = null

## Look-dev tuning (sandbox `--env-tune=name:value,...`): shader parameter overrides applied after the defaults.
static var overrides: Dictionary[StringName, float] = {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## The floor material for this arena, coloured from the palette tokens. `lamps` are the ground points under the lamp heads.
static func build(arena: ArenaDef, tokens: VisualTokens, lamps: Array[Vector3]) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader()
	m.resource_name = "env_ground"
	m.set_shader_parameter(&"floor_tex", EnvTex.texture())
	var obs: Color = tokens.color(&"obsidian")
	var steel: Color = tokens.color(&"gunmetal")
	m.set_shader_parameter(&"c_slab_a", obs.lerp(steel, 0.075))
	m.set_shader_parameter(&"c_slab_b", obs.lerp(steel, 0.17))
	m.set_shader_parameter(&"c_seam", obs.darkened(0.55))
	m.set_shader_parameter(&"c_puddle", obs.lerp(tokens.color(&"warden_cyan"), 0.35))
	m.set_shader_parameter(&"c_hazard", tokens.color(&"core_amber"))
	m.set_shader_parameter(&"play_rect", Vector4(arena.min_x, arena.min_z, arena.max_x, arena.max_z))
	var yaw: float = deg_to_rad(arena.decor_yaw_deg)
	m.set_shader_parameter(&"decor_cs", Vector2(cos(yaw), sin(yaw)))
	m.set_shader_parameter(&"warden_xy", Vector2(arena.warden_x, arena.warden_z))
	m.set_shader_parameter(&"core_xy", Vector2(arena.core_x, arena.core_z))
	m.set_shader_parameter(&"c_sky", obs.lerp(steel, 0.55))
	m.set_shader_parameter(&"stripes", _stripes(arena))
	set_sources(m, arena, tokens, lamps)
	set_tier(m, false, false)
	set_groups(m, 1.0, 1.0, 0.0, 0.0)
	for key: StringName in overrides:
		m.set_shader_parameter(key, overrides[key])
	return m


## WET (reflection streaks) and RIPPLES switches.
static func set_tier(m: ShaderMaterial, wet: bool, ripples: bool) -> void:
	m.set_shader_parameter(&"wet_on", 1.0 if wet else 0.0)
	m.set_shader_parameter(&"ripples_on", 1.0 if ripples else 0.0)


## Intensities of the source groups (core pulse, lamp flicker, pad occupied).
static func set_groups(m: ShaderMaterial, core: float, lamp: float, pad0: float, pad1: float) -> void:
	m.set_shader_parameter(&"grp", Vector4(core, lamp, pad0, pad1))


## The reflecting sources: the reactor column, the lamp heads, the Warden's lights and the two turret pads. A source at height h
## shows on the floor `h * cot(pitch)` toward the viewer, so its streak starts and ends there along Z.
static func set_sources(m: ShaderMaterial, arena: ArenaDef, tokens: VisualTokens, lamps: Array[Vector3]) -> void:
	var cot: float = 1.0 / tan(deg_to_rad(CameraFit.effective_pitch_deg(arena)))
	var amber: Color = tokens.color(&"core_amber")
	var cyan: Color = tokens.color(&"warden_cyan")
	var pos: PackedVector4Array = PackedVector4Array()
	var col: PackedVector4Array = PackedVector4Array()
	var reach: float = arena.core_radius * 0.46
	pos.append(Vector4(arena.core_x, arena.core_z + reach + 0.7 * cot, arena.core_z + reach + 5.0 * cot, arena.core_radius * 0.5))
	col.append(Vector4(amber.r * 2.0, amber.g * 2.0, amber.b * 2.0, GROUP_CORE))
	for spot: Vector3 in lamps:
		if pos.size() >= MAX_SOURCES - 3:
			break
		pos.append(Vector4(spot.x, spot.z + 4.7 * cot, spot.z + 5.1 * cot, 0.55))
		col.append(Vector4(amber.r * 1.8, amber.g * 1.8, amber.b * 1.8, GROUP_LAMP))
	pos.append(Vector4(arena.warden_x, arena.warden_z + 0.9 * cot, arena.warden_z + 1.6 * cot, 0.6))
	col.append(Vector4(cyan.r * 0.9, cyan.g * 0.9, cyan.b * 0.9, GROUP_STEADY))
	for i: int in mini(2, arena.turret_pads.size()):
		var p: Vector2 = arena.turret_pads[i]
		pos.append(Vector4(p.x, p.y + 0.6 * cot, p.y + 1.5 * cot, 0.6))
		col.append(Vector4(cyan.r * 1.3, cyan.g * 1.3, cyan.b * 1.3, GROUP_PAD0 + i))
	var n: int = pos.size()
	while pos.size() < MAX_SOURCES:
		pos.append(Vector4.ZERO)
		col.append(Vector4.ZERO)
	m.set_shader_parameter(&"src_pos", pos)
	m.set_shader_parameter(&"src_col", col)
	m.set_shader_parameter(&"src_n", n)


## Hazard-paint patches as (center_x, center_z, half_x, half_z) in world meters: beside the "B-4" stencil near the Warden and a
## threshold strip at the top spawn edge (just outside the playable rectangle). The third slot is unused.
static func _stripes(arena: ArenaDef) -> PackedVector4Array:
	var out: PackedVector4Array = PackedVector4Array()
	out.append(Vector4(arena.min_x + 5.2, arena.max_z - 0.9, 1.7, 0.32))
	out.append(Vector4((arena.min_x + arena.max_x) * 0.5 + 5.5, arena.min_z - 0.9, 5.4, 0.28))
	out.append(Vector4(-999.0, -999.0, 0.0, 0.0))
	return out
