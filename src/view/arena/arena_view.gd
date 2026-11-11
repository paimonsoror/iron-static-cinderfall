class_name ArenaView
extends Node3D
## The yard. Wave 0 stub: a flat ground quad, the Relay Core cylinder, one directional light and a flat
## environment. TODO(W1-E): the full yard (props, pads, ring, light pools, label, quality tiers).

var _sun: DirectionalLight3D
var _env: WorldEnvironment


func setup(arena: ArenaDef, tokens: VisualTokens) -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"
	var gb: MeshBuilder = MeshKit.begin()
	var w: float = arena.max_x - arena.min_x
	var d: float = arena.max_z - arena.min_z
	var gx: float = (arena.min_x + arena.max_x) * 0.5
	var gz: float = (arena.min_z + arena.max_z) * 0.5
	gb.quad(Vector2(w, d), Transform3D(Basis.IDENTITY, Vector3(gx, 0.0, gz)), &"concrete")
	ground.mesh = gb.build()
	add_child(ground)

	var core: MeshInstance3D = MeshInstance3D.new()
	core.name = "Core"
	var cb: MeshBuilder = MeshKit.begin()
	var base_pos: Vector3 = Vector3(arena.core_x, 0.5, arena.core_z)
	cb.cylinder(arena.core_radius, arena.core_radius, 1.0, 24, Transform3D(Basis.IDENTITY, base_pos), &"gunmetal")
	cb.cylinder(
		arena.core_radius * 0.55,
		arena.core_radius * 0.55,
		2.4,
		24,
		Transform3D(Basis.IDENTITY, Vector3(arena.core_x, 2.2, arena.core_z)),
		&"emit_amber"
	)
	core.mesh = cb.build()
	add_child(core)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_sun.light_energy = 1.1
	_sun.shadow_enabled = false
	add_child(_sun)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = tokens.color(&"obsidian")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = tokens.color(&"gunmetal")
	env.ambient_light_energy = 0.55
	_env = WorldEnvironment.new()
	_env.name = "Environment"
	_env.environment = env
	add_child(_env)


## hp_fraction and shield_fraction are 0..1.
func set_core_state(_hp_fraction: float, _shield_fraction: float, _dead: bool) -> void:
	# TODO(W1-E)
	pass


func set_pad_state(_pad: int, _has_turret: bool) -> void:
	# TODO(W1-E)
	pass


func set_quality(_tier: int) -> void:
	# TODO(W1-E)
	pass
