class_name CameraFit
extends RefCounted
## Pure camera math, unit-tested without a renderer. Wave 0 version: fit the arena bounds plus the ends of
## the spawn regions into the band between `top_px` and `viewport_h - bottom_px`. TODO(W1-E): refine,
## add the pitch/aspect tests, handle decor.

const CAMERA_DISTANCE: float = 60.0


static func solve(arena: ArenaDef, viewport_size: Vector2, top_px: float, bottom_px: float) -> CameraFitResult:
	var pitch: float = deg_to_rad(arena.pitch_down_deg)
	var min_x: float = arena.min_x
	var max_x: float = arena.max_x
	var min_z: float = arena.min_z
	var max_z: float = arena.max_z
	for r: SpawnRegionDef in arena.spawn_regions:
		min_x = minf(min_x, minf(r.x0, r.x1))
		max_x = maxf(max_x, maxf(r.x0, r.x1))
		min_z = minf(min_z, minf(r.z0, r.z1))
		max_z = maxf(max_z, maxf(r.z0, r.z1))
	var margin: float = arena.frame_margin_m
	var width_m: float = (max_x - min_x) + 2.0 * margin
	var depth_m: float = ((max_z - min_z) + 2.0 * margin) * sin(pitch)
	var band_h: float = maxf(1.0, viewport_size.y - top_px - bottom_px)
	var ppm: float = minf(viewport_size.x / width_m, band_h / depth_m)
	var res: CameraFitResult = CameraFitResult.new()
	res.px_per_meter = ppm
	res.ortho_size = viewport_size.y / ppm
	res.basis = Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.UP, deg_to_rad(arena.yaw_deg))
	var look: Vector3 = res.basis * Vector3.FORWARD
	var up: Vector3 = res.basis * Vector3.UP
	var center: Vector3 = Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
	# Shift so the arena center lands in the middle of the band instead of the middle of the screen.
	var band_center_px: float = top_px + band_h * 0.5
	var shift_m: float = (band_center_px - viewport_size.y * 0.5) / ppm
	res.position = center - look * CAMERA_DISTANCE + up * shift_m
	return res
