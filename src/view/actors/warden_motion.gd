class_name WardenMotion
extends RefCounted
## Procedural life of the hard-surface Warden (W3-C), Warden only, no allocation per frame: damped springs for the
## recoil, the pack, the antenna and the cable (a shot kicks them, turning drags them), idle breathing of the chest,
## both arms solved to the weapon, and a reload pose that reads: the weapon is pulled in toward the chest, tilted and rolled
## toward the support hand, which comes to the magazine; a small tap seats the new one, the visor dims and flashes back.
## Pure math on the nodes it is given; the WardenView decides when to call it (never in the CURRENT look).

const STEP_MAX_S: float = 1.0 / 30.0
const PACK_PITCH: int = 0
const PACK_LIFT: int = 1
const ANT_X: int = 2
const ANT_Z: int = 3
const CABLE_X: int = 4
const CABLE_Z: int = 5
const KICK: int = 6
const CHANNELS: int = 7
## Stiffness and damping per channel (stable for a step of 1/30 s).
const STIFF: Array[float] = [170.0, 230.0, 80.0, 80.0, 55.0, 55.0, 380.0]
const DAMP: Array[float] = [9.0, 11.0, 4.2, 4.2, 3.0, 3.0, 19.0]
const HAND_R_REST: Vector3 = HeroMeshes.WARDEN_HAND  ## the CURRENT look's mount (rest() restores it)
## Indices in WardenParts.extras.
const ARM_RU: int = 0
const ARM_RF: int = 1
const ARM_LU: int = 2
const ARM_LF: int = 3
const PACK: int = 4
const ANTENNA: int = 5
const CABLE: int = 6
## How far the glove center is past the wrist.
const HAND_BEYOND: float = 0.05

var _x: PackedFloat32Array = PackedFloat32Array()
var _v: PackedFloat32Array = PackedFloat32Array()
var _shots: int = 0
var _prev_yaw: float = 0.0
var _turn: float = 0.0
var _first: bool = true


func _init() -> void:
	_x.resize(CHANNELS)
	_v.resize(CHANNELS)


func reset() -> void:
	_x.fill(0.0)
	_v.fill(0.0)
	_turn = 0.0
	_first = true


## A shot: kicks the recoil spring and whips the pack, antenna and cable.
func kick(strength: float = 1.0) -> void:
	_shots += 1
	var flip: float = 1.0 if _shots % 2 == 0 else -1.0
	_v[KICK] += 30.0 * strength
	_v[PACK_PITCH] += 1.6 * strength
	_v[PACK_LIFT] += 0.22 * strength
	_v[ANT_X] += 5.0 * strength
	_v[ANT_Z] += 2.4 * strength * flip
	_v[CABLE_X] += 3.0 * strength
	_v[CABLE_Z] += 1.2 * strength * flip


## Current value of a spring channel (tests).
func value(channel: int) -> float:
	return _x[channel]


## Advances the springs by `delta` seconds; `yaw` is the aim yaw of the upper body this frame.
func step(delta: float, yaw: float) -> void:
	var dt: float = minf(delta, STEP_MAX_S)
	if dt <= 0.0:
		return
	if _first:
		_prev_yaw = yaw
		_first = false
	var rate: float = angle_difference(_prev_yaw, yaw) / dt
	_prev_yaw = yaw
	_turn = lerpf(_turn, clampf(rate, -8.0, 8.0), 1.0 - exp(-12.0 * dt))
	for i: int in CHANNELS:
		var target: float = 0.0
		if i == ANT_Z:
			target = clampf(_turn * 0.05, -0.45, 0.45)
		elif i == CABLE_Z:
			target = clampf(_turn * 0.04, -0.4, 0.4)
		var a: float = STIFF[i] * (target - _x[i]) - DAMP[i] * _v[i]
		_v[i] += a * dt
		_x[i] += _v[i] * dt


## Writes the pose of this frame: `reload` 0..1 is the blend into the reload pose, `progress` 0..1 how far the reload is,
## `weapon` 0 pistol or 1 SMG (it decides where the hands hold it). Both arms are solved by LookDevIk to wrist targets
## that move with the weapon node, so the grips follow every recoil kick and the support hand reaches the magazine.
func pose(
	t: float, reload: float, progress: float, weapon: int, body: Node3D, hand: Node3D, parts: WardenParts
) -> void:
	var breath: float = sin(t * 1.9)
	var k: float = _x[KICK]
	var tap: float = 0.0
	if reload > 0.5:
		tap = sin(clampf((progress - 0.5) / 0.18, 0.0, 1.0) * PI)
	body.position = Vector3(0.0, breath * 0.005, 0.04 * k + 0.04 * reload)
	body.rotation = Vector3(-0.08 * reload - 0.015 * k, 0.05 * reload, sin(t * 1.3) * 0.012)
	hand.position = LookDevWarden.HAND_R + Vector3(-0.1 * reload, -0.02 * reload - 0.02 * tap, 0.035 * k + 0.1 * reload)
	hand.rotation = Vector3(0.12 * k - 0.5 * reload, 0.0, 0.4 * reload)
	var lift: float = 1.0 + 0.012 * breath
	parts.torso.scale = Vector3(1.0 + 0.006 * breath, lift, 1.0 + 0.008 * breath)
	parts.torso.rotation = Vector3(-0.02 * k, 0.0, 0.0)
	var weapon_xf: Transform3D = Transform3D(Basis.from_euler(hand.rotation), hand.position)
	var grip_r: Vector3 = weapon_xf * LookDevGear.grip_r(weapon)
	var grip_l: Vector3 = weapon_xf * LookDevGear.grip_l(weapon).lerp(LookDevGear.mag_point(weapon), reload)
	var shoulder_r: Vector3 = LookDevWarden.SHOULDER_R * Vector3(1.0, lift, 1.0)
	var shoulder_l: Vector3 = LookDevWarden.SHOULDER_L * Vector3(1.0, lift, 1.0)
	var upper_r: MeshInstance3D = parts.extras[ARM_RU]
	var fore_r: MeshInstance3D = parts.extras[ARM_RF]
	var upper_l: MeshInstance3D = parts.extras[ARM_LU]
	var fore_l: MeshInstance3D = parts.extras[ARM_LF]
	LookDevIk.pose_arm(
		upper_r, fore_r, shoulder_r, wrist_target(shoulder_r, grip_r), LookDevWarden.ARM_UPPER, LookDevWarden.ARM_FORE,
		LookDevWarden.POLE_R
	)
	LookDevIk.pose_arm(
		upper_l, fore_l, shoulder_l, wrist_target(shoulder_l, grip_l), LookDevWarden.ARM_UPPER, LookDevWarden.ARM_FORE,
		LookDevWarden.POLE_L
	)
	var pack: MeshInstance3D = parts.extras[PACK]
	var antenna: MeshInstance3D = parts.extras[ANTENNA]
	var cable: MeshInstance3D = parts.extras[CABLE]
	pack.position = LookDevWarden.PACK_PIVOT + Vector3(0.0, breath * 0.004 + _x[PACK_LIFT], 0.0)
	pack.rotation = Vector3(_x[PACK_PITCH], 0.0, 0.0)
	antenna.position = LookDevWarden.ANTENNA_PIVOT * Vector3(1.0, lift, 1.0)
	antenna.rotation = Vector3(_x[ANT_X], 0.0, _x[ANT_Z])
	cable.rotation = Vector3(_x[CABLE_X], 0.0, _x[CABLE_Z])


## The wrist target for a hand that holds `grip` (the hand center sits HAND_BEYOND past the wrist along the arm).
static func wrist_target(shoulder: Vector3, grip: Vector3) -> Vector3:
	var dir: Vector3 = (grip - shoulder).normalized()
	return grip - dir * HAND_BEYOND


## Resets the parts to their rest transforms (switching back to a look without this motion).
static func rest(body: Node3D, hand: Node3D, parts: WardenParts) -> void:
	parts.torso.scale = Vector3.ONE
	parts.torso.rotation = Vector3.ZERO
	for mi: MeshInstance3D in parts.extras:
		mi.rotation = Vector3.ZERO
		mi.basis = Basis.IDENTITY
	for i: int in WardenParts.EXTRAS.size():
		var pivot: Vector3 = WardenParts.EXTRAS[i][2]
		parts.extras[i].position = pivot
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	hand.position = HAND_R_REST
	hand.rotation = Vector3.ZERO
