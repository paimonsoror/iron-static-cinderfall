class_name CameraFit
extends RefCounted
## Pure camera math, unit-tested without a renderer (ARCH 8, GDD 4.1).
##
## `solve` fits the playable rectangle plus the outer ends of the spawn regions (plus `frame_margin_m` on every
## side) into the band between `top_px` and `viewport_h - bottom_px`, centered in that band, at the largest scale
## that fits both the width and the band height. Works for any yaw; pitch is clamped to the allowed 55..65 degrees.
## `project` and `unproject_ground` are the same math the rig uses, so tests can check it without a Camera3D.

const CAMERA_DISTANCE: float = 60.0
const PITCH_MIN_DEG: float = 55.0
const PITCH_MAX_DEG: float = 65.0


## The pitch actually used: the arena's `pitch_down_deg` clamped to the allowed band.
static func effective_pitch_deg(arena: ArenaDef) -> float:
	return clampf(arena.pitch_down_deg, PITCH_MIN_DEG, PITCH_MAX_DEG)


## Ground rectangle that must be visible: playable bounds united with the spawn region ends, as
## Vector4(min_x, min_z, max_x, max_z).
static func fit_rect(arena: ArenaDef) -> Vector4:
	var min_x: float = arena.min_x
	var max_x: float = arena.max_x
	var min_z: float = arena.min_z
	var max_z: float = arena.max_z
	for r: SpawnRegionDef in arena.spawn_regions:
		min_x = minf(min_x, minf(r.x0, r.x1))
		max_x = maxf(max_x, maxf(r.x0, r.x1))
		min_z = minf(min_z, minf(r.z0, r.z1))
		max_z = maxf(max_z, maxf(r.z0, r.z1))
	return Vector4(min_x, min_z, max_x, max_z)


static func solve(arena: ArenaDef, viewport_size: Vector2, top_px: float, bottom_px: float) -> CameraFitResult:
	var pitch: float = deg_to_rad(effective_pitch_deg(arena))
	var basis: Basis = Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.UP, deg_to_rad(arena.yaw_deg))
	var right: Vector3 = basis * Vector3.RIGHT
	var up: Vector3 = basis * Vector3.UP
	var look: Vector3 = basis * Vector3.FORWARD

	var rect: Vector4 = fit_rect(arena)
	var m: float = arena.frame_margin_m
	var x0: float = rect.x - m
	var z0: float = rect.y - m
	var x1: float = rect.z + m
	var z1: float = rect.w + m
	var corners: Array[Vector3] = [
		Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1)
	]
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for c: Vector3 in corners:
		var cam_xy: Vector2 = Vector2(c.dot(right), c.dot(up))
		lo = Vector2(minf(lo.x, cam_xy.x), minf(lo.y, cam_xy.y))
		hi = Vector2(maxf(hi.x, cam_xy.x), maxf(hi.y, cam_xy.y))
	var need_w: float = maxf(hi.x - lo.x, 0.001)
	var need_h: float = maxf(hi.y - lo.y, 0.001)

	var band_h: float = maxf(1.0, viewport_size.y - top_px - bottom_px)
	var ppm: float = minf(viewport_size.x / need_w, band_h / need_h)

	var res: CameraFitResult = CameraFitResult.new()
	res.px_per_meter = ppm
	res.ortho_size = viewport_size.y / ppm
	res.basis = basis
	var center: Vector3 = Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	# The rectangle's center must land in the middle of the band, not in the middle of the screen.
	var band_center_px: float = top_px + band_h * 0.5
	var shift_m: float = (band_center_px - viewport_size.y * 0.5) / ppm
	res.position = center - look * CAMERA_DISTANCE + up * shift_m
	return res


## Screen position in pixels (origin top-left, y down) of a world point under a solved fit.
static func project(res: CameraFitResult, viewport_size: Vector2, world: Vector3) -> Vector2:
	var cam: Vector3 = res.basis.inverse() * (world - res.position)
	return Vector2(
		viewport_size.x * 0.5 + cam.x * res.px_per_meter,
		viewport_size.y * 0.5 - cam.y * res.px_per_meter
	)


## The world point at height `ground_y` that projects to `screen_px` (inverse of `project` on a horizontal plane).
static func unproject_ground(
	res: CameraFitResult, viewport_size: Vector2, screen_px: Vector2, ground_y: float = 0.0
) -> Vector3:
	var cam_x: float = (screen_px.x - viewport_size.x * 0.5) / res.px_per_meter
	var cam_y: float = (viewport_size.y * 0.5 - screen_px.y) / res.px_per_meter
	var origin: Vector3 = res.position + res.basis * Vector3(cam_x, cam_y, 0.0)
	var dir: Vector3 = res.basis * Vector3.FORWARD
	if absf(dir.y) < 0.000001:
		return origin
	var t: float = (ground_y - origin.y) / dir.y
	return origin + dir * t
