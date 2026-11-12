class_name CameraRig
extends Node3D
## Perspective camera (narrow field of view, `CameraFit.FOV_DEG`) looking down at the arena (ARCH 8, GDD 4.1): fixed, no zoom, pan or rotation. `fit` places it
## with CameraFit so the whole playable rectangle sits between the top HUD and the bottom controls.
## `world_to_screen` uses the same pure math (in the viewport size passed to `fit`), so it works before the camera
## enters the tree and always matches what the HUD layer uses.

const DEFAULT_VIEWPORT: Vector2 = Vector2(1080.0, 1920.0)

var camera: Camera3D

var _arena: ArenaDef
var _fit: CameraFitResult
var _viewport: Vector2 = DEFAULT_VIEWPORT


func setup(arena: ArenaDef, tokens: VisualTokens) -> void:
	_arena = arena
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	# Until the first real fit, assume the standard HUD bands so the first frame is already framed sensibly.
	var top: float = DEFAULT_VIEWPORT.y * tokens.top_hud_fraction
	var bottom: float = DEFAULT_VIEWPORT.y * tokens.bottom_controls_fraction
	fit(DEFAULT_VIEWPORT, top, bottom)


func fit(viewport_size: Vector2, top_px: float, bottom_px: float) -> void:
	if camera == null or _arena == null:
		return
	_viewport = viewport_size
	_fit = CameraFit.solve(_arena, viewport_size, top_px, bottom_px)
	if _fit.fov_deg > 0.0:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = _fit.fov_deg
		camera.near = CameraPersp.NEAR
		camera.far = CameraPersp.FAR
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.near = 0.1
		camera.far = 200.0
	camera.size = _fit.ortho_size
	camera.transform = Transform3D(_fit.basis, _fit.position)


## Screen position (pixels, in the viewport size given to `fit`) of a world point.
func world_to_screen(world: Vector3) -> Vector2:
	if _fit == null:
		return Vector2.ZERO
	return CameraFit.project(_fit, _viewport, world)


## The world point on the plane at height `ground_y` under a screen pixel.
func screen_to_ground(screen_px: Vector2, ground_y: float = 0.0) -> Vector3:
	if _fit == null:
		return Vector3.ZERO
	return CameraFit.unproject_ground(_fit, _viewport, screen_px, ground_y)


func pitch_down_deg() -> float:
	if _arena == null:
		return 0.0
	return CameraFit.effective_pitch_deg(_arena)


## Pixels per meter on the ground at the current fit (0 before the first fit).
func px_per_meter() -> float:
	if _fit == null:
		return 0.0
	return _fit.px_per_meter
