class_name EnvCamStudy
extends RefCounted
## Camera study of the look-dev sandbox (W3-E; sandbox only, nothing here ships): the same scene at another pitch, orthographic or with a
## perspective camera of a narrow field of view, fitted into the same HUD band as the game camera (CameraFit.solve) so the candidates are
## comparable. `--cam-pitch=<degrees>` and `--cam-persp=<fov degrees>` (0 = orthographic). The game's CameraFit clamps the pitch to 55..65
## degrees; this solver does not, and it never touches data/ or the rig's state (it only sets the transform of the camera it is given).


## Places `cam` so the playable rectangle and the spawn ends (plus the frame margin) fill the band between `top_px` and
## `size.y - bottom_px`. `fov_deg` <= 0: orthographic; otherwise a perspective camera with that vertical field of view.
static func apply(cam: Camera3D, arena: ArenaDef, size: Vector2, top_px: float, bottom_px: float, pitch_deg: float, fov_deg: float) -> void:
	var pitch: float = deg_to_rad(pitch_deg)
	var basis: Basis = Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.UP, deg_to_rad(arena.yaw_deg))
	var corners: Array[Vector3] = _corners(arena)
	var centre: Vector3 = _centre(corners)
	var look: Vector3 = basis * Vector3.FORWARD
	var up: Vector3 = basis * Vector3.UP
	var band_h: float = maxf(1.0, size.y - top_px - bottom_px)
	var band_centre: float = top_px + band_h * 0.5
	if fov_deg <= 0.0:
		var right: Vector3 = basis * Vector3.RIGHT
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		for c: Vector3 in corners:
			var p: Vector2 = Vector2(c.dot(right), c.dot(up))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var ppm: float = minf(size.x / maxf(hi.x - lo.x, 0.001), band_h / maxf(hi.y - lo.y, 0.001))
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = size.y / ppm
		var shift: float = (band_centre - size.y * 0.5) / ppm
		cam.transform = Transform3D(basis, centre - look * CameraFit.CAMERA_DISTANCE + up * shift)
		return
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = fov_deg
	cam.near = 0.5
	cam.far = 400.0
	var best: float = _solve_distance(corners, centre, basis, size, band_h, band_centre, fov_deg)
	cam.transform = Transform3D(basis, _placed(corners, centre, basis, best, size, band_centre, fov_deg))


## Screen position (pixels) of a ground or air point seen by a perspective camera at `origin` (pinhole model, KEEP_HEIGHT).
static func project_persp(point: Vector3, origin: Vector3, basis: Basis, size: Vector2, fov_deg: float) -> Vector2:
	var q: Vector3 = basis.inverse() * (point - origin)
	var depth: float = maxf(-q.z, 0.001)
	var t: float = tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(size.x * 0.5 * (1.0 + q.x / (depth * t * size.x / size.y)), size.y * 0.5 * (1.0 - q.y / (depth * t)))


static func _corners(arena: ArenaDef) -> Array[Vector3]:
	var r: Vector4 = CameraFit.fit_rect(arena)
	var m: float = arena.frame_margin_m
	return [
		Vector3(r.x - m, 0.0, r.y - m), Vector3(r.z + m, 0.0, r.y - m),
		Vector3(r.z + m, 0.0, r.w + m), Vector3(r.x - m, 0.0, r.w + m),
	]


static func _centre(corners: Array[Vector3]) -> Vector3:
	return (corners[0] + corners[2]) * 0.5


## The camera position for distance `d` from the rectangle centre, shifted along the camera's up vector until the projected
## rectangle is centred in the band.
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
			var y: float = project_persp(c, origin, basis, size, fov_deg).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var err_px: float = (lo + hi) * 0.5 - band_centre
		var metres_per_px: float = 2.0 * d * tan(deg_to_rad(fov_deg) * 0.5) / size.y
		shift -= err_px * metres_per_px  # content too high on screen (err < 0): raise the camera
	return origin


## The smallest distance at which the rectangle still fits both the width and the band (bisection; the fit is monotonic).
static func _solve_distance(
	corners: Array[Vector3], centre: Vector3, basis: Basis, size: Vector2, band_h: float, band_centre: float, fov_deg: float
) -> float:
	var lo_d: float = 8.0
	var hi_d: float = 500.0
	for _i: int in 40:
		var mid: float = (lo_d + hi_d) * 0.5
		var origin: Vector3 = _placed(corners, centre, basis, mid, size, band_centre, fov_deg)
		var x0: float = INF
		var x1: float = -INF
		var y0: float = INF
		var y1: float = -INF
		for c: Vector3 in corners:
			var p: Vector2 = project_persp(c, origin, basis, size, fov_deg)
			x0 = minf(x0, p.x)
			x1 = maxf(x1, p.x)
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		if x1 - x0 <= size.x and y1 - y0 <= band_h:
			hi_d = mid
		else:
			lo_d = mid
	return hi_d


## One line of numbers about what `cam` shows of the sim `world` (the camera study table): the arena corners on screen, the size of the
## Warden and the core, and how many of the living enemies can be told apart (their discs are not more than half covered by nearer ones).
static func report(cam: Camera3D, arena: ArenaDef, size: Vector2, top_px: float, bottom_px: float, world: SimWorld) -> String:
	var r: Vector4 = CameraFit.fit_rect(arena)
	var near_l: Vector2 = cam.unproject_position(Vector3(arena.min_x, 0.0, arena.max_z))
	var near_r: Vector2 = cam.unproject_position(Vector3(arena.max_x, 0.0, arena.max_z))
	var far_l: Vector2 = cam.unproject_position(Vector3(arena.min_x, 0.0, arena.min_z))
	var far_r: Vector2 = cam.unproject_position(Vector3(arena.max_x, 0.0, arena.min_z))
	var spawn_far: Vector2 = cam.unproject_position(Vector3((r.x + r.z) * 0.5, 0.0, r.y))
	var warden: Vector2 = cam.unproject_position(Vector3(arena.warden_x, 1.0, arena.warden_z))
	var warden_w: float = (cam.unproject_position(Vector3(arena.warden_x + 0.6, 1.0, arena.warden_z)) - warden).length() * 2.0
	var core_w: float = (cam.unproject_position(Vector3(arena.core_x + arena.core_radius, 0.5, arena.core_z)) - cam.unproject_position(Vector3(arena.core_x - arena.core_radius, 0.5, arena.core_z))).length()
	var bases: PackedVector2Array = PackedVector2Array()
	var tops: PackedVector2Array = PackedVector2Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var depth: PackedFloat32Array = PackedFloat32Array()
	var es: EnemyStore = world.enemies
	for i: int in es.high_water:
		if es.alive[i] != 1:
			continue
		var at: Vector3 = Vector3(es.x[i], 0.0, es.z[i])
		var b: Vector2 = cam.unproject_position(at)
		bases.append(b)
		tops.append(cam.unproject_position(at + Vector3(0.0, 1.0, 0.0)))
		radii.append((cam.unproject_position(at + Vector3(0.4, 0.0, 0.0)) - b).length())
		depth.append(es.z[i])
	var seen_sum: float = 0.0
	var tell_apart: int = 0
	var clear: int = 0
	var in_band: int = 0
	var mean_r: float = 0.0
	for i: int in bases.size():
		mean_r += radii[i]
		if bases[i].y >= top_px and bases[i].y <= size.y - bottom_px:
			in_band += 1
		var covered: int = 0
		for f: float in [0.2, 0.5, 0.8]:
			var centre: Vector2 = bases[i].lerp(tops[i], f)
			for off: float in [-0.7, 0.0, 0.7]:
				var s: Vector2 = centre + Vector2(off * radii[i], 0.0)
				for j: int in bases.size():
					if j != i and depth[j] > depth[i] + 0.05:
						var seg: Vector2 = Geometry2D.get_closest_point_to_segment(s, bases[j], tops[j])
						if s.distance_to(seg) < radii[j]:
							covered += 1
							break
		var vis: float = 1.0 - float(covered) / 9.0
		seen_sum += vis
		if vis >= 0.5:
			tell_apart += 1
		if vis >= 0.8:
			clear += 1
	mean_r = mean_r / maxf(1.0, float(bases.size()))
	return "arena_near=%.0f..%.0f far=%.0f..%.0f arena_y=%.0f..%.0f arena_h=%.0f warden_px=%.0f core_px=%.0f spawn_far_y=%.0f enemies=%d in_band=%d enemy_px=%.0f tell_apart=%d clear=%d visible=%.2f" % [
		near_l.x, near_r.x, far_l.x, far_r.x, far_l.y, near_l.y, near_l.y - far_l.y, warden_w, core_w, spawn_far.y, bases.size(), in_band,
		mean_r * 2.0, tell_apart, clear, seen_sum / maxf(1.0, float(bases.size()))
	]
