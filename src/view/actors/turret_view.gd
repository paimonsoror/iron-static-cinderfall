class_name TurretView
extends Node3D
## One auto turret on a pad: rises out of the pad when deployed (`turret_deployed`), yaws to `turrets.aim` and kicks
## back on its own `shot_fired`. Hidden until deployed. Read only on the sim.
##
## Node tree: TurretView (pad) / Rise / Base, Head (yaw pivot) / HeadMesh (recoil), Muzzle.

const DEPLOY_S: float = 0.7
const AIM_RATE: float = 12.0
const RECOIL_DECAY: float = 18.0

var pad: int = 0

var _sim: SimWorld
var _rise: Node3D
var _head: Node3D
var _head_mesh: MeshInstance3D
var _muzzle: Node3D
var _deployed: bool = false
var _deploy_t: float = 0.0
var _yaw: float = 0.0
var _fresh: bool = true
var _recoil: float = 0.0


func setup(pad_index: int) -> void:
	pad = pad_index
	name = "TurretView%d" % pad_index
	visible = false
	_rise = Node3D.new()
	_rise.name = "Rise"
	add_child(_rise)
	var base: MeshInstance3D = MeshInstance3D.new()
	base.name = "Base"
	base.mesh = ActorMeshes.turret_base()
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rise.add_child(base)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, HeroMeshes.TURRET_HEAD_Y, 0.0)
	_rise.add_child(_head)
	_head_mesh = MeshInstance3D.new()
	_head_mesh.name = "HeadMesh"
	_head_mesh.mesh = ActorMeshes.turret_head()
	_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(_head_mesh)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = HeroMeshes.TURRET_MUZZLE
	_head.add_child(_muzzle)


func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	_fresh = true
	_recoil = 0.0
	_deployed = false
	position = Vector3(sim.turrets.x[pad], 0.0, sim.turrets.z[pad])
	if sim.turrets.active[pad] == 1:
		_start_deploy(DEPLOY_S)
	Events.turret_deployed.connect(_on_turret_deployed)
	Events.shot_fired.connect(_on_shot_fired)
	render(0.0, 0.0)


func unbind() -> void:
	if Events.turret_deployed.is_connected(_on_turret_deployed):
		Events.turret_deployed.disconnect(_on_turret_deployed)
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	_sim = null
	_deployed = false
	visible = false


func render(_alpha: float, delta: float) -> void:
	if _sim == null:
		return
	var ts: TurretStore = _sim.turrets
	position = Vector3(ts.x[pad], 0.0, ts.z[pad])
	if ts.active[pad] == 1 and not _deployed:
		_start_deploy(0.0)
	elif ts.active[pad] == 0 and _deployed:
		_deployed = false
		visible = false
	if not _deployed:
		return
	_deploy_t = minf(_deploy_t + delta, DEPLOY_S)
	var p: float = _deploy_t / DEPLOY_S
	var e: float = 1.0 - pow(1.0 - p, 3.0)
	_rise.position = Vector3(0.0, -0.95 * (1.0 - e), 0.0)
	_rise.scale = Vector3.ONE * (0.6 + 0.4 * e)
	var dx: float = ts.aim_x[pad] - ts.x[pad]
	var dz: float = ts.aim_z[pad] - ts.z[pad]
	if dx * dx + dz * dz > 0.0001:
		var target: float = atan2(-dx, -dz)
		_yaw = target if _fresh else lerp_angle(_yaw, target, 1.0 - exp(-AIM_RATE * delta))
		_fresh = false
	_head.rotation.y = _yaw
	_recoil *= exp(-RECOIL_DECAY * delta)
	_head_mesh.position = Vector3(0.0, 0.0, 0.1 * _recoil)


func muzzle_position() -> Vector3:
	if _muzzle.is_inside_tree():
		return _muzzle.global_position
	return position + Vector3(0.0, 0.85, 0.0)


func is_deployed() -> bool:
	return _deployed


## 0..1 progress of the deploy rise.
func deploy_progress() -> float:
	return _deploy_t / DEPLOY_S if _deployed else 0.0


func recoil_amount() -> float:
	return _recoil


func upper_yaw() -> float:
	return _yaw


func _start_deploy(elapsed: float) -> void:
	_deployed = true
	_deploy_t = elapsed
	visible = true
	_rise.position = Vector3(0.0, -0.95 * (1.0 - minf(elapsed / DEPLOY_S, 1.0)), 0.0)


func _on_turret_deployed(pad_index: int) -> void:
	if pad_index == pad and not _deployed:
		_start_deploy(0.0)


func _on_shot_fired(source: int, _target_id: int) -> void:
	if source == DamageSource.Id.TURRET_0 + pad:
		_recoil = 1.0
