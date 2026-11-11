extends GdUnitTestSuite
## NavGeometry: pushing a point out of props and line-of-sight tests.


func _arena() -> ArenaDef:
	return TestContent.baseline().arena


func test_a_point_outside_every_prop_is_left_alone() -> void:
	var arena: ArenaDef = _arena()
	var p: Vector2 = NavGeometry.push_out(arena.obstacles, -5.0, 8.0, 0.5)
	assert_float(p.x).is_equal(-5.0)
	assert_float(p.y).is_equal(8.0)


func test_a_point_inside_a_circle_is_pushed_radially_to_its_rim() -> void:
	var arena: ArenaDef = _arena()
	var crates: ObstacleDef = arena.obstacles[2]
	var p: Vector2 = NavGeometry.push_out(arena.obstacles, crates.x + 0.5, crates.z, 0.4)
	assert_float(p.x - crates.x).is_equal_approx(crates.radius + 0.4, 0.0001)
	assert_float(p.y).is_equal_approx(crates.z, 0.0001)
	assert_bool(crates.contains(p.x, p.y, 0.4)).is_false()
	var center: Vector2 = NavGeometry.push_out(arena.obstacles, crates.x, crates.z, 0.0)
	assert_bool(crates.contains(center.x, center.y, 0.0)).is_false()


func test_a_point_inside_a_rotated_box_leaves_by_the_nearest_face() -> void:
	var arena: ArenaDef = _arena()
	var barrier: ObstacleDef = arena.obstacles[0]
	var a: float = deg_to_rad(barrier.rot_deg)
	var normal: Vector2 = Vector2(-sin(a), cos(a))
	var inside: Vector2 = Vector2(barrier.x, barrier.z) + normal * 0.1
	var p: Vector2 = NavGeometry.push_out(arena.obstacles, inside.x, inside.y, 0.3)
	assert_bool(barrier.contains(p.x, p.y, 0.3)).is_false()
	var along: float = (p - Vector2(barrier.x, barrier.z)).dot(Vector2(cos(a), sin(a)))
	assert_float(absf(along)).is_less(0.01)
	var across: float = (p - Vector2(barrier.x, barrier.z)).dot(normal)
	assert_float(absf(across)).is_equal_approx(barrier.size_z * 0.5 + 0.3, 0.001)


func test_pushing_along_a_face_slides_instead_of_sticking() -> void:
	var arena: ArenaDef = _arena()
	var barrier: ObstacleDef = arena.obstacles[0]
	var a: float = deg_to_rad(barrier.rot_deg)
	var along: Vector2 = Vector2(cos(a), sin(a))
	var normal: Vector2 = Vector2(-sin(a), cos(a))
	var base: Vector2 = Vector2(barrier.x, barrier.z) + normal * (barrier.size_z * 0.5 + 0.3 + 0.02)
	var moved: Vector2 = base + along * 0.5 - normal * 0.1
	var p: Vector2 = NavGeometry.push_out(arena.obstacles, moved.x, moved.y, 0.3)
	assert_float((p - base).dot(along)).is_equal_approx(0.5, 0.01)
	assert_bool(barrier.contains(p.x, p.y, 0.3)).is_false()


func test_inside_any_follows_contains() -> void:
	var arena: ArenaDef = _arena()
	assert_bool(NavGeometry.inside_any(arena.obstacles, 4.5, 0.5, 0.0)).is_true()
	assert_bool(NavGeometry.inside_any(arena.obstacles, 4.5, 3.0, 0.0)).is_false()
	assert_bool(NavGeometry.inside_any(arena.obstacles, 4.5, 3.0, 1.5)).is_true()


func test_segment_clear_sees_circles_and_rotated_boxes() -> void:
	var arena: ArenaDef = _arena()
	assert_bool(NavGeometry.segment_clear(arena.obstacles, 10.0, 3.0, -7.5, 3.0, 0.4)).is_true()
	assert_bool(NavGeometry.segment_clear(arena.obstacles, 10.0, 0.5, -7.5, 0.5, 0.0)).is_false()
	assert_bool(NavGeometry.segment_clear(arena.obstacles, 10.0, 0.5, 6.0, 0.5, 0.0)).is_true()
	var barrier: ObstacleDef = arena.obstacles[0]
	assert_bool(NavGeometry.segment_clear(arena.obstacles, barrier.x - 3.0, barrier.z - 3.0, barrier.x + 3.0, barrier.z + 3.0, 0.0)).is_false()
	assert_bool(NavGeometry.segment_clear(arena.obstacles, barrier.x + 4.0, barrier.z - 3.0, barrier.x + 4.0, barrier.z + 3.0, 0.0)).is_true()


func test_clearance_widens_the_line_of_sight_test() -> void:
	var arena: ArenaDef = _arena()
	var crates: ObstacleDef = arena.obstacles[2]
	var z: float = crates.z + crates.radius + 0.2
	assert_bool(NavGeometry.segment_clear(arena.obstacles, 9.0, z, 0.0, z, 0.0)).is_true()
	assert_bool(NavGeometry.segment_clear(arena.obstacles, 9.0, z, 0.0, z, 0.5)).is_false()


func test_segment_clear_agrees_with_dense_sampling() -> void:
	var arena: ArenaDef = _arena()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for n: int in 200:
		var a: Vector2 = Vector2(rng.randf_range(-6.0, 10.0), rng.randf_range(-12.0, 10.0))
		var b: Vector2 = Vector2(rng.randf_range(-6.0, 10.0), rng.randf_range(-12.0, 10.0))
		var clearance: float = rng.randf_range(0.0, 0.8)
		var hit: bool = false
		for s: int in 401:
			var p: Vector2 = a.lerp(b, float(s) / 400.0)
			if NavGeometry.inside_any(arena.obstacles, p.x, p.y, clearance):
				hit = true
				break
		var clear: bool = NavGeometry.segment_clear(arena.obstacles, a.x, a.y, b.x, b.y, clearance)
		if hit:
			assert_bool(clear).is_false()
		var length: float = a.distance_to(b)
		if clear:
			assert_bool(hit).is_false()
		elif not hit:
			## the exact test may catch a graze between samples (spacing length / 400)
			assert_float(length).is_greater(5.0)
