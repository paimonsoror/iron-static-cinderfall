class_name ArenaView
extends Node3D
## The yard (GDD 4.2, 12.3): wet concrete ground with seams, puddle gloss, hazard stripes and a "B-4" stencil;
## the four props of arena.json; dressing outside the playable rectangle; Relay Core B-4 (CoreRig); two hex turret
## pads; the cyan Warden ring; faked light pools (additive quads); one directional light; the environment.
## Everything is merged meshes and a handful of nodes (well under 60), palette materials only, no concept art.
## Quality tiers (VisualQuality) switch shadows for static props, omni lights, rain and the cheaper ground shader.

const STENCIL_TEXT: String = "B-4"
const RAIN_STREAKS: int = 90
const RAIN_PERIOD: float = 7.0
const RAIN_SPEED: float = 17.0
const GROUND_SIZE: Vector2 = Vector2(96.0, 108.0)

var sun: DirectionalLight3D
var environment_node: WorldEnvironment
var core: CoreRig
var omnis: Array[OmniLight3D] = []

var _arena: ArenaDef
var _tokens: VisualTokens
var _tier: int = VisualQuality.Tier.MID
var _look: int = LookDevStyle.current()  ## the process-wide look, so the boot only sets LookDevStyle.set_current
var _ground_mat: ShaderMaterial
var _casters: Array[MeshInstance3D] = []
var _pad_meshes: Array[MeshInstance3D] = []
var _pad_pools: Array[MeshInstance3D] = []
var _pad_on: Array[bool] = []
var _pad_rim_dim: StandardMaterial3D
var _pad_rim_lit: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _lamp_pool_mat: StandardMaterial3D
var _lamp_level: float = 1.0
var _lamp_pool_peak: float = 0.16
var _lamp_timer: float = 0.0
var _rain: MeshInstance3D
var _omni_base: Array[float] = []
var _time: float = 0.0
var _reduced_flash: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(arena: ArenaDef, tokens: VisualTokens) -> void:
	_arena = arena
	_tokens = tokens
	_rng.seed = 2026
	_build_ground()
	_build_props_and_decor()
	_build_pads_and_ring()
	_build_core()
	_build_spawn_glow()
	_build_rain()
	_build_lights()
	set_quality(VisualQuality.Tier.MID)
	var center: Vector3 = Vector3((arena.min_x + arena.max_x) * 0.5, -0.4, (arena.min_z + arena.max_z) * 0.5)
	var extra: Array[Material] = [_ground_mat]
	ShaderWarmup.attach(self, center, extra, LookDevMat.warm_materials(_look))
	set_process(true)


## hp_fraction and shield_fraction are 0..1. Dims, flickers and darkens the core (with sparks when dead).
func set_core_state(hp_fraction: float, shield_fraction: float, dead: bool) -> void:
	if core != null:
		core.set_state(hp_fraction, shield_fraction, dead)


## An occupied pad glows bright cyan with a light pool; an empty one shows a dim outline and a plus mark.
func set_pad_state(pad: int, has_turret: bool) -> void:
	if pad < 0 or pad >= _pad_meshes.size():
		return
	_pad_on[pad] = has_turret
	var rim: StandardMaterial3D = _pad_rim_lit if has_turret else _pad_rim_dim
	_pad_meshes[pad].set_surface_override_material(1, rim)
	_pad_pools[pad].visible = has_turret


func set_quality(tier_value: int) -> void:
	_tier = VisualQuality.from_setting(tier_value)
	var shadows: bool = VisualQuality.shadows_enabled(_tier)
	if sun != null:
		sun.shadow_enabled = shadows
	var setting: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shadows:
		setting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mi: MeshInstance3D in _casters:
		mi.cast_shadow = setting
	if core != null:
		core.set_shadows(shadows)
	var budget: int = VisualQuality.omni_light_budget(_tier)
	for i: int in omnis.size():
		omnis[i].visible = i < budget
	if _rain != null:
		_rain.visible = VisualQuality.rain_enabled(_tier)
	if _ground_mat != null:
		GroundMaterial.set_quality(_ground_mat, _tier)
	RenderingServer.directional_shadow_atlas_set_size(VisualQuality.shadow_atlas_size(_tier), true)
	_apply_glow()
	if is_inside_tree():
		VisualQuality.apply_render_scale(get_viewport(), _tier)
		LookDevStyle.apply_aa(get_viewport(), _look, _tier)


## Character look (LookDevStyle.Look, W3-C look-dev): only STYLISED_PLUS turns bloom on, on MID and HIGH.
func set_look(look: int) -> void:
	_look = clampi(look, LookDevStyle.Look.CURRENT, LookDevStyle.Look.STYLISED_PLUS)
	_apply_glow()
	if is_inside_tree():
		LookDevStyle.apply_aa(get_viewport(), _look, _tier)


func current_look() -> int:
	return _look


func glow_active() -> bool:
	return environment_node != null and environment_node.environment.glow_enabled


## Bloom for HDR emissives: three small mip levels (1/4, 1/8, 1/16 of the screen) so the glow stays tight and the
## chain short, added on top, only above the HDR threshold (an emissive material with energy above 1).
func _apply_glow() -> void:
	if environment_node == null:
		return
	var env: Environment = environment_node.environment
	var on: bool = LookDevStyle.glow_enabled(_look, _tier)
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


func _enter_tree() -> void:
	VisualQuality.apply_render_scale(get_viewport(), _tier)


func _exit_tree() -> void:
	VisualQuality.apply_render_scale(get_viewport(), VisualQuality.Tier.MID)  # the next owner of the viewport starts clean


## Flicker (core, lamps) gets slower and shallower for players who asked for reduced flashing.
func set_reduced_flash(on: bool) -> void:
	_reduced_flash = on
	if core != null:
		core.reduced_flash = on


func tier() -> int:
	return _tier


func pad_is_lit(pad: int) -> bool:
	return pad >= 0 and pad < _pad_on.size() and _pad_on[pad]


func rain_visible() -> bool:
	return _rain != null and _rain.visible


func visible_omni_count() -> int:
	var n: int = 0
	for o: OmniLight3D in omnis:
		if o.visible:
			n += 1
	return n


## All descendants of this node (tests: node budget).
func node_count() -> int:
	return _count(self) - 1


## Advances view-only animation by `delta` seconds: core pulse, dimming and flicker, lamp flicker, rain scroll.
func advance(delta: float) -> void:
	_time += delta
	if core != null:
		core.step(delta)
		_drive_core_light()
	_step_lamps(delta)
	if _rain != null and _rain.visible:
		_rain.position.y = -fmod(_time * RAIN_SPEED, RAIN_PERIOD)


func _process(delta: float) -> void:
	advance(delta)


func _count(n: Node) -> int:
	var c: int = 1
	for child: Node in n.get_children():
		c += _count(child)
	return c


# ---------------------------------------------------------------- builders

func _node(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_ground() -> void:
	var a: ArenaDef = _arena
	var mb: MeshBuilder = MeshKit.begin()
	var center: Vector3 = Vector3((a.min_x + a.max_x) * 0.5, 0.0, (a.min_z + a.max_z) * 0.5)
	mb.quad(GROUND_SIZE, Transform3D(Basis.IDENTITY, center), &"concrete")
	var ground: MeshInstance3D = _node("Ground", mb.build())
	_ground_mat = GroundMaterial.build(a, _tokens)
	ground.material_override = _ground_mat
	var yaw: float = deg_to_rad(a.decor_yaw_deg)
	var stencil: Label3D = LabelKit.make(STENCIL_TEXT, 3.4, _stencil_color(), 160, 0.35)
	stencil.name = "Stencil"
	stencil.position = Vector3(a.min_x + 4.4, 0.035, a.max_z - 2.0)
	stencil.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	add_child(stencil)


func _stencil_color() -> Color:
	var c: Color = _tokens.color(&"bone_ceramic")
	return Color(c.r, c.g, c.b, 0.5)


func _build_props_and_decor() -> void:
	var props: MeshBuilder = MeshKit.begin()
	for ob: ObstacleDef in _arena.obstacles:
		PropKit.add_obstacle(props, ob)
	_casters.append(_node("Props", props.build()))

	var body: MeshBuilder = MeshKit.begin()
	var heads: MeshBuilder = MeshKit.begin()
	var lamp_spots: Array[Vector3] = DecorKit.build(_arena, body, heads)
	_casters.append(_node("Decor", body.build()))
	var heads_node: MeshInstance3D = _node("LampHeads", heads.build())
	_lamp_mat = MatLib.mat(&"emit_amber").duplicate() as StandardMaterial3D
	_lamp_mat.emission_enabled = false
	heads_node.material_override = _lamp_mat

	var pools: MeshBuilder = MeshKit.begin()
	for spot: Vector3 in lamp_spots:
		pools.quad(Vector2(6.0, 6.0), Transform3D(Basis.IDENTITY, Vector3(spot.x, 0.03, spot.z)), &"pool_lamp")
	var pools_node: MeshInstance3D = _node("LampPools", pools.build())
	_lamp_pool_mat = MatLib.mat(&"pool_lamp").duplicate() as StandardMaterial3D
	_lamp_pool_peak = _lamp_pool_mat.albedo_color.a
	pools_node.material_override = _lamp_pool_mat


func _build_pads_and_ring() -> void:
	var cyan: Color = _tokens.color(&"warden_cyan")
	var obs: Color = _tokens.color(&"obsidian")
	_pad_rim_lit = MatLib.mat(&"emit_cyan")
	_pad_rim_dim = MatLib.mat(&"emit_cyan").duplicate() as StandardMaterial3D
	_pad_rim_dim.emission_enabled = false
	_pad_rim_dim.albedo_color = obs.lerp(cyan, 0.34)
	for i: int in _arena.turret_pads.size():
		var p: Vector2 = _arena.turret_pads[i]
		var mb: MeshBuilder = MeshKit.begin()
		var turn: Basis = Basis(Vector3.UP, PI / 6.0)
		mb.cylinder(1.02, 1.08, 0.12, 6, Transform3D(turn, Vector3(0.0, 0.06, 0.0)), &"dark_frame")
		mb.cylinder(1.2, 1.2, 0.05, 6, Transform3D(turn, Vector3(0.0, 0.025, 0.0)), &"emit_cyan")
		mb.box(Vector3(0.56, 0.02, 0.08), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.13, 0.0)), &"emit_cyan")
		mb.box(Vector3(0.08, 0.02, 0.56), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.13, 0.0)), &"emit_cyan")
		var pad: MeshInstance3D = _node("Pad%d" % i, mb.build())
		pad.position = Vector3(p.x, 0.0, p.y)
		_pad_meshes.append(pad)
		_pad_on.append(false)
		var quad: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0))
		var pool: MeshInstance3D = _node("PadPool%d" % i, MeshKit.begin().quad(Vector2(6.0, 6.0), quad, &"pool_cyan").build())
		pool.position = pad.position
		pool.visible = false
		_pad_pools.append(pool)
		set_pad_state(i, false)

	var ring: MeshBuilder = MeshKit.begin()
	ring.ring(0.86, 1.02, 36, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0)), &"emit_cyan")
	ring.ring(0.62, 0.68, 36, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0)), &"emit_cyan")
	ring.quad(Vector2(6.0, 6.0), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), &"pool_cyan")
	var ring_node: MeshInstance3D = _node("WardenRing", ring.build())
	ring_node.position = Vector3(_arena.warden_x, 0.0, _arena.warden_z)


func _build_core() -> void:
	core = CoreRig.new()
	core.name = "Core"
	var others: Array[Vector2] = [Vector2(_arena.warden_x, _arena.warden_z)]
	for p: Vector2 in _arena.turret_pads:
		others.append(p)
	add_child(core)
	core.setup(_arena, _tokens, others)


## Faint red glow along the spawn edges: one stretched radial quad per region.
func _build_spawn_glow() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	for r: SpawnRegionDef in _arena.spawn_regions:
		var mid: Vector2 = Vector2((r.x0 + r.x1) * 0.5, (r.z0 + r.z1) * 0.5)
		var span: Vector2 = Vector2(absf(r.x1 - r.x0), absf(r.z1 - r.z0))
		var size: Vector2 = Vector2(maxf(span.x, 1.0) + 5.0, maxf(span.y, 1.0) + 5.0)
		if span.x < span.y:
			size.x = 7.0
		else:
			size.y = 7.0
		mb.quad(size, Transform3D(Basis.IDENTITY, Vector3(mid.x, 0.028, mid.y)), &"pool_red")
	_node("SpawnGlow", mb.build())


## Rain streaks (HIGH only): two copies of one period of streaks, scrolled down and wrapped.
func _build_rain() -> void:
	var mb: MeshBuilder = MeshKit.begin()
	var lean: Basis = Basis(Vector3.BACK, deg_to_rad(7.0)) * Basis(Vector3.RIGHT, PI * 0.5)
	var lo: Vector2 = Vector2(_arena.min_x - 12.0, _arena.min_z - 10.0)
	var hi: Vector2 = Vector2(_arena.max_x + 12.0, _arena.max_z + 8.0)
	for i: int in RAIN_STREAKS:
		var x: float = _rng.randf_range(lo.x, hi.x)
		var z: float = _rng.randf_range(lo.y, hi.y)
		var y: float = _rng.randf_range(0.0, RAIN_PERIOD)
		var streak_len: float = _rng.randf_range(0.9, 1.6)
		for copy: int in 2:
			var at: Vector3 = Vector3(x, y + RAIN_PERIOD * float(copy), z)
			mb.quad(Vector2(0.022, streak_len), Transform3D(lean, at), &"rain")
	_rain = _node("Rain", mb.build())
	_rain.visible = false


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color.WHITE.lerp(_tokens.color(&"warden_cyan"), 0.22)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _tokens.color(&"obsidian")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _tokens.color(&"obsidian").lerp(_tokens.color(&"warden_cyan"), 0.3)
	env.ambient_light_energy = 0.55
	environment_node = WorldEnvironment.new()
	environment_node.name = "Environment"
	environment_node.environment = env
	add_child(environment_node)

	var amber: Color = _tokens.color(&"core_amber")
	var cyan: Color = _tokens.color(&"warden_cyan")
	_add_omni("OmniCore", Vector3(_arena.core_x, 3.4, _arena.core_z), amber, 11.0, 1.6)
	_add_omni("OmniWarden", Vector3(_arena.warden_x, 2.4, _arena.warden_z), cyan, 6.5, 0.9)
	for i: int in _arena.turret_pads.size():
		var p: Vector2 = _arena.turret_pads[i]
		_add_omni("OmniPad%d" % i, Vector3(p.x, 1.8, p.y), cyan, 5.0, 0.7)


func _add_omni(node_name: String, at: Vector3, color: Color, reach: float, energy: float) -> void:
	var o: OmniLight3D = OmniLight3D.new()
	o.name = node_name
	o.position = at
	o.light_color = color
	o.omni_range = reach
	o.omni_attenuation = 1.5
	o.light_energy = energy
	o.light_specular = 0.0
	o.shadow_enabled = false
	add_child(o)
	omnis.append(o)
	_omni_base.append(energy)


# ---------------------------------------------------------------- animation

func _drive_core_light() -> void:
	if omnis.is_empty():
		return
	var k: float = clampf(core.light_level(), 0.0, 1.2)
	omnis[0].light_energy = _omni_base[0] * k


func _step_lamps(delta: float) -> void:
	_lamp_timer -= delta
	if _lamp_timer > 0.0 or _lamp_mat == null:
		return
	_lamp_timer = 0.45 if _reduced_flash else _rng.randf_range(0.18, 0.5)
	var dip: bool = not _reduced_flash and _rng.randf() < 0.07
	_lamp_level = _rng.randf_range(0.5, 0.75) if dip else _rng.randf_range(0.9, 1.0)
	var amber: Color = _tokens.color(&"core_amber")
	_lamp_mat.albedo_color = _tokens.color(&"obsidian").lerp(amber, _lamp_level)
	_lamp_pool_mat.albedo_color = Color(amber.r, amber.g, amber.b, _lamp_pool_peak * _lamp_level)
