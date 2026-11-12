class_name CoreRig
extends Node3D
## Relay Core B-4 (GDD 12.3): a caged reactor, amber emissive column inside eight gunmetal ribs, ring base, cable roots,
## a sloped name plate carrying the label "RELAY CORE B-4", and an amber light pool on the ground.
## It pulses; it dims and flickers as integrity falls; on defeat it goes dark and throws sparks.
## Built from nominal geometry for radius 2 m and scaled to `arena.core_radius`.

const LABEL_TEXT: String = "RELAY CORE B-4"
const NOMINAL_RADIUS: float = 2.0
const POOL_SIZE: float = 12.0
const PLATE_W: float = 3.6
const MIN_GLOW: float = 0.22
const SPARK_COUNT: int = 18

var column_mat: StandardMaterial3D
var pool_mat: StandardMaterial3D
var shield_mat: StandardMaterial3D
var spark_mat: StandardMaterial3D
var reduced_flash: bool = false
var gain: float = 1.0  ## brightness of the column (the styled yard drives it above 1 for the tonemap and the bloom)
var pool_gain: float = 1.0  ## strength of the light pool

var _tokens: VisualTokens
var _body: MeshInstance3D
var _column: MeshInstance3D
var _pool: MeshInstance3D
var _shield: MeshInstance3D
var _sparks: MeshInstance3D
var _label: Label3D

var _hp: float = 1.0
var _shield_frac: float = 0.0
var _dead: bool = false
var _glow: float = 1.0
var _flicker: float = 1.0
var _flicker_timer: float = 0.0
var _spark_timer: float = 0.0
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pool_peak: float = 0.7
var _shield_peak: float = 0.6


func setup(arena: ArenaDef, tokens: VisualTokens, others: Array[Vector2]) -> void:
	_tokens = tokens
	_rng.seed = 4711
	position = Vector3(arena.core_x, 0.0, arena.core_z)
	scale = Vector3.ONE * (arena.core_radius / NOMINAL_RADIUS)
	var pitch: float = deg_to_rad(CameraFit.effective_pitch_deg(arena))

	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = _body_mesh(arena, pitch, others)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)

	_column = MeshInstance3D.new()
	_column.name = "Column"
	_column.mesh = _column_mesh()
	column_mat = _own(&"emit_amber")
	_column.material_override = column_mat
	add_child(_column)

	_pool = MeshInstance3D.new()
	_pool.name = "Pool"
	_pool.mesh = MeshKit.begin().quad(Vector2(POOL_SIZE, POOL_SIZE), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), &"pool_amber").build()
	pool_mat = _own(&"pool_amber")
	_pool_peak = pool_mat.albedo_color.a
	_pool.material_override = pool_mat
	add_child(_pool)

	_shield = MeshInstance3D.new()
	_shield.name = "ShieldRing"
	_shield.mesh = MeshKit.begin().ring(2.6, 2.85, 40, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)), &"add_cyan").build()
	shield_mat = _own(&"add_cyan")
	_shield_peak = shield_mat.albedo_color.a
	_shield.material_override = shield_mat
	_shield.visible = false
	add_child(_shield)

	_sparks = MeshInstance3D.new()
	_sparks.name = "Sparks"
	_sparks.mesh = _spark_mesh()
	spark_mat = _own(&"emit_amber")
	_sparks.material_override = spark_mat
	_sparks.visible = false
	add_child(_sparks)

	var plate: Dictionary = _plate_frame(pitch)
	var white: Color = tokens.color(&"bone_ceramic")
	_label = LabelKit.make(LABEL_TEXT, PLATE_W - 0.3, white, 64)
	_label.name = "Label"
	var label_pos: Vector3 = plate["center"]
	var normal: Vector3 = plate["normal"]
	_label.position = label_pos + normal * 0.13
	_label.basis = Basis(Vector3.RIGHT, -pitch)
	add_child(_label)
	_apply()


## The static body casts a shadow on HIGH only; the emissive parts never do.
func set_shadows(on: bool) -> void:
	if _body == null:
		return
	if on:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## hp and shield are 0..1; `dead` is authoritative for the dark, sparking look.
func set_state(hp_fraction: float, shield_fraction: float, dead: bool) -> void:
	_hp = clampf(hp_fraction, 0.0, 1.0)
	_shield_frac = clampf(shield_fraction, 0.0, 1.0)
	_dead = dead
	_apply()


## Advances the pulse, the dimming and the flicker by `delta` seconds (view time, not sim time).
func step(delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, _target_glow(), delta * 1.6)
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_roll_flicker()
	if _dead:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = 0.12 if not reduced_flash else 0.4
			_jitter_sparks()
	_apply()


## Smoothed 0..1 brightness without the pulse or flicker (tests and light energy read this).
func glow() -> float:
	return _glow


## 1.0 steady, below 1.0 while a flicker dip is active.
func flicker_factor() -> float:
	return _flicker


func is_dead() -> bool:
	return _dead


func sparks_visible() -> bool:
	return _sparks != null and _sparks.visible


func shield_visible() -> bool:
	return _shield != null and _shield.visible


func label_node() -> Label3D:
	return _label


## Current brightness including pulse and flicker, 0..1.2, for the omni light that ArenaView drives.
func light_level() -> float:
	if _dead:
		return 0.0
	return _glow * _flicker * (1.0 + 0.06 * sin(_time * TAU * 0.9))


func _target_glow() -> float:
	if _dead:
		return 0.0
	return lerpf(MIN_GLOW, 1.0, pow(_hp, 0.7))


func _roll_flicker() -> void:
	_flicker = 1.0
	_flicker_timer = 0.4 if reduced_flash else _rng.randf_range(0.06, 0.24)
	if _dead or _hp >= 0.5:
		return
	var chance: float = (0.5 - _hp) * 1.6
	if _rng.randf() < chance:
		var floor_v: float = 0.78 if reduced_flash else 0.3
		_flicker = _rng.randf_range(floor_v, 0.8 if not reduced_flash else 0.92)


func _apply() -> void:
	if column_mat == null:
		return
	var amber: Color = _tokens.color(&"core_amber")
	var dark: Color = MatLib.mat(&"dark_frame").albedo_color
	var k: float = 0.0 if _dead else clampf(light_level(), 0.0, 1.0)
	var lit: Color = dark.lerp(amber, k)
	column_mat.albedo_color = Color(lit.r * gain, lit.g * gain, lit.b * gain)
	pool_mat.albedo_color = Color(amber.r, amber.g, amber.b, _pool_peak * k * pool_gain)
	_pool.visible = k > 0.01
	var cyan: Color = _tokens.color(&"warden_cyan")
	shield_mat.albedo_color = Color(cyan.r, cyan.g, cyan.b, _shield_peak * _shield_frac)
	_shield.visible = _shield_frac > 0.01 and not _dead
	if not _dead:
		_sparks.visible = false


func _jitter_sparks() -> void:
	_sparks.visible = _rng.randf() < 0.75
	_sparks.position = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.2, 0.3), _rng.randf_range(-0.4, 0.4))
	_sparks.rotation.y = _rng.randf_range(0.0, TAU)


func _own(id: StringName) -> StandardMaterial3D:
	var dup: StandardMaterial3D = MatLib.mat(id).duplicate() as StandardMaterial3D
	dup.emission_enabled = false  # unshaded: the albedo alone carries the color, so dimming it dims the part
	return dup


## Center and outward normal of the name plate in this node's local space.
func _plate_frame(pitch: float) -> Dictionary:
	var half_h: float = 0.45
	var half_t: float = 0.11
	var lift: float = half_h * cos(pitch) + half_t * sin(pitch) + 0.02
	var reach: float = half_h * sin(pitch) + half_t * cos(pitch)
	return {
		"center": Vector3(0.0, lift, NOMINAL_RADIUS + 0.1 + reach),
		"normal": Vector3(0.0, sin(pitch), cos(pitch)),
	}


func _body_mesh(arena: ArenaDef, pitch: float, others: Array[Vector2]) -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.cylinder(2.05, 2.25, 0.45, 18, _y(0.225), &"gunmetal")
	mb.cylinder(1.7, 1.8, 0.2, 18, _y(0.55), &"dark_frame")
	mb.ring(2.3, 2.55, 36, _y(0.02), &"hazard")
	mb.cylinder(1.45, 1.45, 0.3, 18, _y(0.85), &"dark_frame")
	mb.cylinder(1.4, 1.4, 0.14, 18, _y(2.9), &"dark_frame")
	mb.cylinder(1.45, 1.45, 0.3, 18, _y(5.1), &"dark_frame")
	mb.cylinder(0.8, 1.4, 0.55, 18, _y(5.55), &"gunmetal")
	mb.cylinder(0.12, 0.12, 1.4, 8, _y(6.5), &"dark_frame")
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		var at: Vector3 = Vector3(cos(a) * 1.3, 2.9, sin(a) * 1.3)
		mb.box(Vector3(0.17, 4.5, 0.17), Transform3D(Basis(Vector3.UP, -a), at), &"gunmetal")
	for i: int in 4:
		var a2: float = TAU * float(i) / 4.0
		var at2: Vector3 = Vector3(cos(a2) * 2.0, 0.28, sin(a2) * 2.0)
		mb.box(Vector3(0.9, 0.34, 0.5), Transform3D(Basis(Vector3.UP, -a2), at2), &"dark_frame")
	# Sloped name plate facing the camera, with a hazard edge.
	var plate: Dictionary = _plate_frame(pitch)
	var plate_basis: Basis = Basis(Vector3.RIGHT, -pitch)
	var center: Vector3 = plate["center"]
	mb.box(Vector3(PLATE_W, 0.9, 0.22), Transform3D(plate_basis, center), &"dark_frame")
	var up_dir: Vector3 = plate_basis * Vector3.UP
	mb.box(Vector3(PLATE_W, 0.06, 0.26), Transform3D(plate_basis, center + up_dir * 0.46), &"hazard")
	# Cable roots: out to the left, and to the other pads and the Warden along the ground.
	var left_run: Array[Vector3] = [Vector3(-2.0, 0.11, 0.3), Vector3(-3.3, 0.11, 1.0), Vector3(-4.6, 0.11, 0.1)]
	DecorKit.cable(mb, left_run, 0.11)
	var core_at: Vector2 = Vector2(arena.core_x, arena.core_z)
	for target: Vector2 in others:
		var d: Vector2 = (target - core_at) * (NOMINAL_RADIUS / arena.core_radius)
		if d.length() < 3.0:
			continue
		var dir: Vector2 = d.normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var start: Vector2 = dir * 2.55
		var mid: Vector2 = d * 0.5 + side * 0.9
		var stop: Vector2 = d - dir * 1.3
		var run: Array[Vector3] = [
			Vector3(start.x, 0.08, start.y), Vector3(mid.x, 0.08, mid.y), Vector3(stop.x, 0.08, stop.y)
		]
		DecorKit.cable(mb, run, 0.07)
	return mb.build()


func _column_mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	mb.cylinder(0.92, 0.92, 4.3, 20, _y(2.85), &"emit_amber")
	mb.cylinder(1.48, 1.48, 0.07, 18, _y(4.9), &"emit_amber")
	mb.cylinder(1.48, 1.48, 0.07, 18, _y(1.0), &"emit_amber")
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		var at: Vector3 = Vector3(cos(a) * 2.2, 0.3, sin(a) * 2.2)
		mb.box(Vector3(0.62, 0.1, 0.08), Transform3D(Basis(Vector3.UP, -(a + PI * 0.5)), at), &"emit_amber")
	return mb.build()


func _spark_mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshKit.begin()
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 99
	for i: int in SPARK_COUNT:
		var a: float = r.randf_range(0.0, TAU)
		var rad: float = r.randf_range(0.7, 1.9)
		var at: Vector3 = Vector3(cos(a) * rad, r.randf_range(0.9, 5.2), sin(a) * rad)
		var s: float = r.randf_range(0.1, 0.22)
		mb.box(Vector3(s, s, s), Transform3D(Basis(Vector3.UP, r.randf_range(0.0, TAU)), at), &"emit_amber")
	return mb.build()


static func _y(h: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, h, 0.0))
