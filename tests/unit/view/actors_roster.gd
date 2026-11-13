extends Node
## V4-R capture helper (not a test suite): the real BattleView with a still sim world and the V4-R models, so the new enemies, bosses and
## weapons can be looked at the way the game camera and a close camera see them.
##   -Scene "res://tests/unit/view/actors_roster.tscn --roster=enemies|bosses|minis|weapons|warden|all --game"
##   --game       the game camera (what a player sees: the arena, the fitted camera); without it a low perspective camera frames the row
##   --az=35 --el=28 --dist=6 --fov=30   the gallery camera round the middle of the row (0 = in front of the specimens, they face -Z)
##   --face=up|left|down   which way the specimens face (the game camera sees them mostly facing left or down)
##   --only=<id>   one specimen in the middle     --refs   the four old machines and a burster next to the row
##   --weapon=<id>   (--roster=warden) the weapon in the Warden's hand, the other slot holstered   --holster=<id>   the holstered one
##   --look=current|stylised|stylised_plus  --quality=0|1|2  --high-contrast  --world (keep the yard's props)  --armed
## Nothing here is part of the game; it writes into a throwaway SimWorld like the debug puppet does.

const SOLO_HIDDEN: Array[String] = ["Core", "Props", "Decor", "LampHeads", "LampPools", "Pad0", "Pad1", "PadPool0", "PadPool1", "Rain"]
const NEW_BODIES: Array[int] = [
	Ids.EN_SPITTER, Ids.EN_SPLITTER, Ids.EN_SHIELDBEARER, Ids.EN_RECLAIMER, Ids.EN_JAMMER, Ids.EN_BORER, Ids.EN_WARD_PYLON,
]
const BOSSES: Array[int] = [Ids.EN_BROOD_CARRIER, Ids.EN_LANCE_PLATFORM, Ids.EN_AEGIS_ARRAY, Ids.EN_TREMOR_RIG, Ids.EN_HULK]
const REFS: Array[int] = [Ids.EN_SKITTER, Ids.EN_RUSHER, Ids.EN_HOLLOW, Ids.EN_BURSTER]

var _view: BattleView
var _world: SimWorld
var _cam: Camera3D
var _roster: String = "enemies"
var _game: bool = false
var _az: float = 35.0
var _el: float = 28.0
var _dist: float = 6.0
var _fov: float = 30.0
var _face: Vector2 = Vector2(0.0, -1.0)
var _only: String = ""
var _refs: bool = false
var _armed: bool = false
var _solo: bool = true
var _look_at: Vector3 = Vector3(0.0, 0.9, 0.0)
var _weapon: String = "scattergun"
var _holster: String = ""
var _weapon_nodes: Array[MeshInstance3D] = []


func _ready() -> void:
	var content: ContentSet = Content.db
	var tier: int = VisualQuality.Tier.HIGH
	var contrast: bool = false
	var look: int = -1
	for raw: String in DebugArgs.expand(OS.get_cmdline_user_args()):
		var kv: PackedStringArray = raw.split("=", true, 1)
		var value: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"--roster":
				_roster = value
			"--game":
				_game = true
			"--az":
				_az = value.to_float()
			"--el":
				_el = value.to_float()
			"--dist":
				_dist = value.to_float()
			"--fov":
				_fov = value.to_float()
			"--face":
				_face = {"up": Vector2(0.0, -1.0), "left": Vector2(-1.0, 0.0), "down": Vector2(0.0, 1.0)}.get(value, Vector2(0.0, -1.0))
			"--only":
				_only = value
			"--refs":
				_refs = true
			"--armed":
				_armed = true
			"--weapon":
				_weapon = value
			"--holster":
				_holster = value
			"--quality":
				tier = clampi(value.to_int(), 0, 2)
			"--high-contrast":
				contrast = true
			"--look":
				look = LookDevStyle.from_name(value)
			"--world":
				_solo = false
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	add_child(_view)
	_view.setup(content)
	_view.set_quality(tier)
	_view.set_high_contrast(contrast)
	if look >= 0:
		_view.actor_layer.set_look(look)
		_view.arena_view.set_look(look)
	_world = SimWorld.new(SimConfig.create(content, 1))
	_world.phase = GameState.Id.SPAWNING
	_place()
	_view.bind(_world)
	if _game:
		get_viewport().size_changed.connect(_refit)
		_refit()
	else:
		_cam = Camera3D.new()
		_cam.name = "RosterCamera"
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
	if _roster == "weapons":
		_place_weapons(look if look >= 0 else LookDevStyle.current(), tier)


func _process(delta: float) -> void:
	_view.render(1.0, 1.0 / 60.0 if delta > 0.0 else 0.0)
	if not _game:
		_aim_camera()


func _refit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, Content.db.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, Content.db.tokens)
	_view.fit_camera(size, top, bottom)


func _aim_camera() -> void:
	var yaw: float = deg_to_rad(_az)
	var elev: float = deg_to_rad(_el)
	var from: Vector3 = _look_at + Vector3(sin(yaw) * cos(elev), sin(elev), -cos(yaw) * cos(elev)) * _dist
	_cam.look_at_from_position(from, _look_at, Vector3.UP)


func _place() -> void:
	var ids: Array[int] = []
	var spacing: float = 1.7
	match _roster:
		"enemies":
			ids.append_array(NEW_BODIES)
		"bosses":
			ids.append_array(BOSSES)
			spacing = 5.2
		"minis":
			ids = [Ids.EN_MOTE, Ids.EN_SHARD]
			spacing = 3.0
		"all":
			ids.append_array(NEW_BODIES)
		"warden":
			_place_warden()
			return
		"weapons":
			_look_at = Vector3(0.0, 0.0, 0.0)
			return
	if _only != "":
		ids = [Ids.enemy_index(StringName(_only))]
	if _refs:
		ids.append_array(REFS)
	if _game:
		_place_game(ids)
		return
	var x0: float = -spacing * float(ids.size() - 1) * 0.5
	for k: int in ids.size():
		var index: int = _spawn(ids[k], x0 + spacing * float(k), 0.0)
		if index >= 0 and _armed:
			_world.enemies.state[index] = EnemyStore.ST_ATTACKING
	var height: float = 3.0 if _roster == "bosses" else 1.0
	_look_at = Vector3(0.0, height * 0.55, 0.0)
	if _roster == "minis":
		for n: int in 16:
			var kind: int = Ids.EN_MOTE if n < 8 else Ids.EN_SHARD
			var _m: int = _spawn(kind, -5.0 + float(n % 8) * 0.7, -1.2 - float(floori(float(n) / 8.0)) * 0.9)
		_look_at = Vector3(0.0, 0.2, -0.8)


## The game camera: the specimens in rows in the yard, every one facing `_face`.
func _place_game(ids: Array[int]) -> void:
	var row: int = 0
	var col: int = 0
	for id: int in ids:
		var big: bool = BOSSES.has(id)
		var x: float = -7.0 + float(col) * (4.2 if big else 2.4)
		var z: float = -9.0 + float(row) * (5.0 if big else 3.0)
		if x > 8.0:
			col = 0
			row += 1
			x = -7.0
			z = -9.0 + float(row) * 3.0
		var _i: int = _spawn(id, x, z)
		col += 1
	if _roster == "all":
		for n: int in 16:
			var kind: int = Ids.EN_MOTE if n < 8 else Ids.EN_SHARD
			var _m: int = _spawn(kind, -7.0 + float(n % 8) * 0.9, 3.0 + float(floori(float(n) / 8.0)) * 1.0)
		var bx: float = -6.0
		for boss: int in [Ids.EN_BROOD_CARRIER, Ids.EN_LANCE_PLATFORM, Ids.EN_AEGIS_ARRAY, Ids.EN_TREMOR_RIG]:
			var _b: int = _spawn(boss, bx, 7.5)
			bx += 4.4


func _place_warden() -> void:
	var idx: int = Ids.weapon_index(StringName(_weapon))
	var other: int = Ids.weapon_index(StringName(_holster)) if _holster != "" else 1
	_world.warden.weapon_index = idx
	_world.arsenal.slot_weapon[0] = idx
	_world.arsenal.slot_weapon[1] = other
	_world.arsenal.active = 0
	_world.warden.aim_x = _world.warden.x + 8.0
	_world.warden.aim_z = _world.warden.z - 6.0
	Events.weapon_changed.emit(StringName(_weapon))
	_look_at = Vector3(_world.warden.x, 1.15, _world.warden.z)
	if _dist == 6.0:
		_dist = 3.2


## The weapon meshes on their own in a row, dressed like the Warden's weapon nodes.
func _place_weapons(look: int, tier: int) -> void:
	var names: Array[StringName] = ActorMeshes.WARDEN_WEAPON_NODES
	for k: int in names.size():
		var m: ArrayMesh = ActorMeshes.warden_part(names[k], look)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = m
		for s: int in m.get_surface_count():
			var base: StringName = StringName(m.surface_get_material(s).resource_name)
			mi.set_surface_override_material(s, null if look == LookDevStyle.Look.CURRENT else LookDevMat.surface(base, look, tier))
		var row: int = floori(float(k) / 5.0)
		mi.position = Vector3(-1.2 + float(k % 5) * 0.62, 0.0, 0.0 - float(row) * 0.5)
		mi.scale = Vector3(1.4, 1.4, 1.4)
		mi.rotation.y = deg_to_rad(90.0)
		_view.add_child(mi)
		_weapon_nodes.append(mi)
	_look_at = Vector3(-0.5, 0.0, -0.1)
	if _dist == 6.0:
		_dist = 2.5


func _spawn(type_index: int, x: float, z: float) -> int:
	var i: int = _world.spawn_enemy(type_index, x, z)
	if i < 0:
		return i
	_world.enemies.x[i] = x
	_world.enemies.z[i] = z
	_world.enemies.prev_x[i] = x
	_world.enemies.prev_z[i] = z
	_world.enemies.face_x[i] = _face.x
	_world.enemies.face_z[i] = _face.y
	return i
