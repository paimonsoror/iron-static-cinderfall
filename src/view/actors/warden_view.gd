class_name WardenView
extends Node3D
## The Warden: legs stay planted, the upper body yaws to `warden.aim` (GDD 5.1), recoils on `shot_fired`, swaps the
## weapon on `weapon_changed`, dips the weapon while reloading and sways when idle. Procedural, read-only on the sim.
##
## Node tree: WardenView (ground) / Legs, Upper (waist pivot, yaw) / Body (recoil, sway) / Torso, Hand / Pistol, Smg
## (each with a Muzzle marker).

const AIM_RATE: float = 16.0
const RECOIL_KICK: float = 0.7
const RECOIL_DECAY: float = 20.0
const RELOAD_RATE: float = 7.0

var _sim: SimWorld
var _upper: Node3D
var _body: Node3D
var _hand: Node3D
var _weapons: Array[MeshInstance3D] = []
var _muzzles: Array[Node3D] = []
var _weapon: int = 0
var _yaw: float = 0.0
var _fresh: bool = true
var _recoil: float = 0.0
var _reload_amt: float = 0.0
var _reloading: bool = false
var _reload_left: float = 0.0
var _t: float = 0.0


func setup() -> void:
	name = "WardenView"
	visible = false
	var legs: MeshInstance3D = _mesh_node("Legs", ActorMeshes.warden_legs())
	add_child(legs)
	_upper = Node3D.new()
	_upper.name = "Upper"
	_upper.position = Vector3(0.0, HeroMeshes.WARDEN_WAIST_Y, 0.0)
	add_child(_upper)
	_body = Node3D.new()
	_body.name = "Body"
	_upper.add_child(_body)
	_body.add_child(_mesh_node("Torso", ActorMeshes.warden_torso()))
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = HeroMeshes.WARDEN_HAND
	_body.add_child(_hand)
	var specs: Array[Array] = [
		["Pistol", ActorMeshes.pistol(), HeroMeshes.PISTOL_MUZZLE],
		["Smg", ActorMeshes.smg(), HeroMeshes.SMG_MUZZLE],
	]
	for spec: Array in specs:
		var weapon_name: String = spec[0]
		var weapon_mesh: ArrayMesh = spec[1]
		var tip: Vector3 = spec[2]
		var w: MeshInstance3D = _mesh_node(weapon_name, weapon_mesh)
		var m: Node3D = Node3D.new()
		m.name = "Muzzle"
		m.position = tip
		w.add_child(m)
		_hand.add_child(w)
		_weapons.append(w)
		_muzzles.append(m)
	_show_weapon(0)


## Starts reading `sim` (read only) and listening to the Events that drive the Warden's poses.
func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	_fresh = true
	_recoil = 0.0
	_reload_amt = 0.0
	_reloading = sim.warden.reload_ticks_left > 0
	_reload_left = float(sim.warden.reload_ticks_left) * SimWorld.DT
	_show_weapon(clampi(sim.warden.weapon_index, 0, _weapons.size() - 1))
	position = Vector3(sim.warden.x, 0.0, sim.warden.z)
	Events.shot_fired.connect(_on_shot_fired)
	Events.weapon_changed.connect(_on_weapon_changed)
	Events.reload_started.connect(_on_reload_started)
	Events.reload_finished.connect(_on_reload_finished)
	render(0.0, 0.0)
	visible = true


func unbind() -> void:
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	if Events.weapon_changed.is_connected(_on_weapon_changed):
		Events.weapon_changed.disconnect(_on_weapon_changed)
	if Events.reload_started.is_connected(_on_reload_started):
		Events.reload_started.disconnect(_on_reload_started)
	if Events.reload_finished.is_connected(_on_reload_finished):
		Events.reload_finished.disconnect(_on_reload_finished)
	_sim = null
	visible = false


func render(_alpha: float, delta: float) -> void:
	if _sim == null:
		return
	var w: WardenState = _sim.warden
	position = Vector3(w.x, 0.0, w.z)
	var dx: float = w.aim_x - w.x
	var dz: float = w.aim_z - w.z
	if dx * dx + dz * dz > 0.0001:
		var target: float = atan2(-dx, -dz)
		if _fresh:
			_yaw = target
		else:
			_yaw = lerp_angle(_yaw, target, 1.0 - exp(-AIM_RATE * delta))
		_fresh = false
	_upper.rotation.y = _yaw
	_t += delta
	_recoil *= exp(-RECOIL_DECAY * delta)
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reloading = false
	_reload_amt = move_toward(_reload_amt, 1.0 if _reloading else 0.0, delta * RELOAD_RATE)
	# upper body: recoil kick back along the aim, forward dip while reloading, idle sway
	_body.position = Vector3(0.0, sin(_t * 1.8) * 0.008, 0.11 * _recoil + 0.04 * _reload_amt)
	_body.rotation = Vector3(-0.1 * _reload_amt, 0.0, sin(_t * 1.3) * 0.012)
	_hand.rotation.x = 0.08 * _recoil - 0.9 * _reload_amt
	_hand.position = HeroMeshes.WARDEN_HAND + Vector3(0.0, -0.06 * _reload_amt, 0.05 * _recoil)


## World position of the muzzle of the weapon in hand.
func muzzle_position() -> Vector3:
	var m: Node3D = _muzzles[_weapon]
	if m.is_inside_tree():
		return m.global_position
	return position + Vector3(0.0, 1.3, 0.0)


func weapon_index() -> int:
	return _weapon


func weapon_visible(weapon: int) -> bool:
	return weapon >= 0 and weapon < _weapons.size() and _weapons[weapon].visible


func recoil_amount() -> float:
	return _recoil


func reload_amount() -> float:
	return _reload_amt


## Yaw of the upper body (radians, 0 = facing -Z).
func upper_yaw() -> float:
	return _yaw


func is_reloading() -> bool:
	return _reloading


func _show_weapon(index: int) -> void:
	_weapon = clampi(index, 0, _weapons.size() - 1)
	for i: int in _weapons.size():
		_weapons[i].visible = i == _weapon


func _mesh_node(node_name: String, mesh_res: ArrayMesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh_res
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _on_shot_fired(source: int, _target_id: int) -> void:
	if source == DamageSource.Id.WARDEN:
		_recoil = minf(1.0, _recoil + RECOIL_KICK)


func _on_weapon_changed(weapon_id: StringName) -> void:
	var index: int = Ids.weapon_index(weapon_id)
	if index >= 0:
		_show_weapon(index)


func _on_reload_started(ticks: int) -> void:
	_reloading = true
	_reload_left = float(ticks) * SimWorld.DT


func _on_reload_finished() -> void:
	_reloading = false
	_reload_left = 0.0
