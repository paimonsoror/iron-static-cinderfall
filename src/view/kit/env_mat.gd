class_name EnvMat
extends RefCounted
## The shared materials of the gritty yard (W3-E): one instance per kind, never per instance. Palette colours come from MatLib (the
## tokens stay the single source).
##  prop(shaded)   MID and HIGH: a ShaderMaterial on env_prop.gdshader (grime streaks, wet foot, cool rim); LOW: a StandardMaterial3D
##                 that shows the baked vertex colours only. Both read the vertex colour as the albedo.
##  emit(role)     unshaded amber or cyan windows and light panels, HDR above 1 (an unshaded material ignores its emission: the
##                 brightness is the albedo times the gain, and above 1 only bloom or the tonemap sees it).
##  halo(role)     additive radial glow quads (camera-facing halos of lamps and the reactor).

const PROP_SHADER: String = "res://src/view/kit/env_prop.gdshader"

static var _shader: Shader = null
static var _cache: Dictionary[String, Material] = {}


static func prop_shader() -> Shader:
	if _shader == null:
		_shader = load(PROP_SHADER) as Shader
	return _shader


## The prop material of a tier class (`shaded` = MID and HIGH).
static func prop(shaded: bool) -> Material:
	var key: String = "prop|%d" % (1 if shaded else 0)
	if not _cache.has(key):
		if shaded:
			var sm: ShaderMaterial = ShaderMaterial.new()
			sm.resource_name = "env_prop"
			sm.shader = prop_shader()
			sm.set_shader_parameter(&"grime_tex", EnvTex.texture())
			_cache[key] = sm
		else:
			var std: StandardMaterial3D = StandardMaterial3D.new()
			std.resource_name = "env_prop_baked"
			std.vertex_color_use_as_albedo = true
			std.roughness = 0.8
			std.metallic = 0.0
			_cache[key] = std
	return _cache[key]


## Unshaded light panel: `role` is `amber` or `cyan`, `gain` the brightness (above 1 = HDR).
static func emit(role: StringName, gain: float) -> StandardMaterial3D:
	var key: String = "emit|%s|%.2f" % [role, gain]
	if not _cache.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.resource_name = "env_emit_%s" % role
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c: Color = MatLib.mat(&"emit_%s" % role).albedo_color
		m.albedo_color = Color(c.r * gain, c.g * gain, c.b * gain, 1.0)
		_cache[key] = m
	var out: StandardMaterial3D = _cache[key] as StandardMaterial3D
	return out


## Additive radial glow (white falloff texture tinted by the palette colour); `peak` is the alpha at the centre.
static func halo(role: StringName, peak: float) -> StandardMaterial3D:
	var key: String = "halo|%s|%.3f" % [role, peak]
	if not _cache.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.resource_name = "env_halo_%s" % role
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_receive_shadows = true
		m.albedo_texture = MatLib.glow_texture()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		var c: Color = MatLib.mat(&"emit_%s" % role).albedo_color
		m.albedo_color = Color(c.r, c.g, c.b, peak)
		_cache[key] = m
	var out: StandardMaterial3D = _cache[key] as StandardMaterial3D
	return out


## Swaps the real materials into a styled prop mesh; its surfaces are named by their slot (see EnvShapes). The other surfaces (the blob
## shadows) keep their MatLib material.
static func bind(mesh: ArrayMesh, shaded: bool) -> void:
	for i: int in mesh.get_surface_count():
		match mesh.surface_get_name(i):
			"steel_grey":
				mesh.surface_set_material(i, prop(shaded))
			"emit_amber":
				mesh.surface_set_material(i, emit(&"amber", EnvStyle.WINDOW_GAIN))
			"emit_cyan":
				mesh.surface_set_material(i, emit(&"cyan", EnvStyle.WINDOW_GAIN))


static func cached_count() -> int:
	return _cache.size()


## Repaints the cached palette materials after `MatLib.configure`.
static func refresh() -> void:
	for key: String in _cache.keys():
		var parts: PackedStringArray = key.split("|")
		var m: Material = _cache[key]
		var std: StandardMaterial3D = m as StandardMaterial3D
		if std == null or parts[0] == "prop":
			continue
		var c: Color = MatLib.mat(StringName("emit_%s" % parts[1])).albedo_color
		if parts[0] == "emit":
			var gain: float = parts[2].to_float()
			std.albedo_color = Color(c.r * gain, c.g * gain, c.b * gain, 1.0)
		else:
			std.albedo_color = Color(c.r, c.g, c.b, parts[2].to_float())
