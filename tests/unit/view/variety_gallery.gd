extends Node
## V2-F capture helper (not a test suite): the real BattleView with a still sim world, one specimen of the new content and a low
## perspective camera, so the new models can be looked at the way the three-quarter game camera and a close camera see them.
##   -Scene "res://tests/unit/view/variety_gallery.tscn --gallery=burster|mote|swarm|row|arc|crate|ring --az=35 --el=28 --dist=3.4"
##   --armed (burster: held in ATTACK mode so the tank swells)  --look=current|stylised  --quality=0|1|2  --high-contrast
##   --harmful (ring: the telegraph is a red hatch)  --world (keep the yard's props)
## Nothing here is part of the game; it writes into a throwaway SimWorld like the debug puppet does.

const SOLO_HIDDEN: Array[String] = ["Core", "Props", "Decor", "LampHeads", "LampPools", "Pad0", "Pad1", "PadPool0", "PadPool1", "Rain"]

var _view: BattleView
var _world: SimWorld
var _cam: Camera3D
var _gallery: String = "burster"
var _look_at: Vector3 = Vector3(0.0, 0.7, 0.0)
var _az: float = 35.0  ## degrees round the specimen: 0 in front of it (it faces -Z), 90 its left side, 180 behind
var _el: float = 28.0
var _dist: float = 3.4
var _fov: float = 30.0
var _armed: bool = false
var _frame: int = 0
var _solo: bool = true
var _tick_hold: int = 0
var _harmful: bool = false  ## the strike's event is a harmful one (a red hatch instead of the cyan ring)


func _ready() -> void:
	var content: ContentSet = Content.db
	var tier: int = VisualQuality.Tier.HIGH
	var contrast: bool = false
	var look: int = -1
	for raw: String in DebugArgs.expand(OS.get_cmdline_user_args()):
		var kv: PackedStringArray = raw.split("=", true, 1)
		var value: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"--gallery":
				_gallery = value
			"--az":
				_az = value.to_float()
			"--el":
				_el = value.to_float()
			"--dist":
				_dist = value.to_float()
			"--fov":
				_fov = value.to_float()
			"--armed":
				_armed = true
			"--quality":
				tier = clampi(value.to_int(), 0, 2)
			"--high-contrast":
				contrast = true
			"--look":
				look = LookDevStyle.from_name(value)
			"--world":
				_solo = false
			"--hold":
				_tick_hold = value.to_int()
			"--harmful":
				_harmful = true
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	add_child(_view)
	_view.setup(content)
	_view.set_quality(tier)
	_view.set_high_contrast(contrast)
	if look >= 0:
		_view.actor_layer.set_look(look)
		_view.arena_view.set_look(look)
	if _harmful:
		content.events[content.event_index(&"deadfall_strike")].harmful = true  # this process's copy only
	_world = SimWorld.new(SimConfig.create(content, 1))
	_world.phase = GameState.Id.SPAWNING
	_place()
	_view.bind(_world)
	_cam = Camera3D.new()
	_cam.name = "GalleryCamera"
	_cam.fov = _fov
	_cam.near = 0.2
	_cam.far = 160.0
	_view.add_child(_cam)
	_cam.make_current()
	if _solo:
		for node_name: String in SOLO_HIDDEN:
			var hidden_node: Node3D = _view.arena_view.get_node_or_null(node_name) as Node3D
			if hidden_node != null:
				hidden_node.visible = false
	_aim_camera()


func _process(delta: float) -> void:
	_frame += 1
	_view.render(1.0, 1.0 / 60.0 if delta > 0.0 else 0.0)
	if _gallery == "ring" or _gallery == "arc":
		_animate_effects()
	_aim_camera()


func _aim_camera() -> void:
	var yaw: float = deg_to_rad(_az)
	var elev: float = deg_to_rad(_el)
	var from: Vector3 = _look_at + Vector3(sin(yaw) * cos(elev), sin(elev), -cos(yaw) * cos(elev)) * _dist
	_cam.look_at_from_position(from, _look_at, Vector3.UP)


## The specimens stand near the middle of the yard facing -Z (the screen's up), so `--az` 0 looks at their faces.
func _place() -> void:
	var st: EnemyStore = _world.enemies
	match _gallery:
		"burster":
			var i: int = _spawn(Ids.EN_BURSTER, 0.0, 0.0)
			if _armed and i >= 0:
				st.state[i] = EnemyStore.ST_ATTACKING
			_look_at = Vector3(0.0, 0.75, 0.0)
		"mote":
			var _m: int = _spawn(Ids.EN_MOTE, 0.0, 0.0)
			_look_at = Vector3(0.0, 0.2, 0.0)
		"swarm":
			for k: int in 40:
				var _s: int = _spawn(Ids.EN_MOTE, -3.0 + float(k % 8) * 0.75, -2.0 + float(floori(float(k) / 8.0)) * 0.75)
			_look_at = Vector3(0.0, 0.2, 0.0)
		"row":
			var _b: int = _spawn(Ids.EN_BURSTER, -1.6, 0.0)
			var _k: int = _spawn(Ids.EN_SKITTER, -0.4, 0.0)
			var _h: int = _spawn(Ids.EN_HOLLOW, 0.9, 0.0)
			var _r: int = _spawn(Ids.EN_RUSHER, 2.2, 0.0)
			for n: int in 5:
				var _mn: int = _spawn(Ids.EN_MOTE, -1.4 + float(n) * 0.5, 1.4)
			_look_at = Vector3(0.3, 0.6, 0.4)
		"arc":
			_world.warden.weapon_index = Ids.WP_ARC_PROJECTOR
			_world.warden.aim_x = _world.warden.x
			_world.warden.aim_z = _world.warden.z - 8.0
			Events.weapon_changed.emit(&"arc_projector")
			_look_at = Vector3(_world.warden.x, 1.2, _world.warden.z)
			for k: int in 4:
				var _t: int = _spawn(Ids.EN_SKITTER, _world.warden.x + float(k) * 0.8 - 1.2, _world.warden.z - 4.0 - float(k % 2) * 1.2)
		"crate":
			_world.salvage.crate_active = true
			_world.salvage.crate_x = 0.0
			_world.salvage.crate_z = 0.0
			_world.salvage.crate_progress = 300
			_look_at = Vector3(0.0, 0.3, 0.0)
		"ring":
			_look_at = Vector3(0.0, 0.0, 0.0)


func _spawn(type_index: int, x: float, z: float) -> int:
	var i: int = _world.spawn_enemy(type_index, x, z)
	if i < 0:
		return i
	_world.enemies.x[i] = x
	_world.enemies.z[i] = z
	_world.enemies.prev_x[i] = x
	_world.enemies.prev_z[i] = z
	_world.enemies.face_x[i] = 0.0
	_world.enemies.face_z[i] = -1.0
	return i


## `--gallery=ring` and `arc`: the effects that need events (a telegraph, a blast, an arc) are fired on a loop.
func _animate_effects() -> void:
	if _frame % 90 != 5:
		return
	match _gallery:
		"ring":
			Events.event_warned.emit(&"deadfall_strike", 120, 0.0, 0.0)
			Events.pool_changed.emit(1, -3.0, 2.0, 2.2, true)
			Events.area_blast.emit(HazardState.K_BLAST, 3.0, 0.0, 2.6)
			Events.area_blast.emit(HazardState.K_STRIKE, -3.0, -3.0, 4.0)
		"arc":
			var ids: Array[int] = []
			for i: int in _world.enemies.high_water:
				if _world.enemies.alive[i] == 1:
					ids.append(_world.enemies.id[i])
			var from_id: int = 0
			for enemy_id: int in ids:
				Events.chain_arc.emit(from_id, enemy_id)
				from_id = enemy_id
