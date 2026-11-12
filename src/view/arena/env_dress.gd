class_name EnvDress
extends RefCounted
## The environment grit pass of the yard (W3-E), owned by ArenaView. ArenaView builds today's yard (CURRENT) exactly as before; this
## class keeps the styled variants next to it (built once, the first time a styled look is applied) and swaps them by
## (look, tier) through EnvStyle: the floor material, the prop meshes, the extra nodes (light spill, reactor detail, vignette) and the
## Environment's grade. Switching looks never creates a node or a material after the first styled apply. CURRENT restores the exact
## original references.

var _view: ArenaView
var _arena: ArenaDef
var _tokens: VisualTokens
var _lamps: Array[Vector3] = []
var _ground: MeshInstance3D
var _ground_old: Material
var _ground_new: ShaderMaterial
var _props: MeshInstance3D
var _decor: MeshInstance3D
var _heads: MeshInstance3D
var _old_meshes: Array[Mesh] = []
var _light: EnvLight = EnvLight.new()
var _reactor: MeshInstance3D
var _new_meshes: Array[ArrayMesh] = []
var _look: int = LookDevStyle.Look.CURRENT
var _tier: int = VisualQuality.Tier.MID
var _built: bool = false


func attach(view: ArenaView, arena: ArenaDef, tokens: VisualTokens, lamp_spots: Array[Vector3]) -> void:
	_view = view
	_arena = arena
	_tokens = tokens
	_lamps = lamp_spots
	_ground = view.get_node("Ground") as MeshInstance3D
	_ground_old = _ground.material_override
	_props = view.get_node("Props") as MeshInstance3D
	_decor = view.get_node("Decor") as MeshInstance3D
	_heads = view.get_node("LampHeads") as MeshInstance3D
	_old_meshes = [_props.mesh, _decor.mesh, _heads.mesh]


## The boot warm-up (ShaderWarmup): the old yard's ground and the hard-surface Warden's materials, plus, for a styled look, every material
## of the styled yard (the floor, the halos, the prop paint and the lit panels; the prop quads carry a vertex colour like the prop meshes).
func warm_up(center: Vector3, ground: Material, look: int) -> void:
	var extra: Array[Material] = [ground]
	var lit: Array[Material] = LookDevMat.warm_materials(look)
	if look != LookDevStyle.Look.CURRENT:
		_build()
		extra.append(_ground_new)
		extra.append_array(_light.materials())
		lit.append(EnvMat.prop(true))
		lit.append(EnvMat.prop(false))
		lit.append(EnvMat.emit(&"amber", EnvStyle.WINDOW_GAIN))
		lit.append(EnvMat.emit(&"cyan", EnvStyle.WINDOW_GAIN))
	ShaderWarmup.attach(_view, center, extra, lit)


## Applies `look` at `tier` (ArenaView calls it from set_quality and set_look).
func apply(look: int, tier: int) -> void:
	if _view == null:
		return
	_look = look
	_tier = tier
	var styled: bool = look != LookDevStyle.Look.CURRENT
	if styled:
		_build()
	_apply_floor()
	_apply_props()
	_apply_light()
	_apply_grade()


## Per frame: the intensities of the reflecting source groups (core pulse, lamp flicker).
func step(core_level: float, lamp_level: float) -> void:
	if _built:
		_light.step(core_level, lamp_level)
	if _ground_new != null and EnvStyle.on(EnvStyle.FLICKER, _look, _tier):
		EnvGround.set_groups(_ground_new, core_level, lamp_level, _pad_level(0), _pad_level(1))


func set_pad(pad: int, lit: bool) -> void:
	if _built:
		_light.set_pad(pad, lit)
	if _ground_new != null:
		EnvGround.set_groups(_ground_new, 1.0, 1.0, _pad_level(0), _pad_level(1))


## Bloom for HDR emissives: three small mip levels (1/4, 1/8, 1/16 of the screen) so the glow stays tight and the chain short, added
## on top, only above the HDR threshold (an emissive material with energy above 1). On for STYLISED_PLUS (LookDevStyle.glow_enabled)
## and for the styled yard's GLOW gate (EnvStyle); `LookDevStyle.glow_override` (look-dev flag) wins over both.
static func apply_glow(env: Environment, look: int, tier: int) -> void:
	var on: bool = LookDevStyle.glow_enabled(look, tier)
	if LookDevStyle.glow_override < 0:
		on = on or EnvStyle.on(EnvStyle.GLOW, look, tier)
	env.glow_enabled = on
	if not on:
		return
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.0
	for level: int in 7:
		env.set_glow_level(level, 1.0 if level >= 1 and level <= 3 else 0.0)


func floor_material() -> Material:
	return _ground.material_override


func _pad_level(pad: int) -> float:
	return 1.0 if _view.pad_is_lit(pad) else 0.22


func _build() -> void:
	if _built:
		return
	_built = true
	_ground_new = EnvGround.build(_arena, _tokens, _lamps)
	var props: MeshBuilder = MeshKit.begin()
	for ob: ObstacleDef in _arena.obstacles:
		EnvProps.add_obstacle(props, ob)
	var body: MeshBuilder = MeshKit.begin()
	var heads: MeshBuilder = MeshKit.begin()
	EnvDecor.build(_arena, body, heads)
	_new_meshes = [EnvShapes.finish(props), EnvShapes.finish(body), EnvShapes.finish(heads)]
	_light.build(_view, _arena, _lamps)
	_reactor = MeshInstance3D.new()
	_reactor.name = "Detail"
	_reactor.mesh = EnvReactor.mesh()
	_reactor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.core.add_child(_reactor)


func _apply_floor() -> void:
	if EnvStyle.on(EnvStyle.FLOOR, _look, _tier):
		EnvGround.set_tier(_ground_new, EnvStyle.on(EnvStyle.WET, _look, _tier), EnvStyle.on(EnvStyle.RIPPLES, _look, _tier))
		_ground.material_override = _ground_new
	else:
		_ground.material_override = _ground_old


## The prop meshes: styled geometry (PROPS), styled shading (PROP_SHADER on MID and HIGH, baked vertex colours on LOW).
func _apply_props() -> void:
	var nodes: Array[MeshInstance3D] = [_props, _decor, _heads]
	var styled: bool = EnvStyle.on(EnvStyle.PROPS, _look, _tier)
	for i: int in nodes.size():
		if styled:
			EnvMat.bind(_new_meshes[i], EnvStyle.on(EnvStyle.PROP_SHADER, _look, _tier))
		nodes[i].mesh = _new_meshes[i] if styled else _old_meshes[i]
	_view.lamp_gain = EnvStyle.LAMP_GAIN if EnvStyle.on(EnvStyle.SPILL, _look, _tier) else 1.0
	_view.refresh_lamps()


## Light spill, the reactor detail and the HDR gains.
func _apply_light() -> void:
	if not _built:
		return
	_light.apply(_look, _tier)
	var reactor: bool = EnvStyle.on(EnvStyle.REACTOR, _look, _tier)
	_reactor.visible = reactor
	EnvMat.bind(_reactor.mesh as ArrayMesh, false)
	_view.core.gain = EnvStyle.REACTOR_GAIN if reactor else 1.0
	_view.core.pool_gain = 1.7 if EnvStyle.on(EnvStyle.SPILL, _look, _tier) else 1.0
	_view.pool_gain = 2.2 if EnvStyle.on(EnvStyle.SPILL, _look, _tier) else 1.0


## Tonemap and colour adjustment of the Environment; CURRENT gets the engine defaults back.
func _apply_grade() -> void:
	var env: Environment = _view.environment_node.environment
	var on: bool = EnvStyle.on(EnvStyle.GRADE, _look, _tier)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if on else Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = EnvStyle.GRADE_EXPOSURE
	env.tonemap_white = EnvStyle.GRADE_WHITE if on else 1.0
	env.adjustment_enabled = on
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = EnvStyle.GRADE_CONTRAST if on else 1.0
	env.adjustment_saturation = EnvStyle.GRADE_SATURATION if on else 1.0
