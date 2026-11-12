extends GdUnitTestSuite
## CameraRig: a perspective KEEP_HEIGHT camera at the arena pitch, fitted by CameraFit, whose pure world_to_screen
## agrees with Godot's own Camera3D projection.

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()


func _rig() -> CameraRig:
	var rig: CameraRig = auto_free(CameraRig.new())
	rig.setup(_content.arena, _content.tokens)
	return rig


func test_setup_builds_a_perspective_keep_height_camera() -> void:
	var rig: CameraRig = _rig()
	assert_object(rig.camera).is_not_null()
	assert_int(rig.camera.projection).is_equal(Camera3D.PROJECTION_PERSPECTIVE)
	assert_float(rig.camera.fov).is_equal(CameraFit.FOV_DEG)
	assert_int(rig.camera.keep_aspect).is_equal(Camera3D.KEEP_HEIGHT)
	assert_float(rig.pitch_down_deg()).is_between(55.0, 65.0)
	assert_float(rig.pitch_down_deg()).is_equal(_content.arena.pitch_down_deg)


func test_fit_matches_the_pure_solution() -> void:
	var rig: CameraRig = _rig()
	var size: Vector2 = Vector2(1080.0, 2340.0)
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, _content.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, _content.tokens)
	rig.fit(size, top, bottom)
	var res: CameraFitResult = CameraFit.solve(_content.arena, size, top, bottom)
	assert_float(rig.camera.size).is_equal_approx(res.ortho_size, 0.0001)
	assert_float(rig.px_per_meter()).is_equal_approx(res.px_per_meter, 0.0001)
	assert_vector(rig.camera.position).is_equal_approx(res.position, Vector3(0.001, 0.001, 0.001))
	var pitch: float = rad_to_deg(asin(-(rig.camera.basis * Vector3.FORWARD).y))
	assert_float(pitch).is_equal_approx(_content.arena.pitch_down_deg, 0.001)


func test_world_to_screen_agrees_with_the_real_camera() -> void:
	var rig: CameraRig = _rig()
	var size: Vector2i = Vector2i(1080, 2400)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	add_child(viewport)
	viewport.add_child(rig)
	var sizef: Vector2 = Vector2(size)
	rig.fit(sizef, sizef.y * 0.11, sizef.y * 0.23)
	for p: Vector3 in [Vector3(0.0, 0.0, 0.0), Vector3(-7.5, 2.0, 3.0), Vector3(9.0, 0.0, -12.0)]:
		var mine: Vector2 = rig.world_to_screen(p)
		var theirs: Vector2 = rig.camera.unproject_position(p)
		assert_float(mine.x).override_failure_message("x for %s: %s vs %s" % [p, mine, theirs]).is_equal_approx(theirs.x, 0.5)
		assert_float(mine.y).override_failure_message("y for %s: %s vs %s" % [p, mine, theirs]).is_equal_approx(theirs.y, 0.5)
	viewport.queue_free()


func test_world_to_screen_round_trips_through_screen_to_ground() -> void:
	var rig: CameraRig = _rig()
	var size: Vector2 = Vector2(1080.0, 1920.0)
	rig.fit(size, size.y * 0.11, size.y * 0.23)
	var p: Vector3 = Vector3(-4.2, 0.0, 6.6)
	var back: Vector3 = rig.screen_to_ground(rig.world_to_screen(p))
	assert_float(back.x).is_equal_approx(p.x, 0.001)
	assert_float(back.z).is_equal_approx(p.z, 0.001)


func test_refit_follows_the_viewport_without_a_new_camera() -> void:
	var rig: CameraRig = _rig()
	var camera_before: Camera3D = rig.camera
	rig.fit(Vector2(1080.0, 2400.0), 264.0, 552.0)
	var tall: float = rig.px_per_meter()
	rig.fit(Vector2(1080.0, 1120.0), 123.0, 258.0)
	var squat: float = rig.px_per_meter()
	assert_object(rig.camera).is_same(camera_before)
	assert_float(squat).is_less(tall)
	assert_float(squat).is_greater(20.0)
