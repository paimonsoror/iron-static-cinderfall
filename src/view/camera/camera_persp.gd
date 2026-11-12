class_name CameraPersp
extends RefCounted
## The perspective half of CameraFit (pure math, no renderer): a narrow-field-of-view camera that looks down at the arena by the pitch,
## placed so the playable rectangle and the spawn ends (plus the frame margin) fill the band between the HUD bars, exactly like the
## orthographic fit does. A Camera3D with KEEP_HEIGHT has a vertical field of view `fov_deg`; the horizontal one follows the aspect.
## `solve` finds the smallest distance at which the corners still fit the width and the band (bisection: the fit is monotonic), then
## shifts the camera along its up vector until the projected rectangle is centred in the band.

const MIN_DISTANCE: float = 8.0
const MAX_DISTANCE: float = 500.0
const NEAR: float = 1.0
const FAR: float = 300.0


## The camera for `corners` (ground points that must all be visible). `res.px_per_meter` is the scale on the ground at the
## rectangle centre; `res.ortho_size` is the orthographic size that would give the same scale there (tests and the HUD read it).
static func solve(
	basis: Basis, corners: Array[Vector3], viewport_size: Vector2, top_px: float, bottom_px: float, fov_deg: float
) -> CameraFitResult:
	var band_h: float = maxf(1.0, viewport_size.y - top_px - bottom_px)
	var band_centre: float = top_px + band_h * 0.5
	var centre: Vector3 = (corners[0] + corners[2]) * 0.5
	var lo_d: float = MIN_DISTANCE
	var hi_d: float = MAX_DISTANCE
	for _i: int in 40:
		var mid: float = (lo_d + hi_d) * 0.5
		var origin: Vector3 = _placed(corners, centre, basis, mid, viewport_size, band_centre, fov_deg)
		var x0: float = INF
		var x1: float = -INF
		var y0: float = INF
		var y1: float = -INF
		for c: Vector3 in corners:
			var p: Vector2 = _project(c, origin, basis, viewport_size, fov_deg)
			x0 = minf(x0, p.x)
			x1 = maxf(x1, p.x)
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		if x1 - x0 <= viewport_size.x and y1 - y0 <= band_h:
			hi_d = mid
		else:
			lo_d = mid
	var res: CameraFitResult = CameraFitResult.new()
	res.fov_deg = fov_deg
	res.px_per_meter = viewport_size.y / (2.0 * hi_d * tan(deg_to_rad(fov_deg) * 0.5))
	res.ortho_size = viewport_size.y / res.px_per_meter  # the orthographic size with the same scale at the rectangle centre
	res.basis = basis
	res.position = _placed(corners, centre, basis, hi_d, viewport_size, band_centre, fov_deg)
	return res


## Screen position in pixels (origin top-left, y down) of a world point under a perspective fit.
static func project(res: CameraFitResult, viewport_size: Vector2, world: Vector3) -> Vector2:
	return _project(world, res.position, res.basis, viewport_size, res.fov_deg)


## The world point at height `ground_y` under a screen pixel (the camera ray through the pixel meets the horizontal plane).
static func unproject_ground(res: CameraFitResult, viewport_size: Vector2, screen_px: Vector2, ground_y: float) -> Vector3:
	var t: float = tan(deg_to_rad(res.fov_deg) * 0.5)
	var ndc: Vector2 = Vector2(
		(screen_px.x / viewport_size.x * 2.0 - 1.0) * t * viewport_size.x / viewport_size.y,
		(1.0 - screen_px.y / viewport_size.y * 2.0) * t
	)
	var dir: Vector3 = (res.basis * Vector3(ndc.x, ndc.y, -1.0)).normalized()
	if absf(dir.y) < 0.000001:
		return res.position
	return res.position + dir * ((ground_y - res.position.y) / dir.y)


static func _project(point: Vector3, origin: Vector3, basis: Basis, size: Vector2, fov_deg: float) -> Vector2:
	var q: Vector3 = basis.inverse() * (point - origin)
	var depth: float = maxf(-q.z, 0.001)
	var t: float = tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(
		size.x * 0.5 * (1.0 + q.x / (depth * t * size.x / size.y)),
		size.y * 0.5 * (1.0 - q.y / (depth * t))
	)


## The position for distance `d` from the rectangle centre, shifted along the camera's up vector until the projected rectangle is
## centred in the band (the shift converges in a few steps: the screen offset of the centre changes almost linearly with it).
static func _placed(
	corners: Array[Vector3], centre: Vector3, basis: Basis, d: float, size: Vector2, band_centre: float, fov_deg: float
) -> Vector3:
	var look: Vector3 = basis * Vector3.FORWARD
	var up: Vector3 = basis * Vector3.UP
	var shift: float = 0.0
	var origin: Vector3 = centre - look * d
	for _i: int in 12:
		origin = centre - look * d + up * shift
		var lo: float = INF
		var hi: float = -INF
		for c: Vector3 in corners:
			var y: float = _project(c, origin, basis, size, fov_deg).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var metres_per_px: float = 2.0 * d * tan(deg_to_rad(fov_deg) * 0.5) / size.y
		shift -= ((lo + hi) * 0.5 - band_centre) * metres_per_px  # content too high on screen: raise the camera
	return origin
