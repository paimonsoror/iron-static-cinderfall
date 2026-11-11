extends GdUnitTestSuite
## CameraFit (pure math, no renderer): pitch band, the playable rectangle and the spawn ends inside the HUD band on
## every phone aspect and on a near-square screen, minimum scale, projection round trip (A04).

const PHONES: Array[Vector2] = [Vector2(1080.0, 1920.0), Vector2(1080.0, 2340.0), Vector2(1080.0, 2400.0)]
const ALL_SIZES: Array[Vector2] = [
	Vector2(1080.0, 1920.0), Vector2(1080.0, 2340.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 1120.0)
]

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()


func _bands(size: Vector2) -> Vector2:
	var tokens: VisualTokens = _content.tokens
	return Vector2(HudLayout.top_band_px(size, Vector4.ZERO, tokens), HudLayout.bottom_band_px(size, Vector4.ZERO, tokens))


## The four corners of the playable rectangle and both ends of every spawn region (ground level).
func _must_show_points() -> Array[Vector3]:
	var a: ArenaDef = _content.arena
	var pts: Array[Vector3] = [
		Vector3(a.min_x, 0.0, a.min_z), Vector3(a.max_x, 0.0, a.min_z),
		Vector3(a.max_x, 0.0, a.max_z), Vector3(a.min_x, 0.0, a.max_z),
	]
	for r: SpawnRegionDef in a.spawn_regions:
		pts.append(Vector3(r.x0, 0.0, r.z0))
		pts.append(Vector3(r.x1, 0.0, r.z1))
	return pts


func test_pitch_is_inside_the_allowed_band() -> void:
	var a: ArenaDef = _content.arena
	assert_float(CameraFit.effective_pitch_deg(a)).is_between(55.0, 65.0)
	assert_float(CameraFit.effective_pitch_deg(a)).is_equal(a.pitch_down_deg)
	# Out-of-band data is clamped, never used as is.
	var steep: ArenaDef = _content.arena
	var saved: float = steep.pitch_down_deg
	steep.pitch_down_deg = 80.0
	assert_float(CameraFit.effective_pitch_deg(steep)).is_equal(65.0)
	steep.pitch_down_deg = 20.0
	assert_float(CameraFit.effective_pitch_deg(steep)).is_equal(55.0)
	steep.pitch_down_deg = saved


func test_basis_looks_down_by_the_pitch() -> void:
	var res: CameraFitResult = CameraFit.solve(_content.arena, Vector2(1080.0, 2400.0), 264.0, 552.0)
	var look: Vector3 = res.basis * Vector3.FORWARD
	var down_deg: float = rad_to_deg(asin(-look.y))
	assert_float(down_deg).is_equal_approx(_content.arena.pitch_down_deg, 0.001)


func test_all_must_show_points_project_inside_the_band_and_width() -> void:
	for size: Vector2 in ALL_SIZES:
		var bands: Vector2 = _bands(size)
		var res: CameraFitResult = CameraFit.solve(_content.arena, size, bands.x, bands.y)
		for p: Vector3 in _must_show_points():
			var px: Vector2 = CameraFit.project(res, size, p)
			assert_float(px.x).override_failure_message("x of %s at %s" % [p, size]).is_between(0.0, size.x)
			assert_float(px.y).override_failure_message("y of %s at %s: %s" % [p, size, px]).is_between(bands.x, size.y - bands.y)


func test_scale_is_at_least_40_px_per_meter_on_phone_sizes() -> void:
	for size: Vector2 in PHONES:
		var bands: Vector2 = _bands(size)
		var res: CameraFitResult = CameraFit.solve(_content.arena, size, bands.x, bands.y)
		assert_float(res.px_per_meter).override_failure_message("ppm at %s" % size).is_greater_equal(40.0)
		assert_float(res.ortho_size).is_equal_approx(size.y / res.px_per_meter, 0.0001)


func test_arena_center_lands_in_the_middle_of_the_band() -> void:
	for size: Vector2 in ALL_SIZES:
		var bands: Vector2 = _bands(size)
		var res: CameraFitResult = CameraFit.solve(_content.arena, size, bands.x, bands.y)
		var rect: Vector4 = CameraFit.fit_rect(_content.arena)
		var center: Vector3 = Vector3((rect.x + rect.z) * 0.5, 0.0, (rect.y + rect.w) * 0.5)
		var px: Vector2 = CameraFit.project(res, size, center)
		var band_mid: float = bands.x + (size.y - bands.x - bands.y) * 0.5
		assert_float(px.y).is_equal_approx(band_mid, 0.5)
		assert_float(px.x).is_equal_approx(size.x * 0.5, 0.5)


func test_world_to_screen_round_trip() -> void:
	var size: Vector2 = Vector2(1080.0, 2400.0)
	var bands: Vector2 = _bands(size)
	var res: CameraFitResult = CameraFit.solve(_content.arena, size, bands.x, bands.y)
	var samples: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(-7.5, 0.0, 3.0), Vector3(10.8, 0.0, -8.0), Vector3(3.3, 0.0, 11.9),
		Vector3(-10.0, 0.0, -16.0),
	]
	for p: Vector3 in samples:
		var px: Vector2 = CameraFit.project(res, size, p)
		var back: Vector3 = CameraFit.unproject_ground(res, size, px, 0.0)
		assert_float(back.x).is_equal_approx(p.x, 0.001)
		assert_float(back.z).is_equal_approx(p.z, 0.001)
		assert_float(back.y).is_equal_approx(0.0, 0.001)
	# A raised point projects higher on screen (smaller y) than the same ground point.
	var ground_px: Vector2 = CameraFit.project(res, size, Vector3(1.0, 0.0, 2.0))
	var raised_px: Vector2 = CameraFit.project(res, size, Vector3(1.0, 3.0, 2.0))
	assert_float(raised_px.x).is_equal_approx(ground_px.x, 0.001)
	assert_float(raised_px.y).is_less(ground_px.y)


func test_core_is_at_the_left_and_the_spawn_edges_at_the_right_and_top() -> void:
	var size: Vector2 = Vector2(1080.0, 2400.0)
	var bands: Vector2 = _bands(size)
	var a: ArenaDef = _content.arena
	var res: CameraFitResult = CameraFit.solve(a, size, bands.x, bands.y)
	var core_px: Vector2 = CameraFit.project(res, size, Vector3(a.core_x, 0.0, a.core_z))
	var warden_px: Vector2 = CameraFit.project(res, size, Vector3(a.warden_x, 0.0, a.warden_z))
	var right: SpawnRegionDef = a.region(&"right")
	var upper: SpawnRegionDef = a.region(&"upper_right")
	var right_px: Vector2 = CameraFit.project(res, size, Vector3(right.x0, 0.0, (right.z0 + right.z1) * 0.5))
	var upper_px: Vector2 = CameraFit.project(res, size, Vector3((upper.x0 + upper.x1) * 0.5, 0.0, upper.z0))
	assert_float(core_px.x).is_less(size.x * 0.3)
	assert_float(warden_px.x).is_greater(core_px.x)
	assert_float(warden_px.y).is_greater(core_px.y)
	assert_float(right_px.x).is_greater(size.x * 0.9)
	assert_float(upper_px.y).is_less(core_px.y)


func test_fit_also_handles_a_yawed_arena_and_a_tiny_band() -> void:
	var a: ArenaDef = _content.arena
	var saved: float = a.yaw_deg
	a.yaw_deg = 25.0
	var size: Vector2 = Vector2(1080.0, 2400.0)
	var bands: Vector2 = _bands(size)
	var res: CameraFitResult = CameraFit.solve(a, size, bands.x, bands.y)
	for p: Vector3 in _must_show_points():
		var px: Vector2 = CameraFit.project(res, size, p)
		assert_float(px.x).is_between(0.0, size.x)
		assert_float(px.y).is_between(bands.x, size.y - bands.y)
	a.yaw_deg = saved
	# A degenerate band (HUD taller than the screen) must not divide by zero.
	var squeezed: CameraFitResult = CameraFit.solve(a, size, 1500.0, 1500.0)
	assert_bool(is_finite(squeezed.px_per_meter) and squeezed.px_per_meter > 0.0).is_true()
