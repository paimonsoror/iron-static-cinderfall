class_name CameraRig
extends Node3D
## Orthographic camera looking down at the arena (ARCH 8). Wave 0: pitch from the arena data, size from
## CameraFit. TODO(W1-E): polish.

var camera: Camera3D
var _arena: ArenaDef


func setup(arena: ArenaDef, _tokens: VisualTokens) -> void:
	_arena = arena
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	fit(Vector2(1080.0, 1920.0), 0.0, 0.0)


func fit(viewport_size: Vector2, top_px: float, bottom_px: float) -> void:
	if camera == null or _arena == null:
		return
	var r: CameraFitResult = CameraFit.solve(_arena, viewport_size, top_px, bottom_px)
	camera.size = r.ortho_size
	camera.transform = Transform3D(r.basis, r.position)


## Screen position (in the camera's viewport) of a world point.
func world_to_screen(world: Vector3) -> Vector2:
	if camera == null or not camera.is_inside_tree():
		return Vector2.ZERO
	return camera.unproject_position(world)


func pitch_down_deg() -> float:
	if _arena == null:
		return 0.0
	return _arena.pitch_down_deg
