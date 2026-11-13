class_name FxScale
extends RefCounted
## Keeps an effect the same size ON THE SCREEN wherever it happens (V4-X). The camera is a perspective one, so a blast at the far edge of the
## yard is drawn smaller than the same blast beside the Warden: `at(point)` is the factor (distance to the camera over the distance to the
## middle of the yard, clamped) that a module multiplies into the world size of an effect that must stay readable. 1.0 when no camera is
## known (tests without a rig). Purely a view helper: it reads the camera, never the sim.

const MIN_FACTOR: float = 0.9
const MAX_FACTOR: float = 1.55

var _cam: Vector3 = Vector3.INF
var _ref: float = 0.0
var _center: Vector3 = Vector3.ZERO


func setup(arena: ArenaDef) -> void:
	_center = Vector3((arena.min_x + arena.max_x) * 0.5, 0.0, (arena.min_z + arena.max_z) * 0.5)


## Reads the camera position once per frame (the rig may not be in the tree yet: then nothing is scaled).
func update(rig: CameraRig) -> void:
	if rig == null or rig.camera == null:
		_cam = Vector3.INF
		return
	_cam = rig.camera.global_position if rig.camera.is_inside_tree() else rig.camera.position
	_ref = _cam.distance_to(_center)


func at(point: Vector3) -> float:
	if not _cam.is_finite() or _ref < 0.001:
		return 1.0
	return clampf(_cam.distance_to(point) / _ref, MIN_FACTOR, MAX_FACTOR)


func known() -> bool:
	return _cam.is_finite() and _ref >= 0.001
