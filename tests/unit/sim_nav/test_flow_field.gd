extends GdUnitTestSuite
## ArenaGrid and FlowField on the frozen baseline arena (ARCH 5.2, 6.6).


func _arena() -> ArenaDef:
	return TestContent.baseline().arena


func _blocked_count(g: ArenaGrid) -> int:
	var n: int = 0
	for c: int in g.blocked.size():
		n += g.blocked[c]
	return n


func _step_of(dx: float, dz: float) -> Vector2i:
	return Vector2i(0 if absf(dx) < 0.3 else (1 if dx > 0.0 else -1), 0 if absf(dz) < 0.3 else (1 if dz > 0.0 else -1))


func test_grid_covers_the_bounds_plus_margin() -> void:
	var g: ArenaGrid = ArenaGrid.build(_arena(), 0.5)
	assert_int(g.cols).is_equal(24)
	assert_int(g.rows).is_equal(32)
	assert_float(g.origin_x).is_equal(-12.0)
	assert_float(g.origin_z).is_equal(-18.0)
	assert_float(g.cell_m).is_equal(1.0)
	assert_int(g.blocked.size()).is_equal(24 * 32)


func test_grid_blocks_exactly_the_cells_inside_inflated_obstacles() -> void:
	var arena: ArenaDef = _arena()
	var g: ArenaGrid = ArenaGrid.build(arena, 0.5)
	var blocked_cells: int = 0
	for c: int in g.cols * g.rows:
		var p: Vector2 = g.cell_center(c)
		var expected: bool = false
		for o: ObstacleDef in arena.obstacles:
			if o.contains(p.x, p.y, 0.5):
				expected = true
		assert_bool(g.blocked[c] == 1).is_equal(expected)
		blocked_cells += g.blocked[c]
	assert_int(blocked_cells).is_greater(8)
	for o: ObstacleDef in arena.obstacles:
		assert_int(g.blocked[g.cell_of(o.x, o.z)]).is_equal(1)
	assert_int(g.blocked[g.cell_of(arena.core_x + 4.0, arena.core_z)]).is_equal(0)


func test_inflation_grows_the_blocked_set() -> void:
	var arena: ArenaDef = _arena()
	var small: int = _blocked_count(ArenaGrid.build(arena, 0.0))
	var big: int = _blocked_count(ArenaGrid.build(arena, 1.5))
	assert_int(big).is_greater(small)


func test_cell_of_clamps_and_cell_center_round_trips() -> void:
	var g: ArenaGrid = ArenaGrid.build(_arena(), 0.5)
	assert_int(g.cell_of(-500.0, -500.0)).is_equal(0)
	assert_int(g.cell_of(500.0, 500.0)).is_equal(g.cols * g.rows - 1)
	assert_int(g.cell_of(500.0, -500.0)).is_equal(g.cols - 1)
	for c: int in [0, 5, 100, 400, g.cols * g.rows - 1]:
		var p: Vector2 = g.cell_center(c)
		assert_int(g.cell_of(p.x, p.y)).is_equal(c)


func test_every_spawn_region_cell_is_reachable() -> void:
	var arena: ArenaDef = _arena()
	var f: FlowField = FlowField.build(arena)
	assert_int(f.unreachable_spawn_cells(arena)).is_equal(0)
	for r: SpawnRegionDef in arena.spawn_regions:
		for s: int in 41:
			var t: float = float(s) / 40.0
			var c: float = f.sample_cost(r.x0 + (r.x1 - r.x0) * t, r.z0 + (r.z1 - r.z0) * t)
			assert_bool(is_finite(c)).is_true()
			assert_float(c).is_greater(0.0)


func test_a_sealed_spawn_region_is_reported() -> void:
	var content: ContentSet = TestContent.baseline()
	var wall: ObstacleDef = ObstacleDef.new()
	wall.id = &"test_wall"
	wall.shape = ObstacleDef.Shape.BOX
	wall.x = 9.5
	wall.z = -2.0
	wall.size_x = 0.8
	wall.size_z = 40.0
	content.arena.obstacles.append(wall)
	var f: FlowField = FlowField.build(content.arena)
	assert_int(f.unreachable_spawn_cells(content.arena)).is_greater(0)
	assert_bool(is_inf(f.sample_cost(10.8, 3.0))).is_true()


func test_directions_point_downhill() -> void:
	var f: FlowField = FlowField.build(_arena())
	var g: ArenaGrid = f.grid
	var checked: int = 0
	for c: int in g.cols * g.rows:
		if g.blocked[c] == 1 or is_inf(f.cost[c]) or f.cost[c] == 0.0:
			continue
		var step: Vector2i = _step_of(f.dir_x[c], f.dir_z[c])
		assert_bool(step != Vector2i.ZERO).is_true()
		var cz: int = floori(float(c) / float(g.cols))
		var cx: int = c - cz * g.cols
		var n: int = (cz + step.y) * g.cols + cx + step.x
		assert_float(f.cost[n]).is_less(f.cost[c])
		assert_float(Vector2(f.dir_x[c], f.dir_z[c]).length()).is_equal_approx(1.0, 0.0001)
		checked += 1
	assert_int(checked).is_greater(300)


func test_blocked_cells_are_never_entered_and_corners_are_not_cut() -> void:
	var f: FlowField = FlowField.build(_arena())
	var g: ArenaGrid = f.grid
	for c: int in g.cols * g.rows:
		if g.blocked[c] == 1:
			assert_float(f.dir_x[c]).is_equal(0.0)
			assert_float(f.dir_z[c]).is_equal(0.0)
			assert_bool(is_inf(f.cost[c])).is_true()
			continue
		if is_inf(f.cost[c]) or f.cost[c] == 0.0:
			continue
		var step: Vector2i = _step_of(f.dir_x[c], f.dir_z[c])
		var cz: int = floori(float(c) / float(g.cols))
		var cx: int = c - cz * g.cols
		assert_int(g.blocked[(cz + step.y) * g.cols + cx + step.x]).is_equal(0)
		if step.x != 0 and step.y != 0:
			assert_int(g.blocked[cz * g.cols + cx + step.x]).is_equal(0)
			assert_int(g.blocked[(cz + step.y) * g.cols + cx]).is_equal(0)


func test_goal_cells_cost_zero_and_point_at_the_core() -> void:
	var arena: ArenaDef = _arena()
	var f: FlowField = FlowField.build(arena)
	var g: ArenaGrid = f.grid
	var goals: int = 0
	for c: int in g.cols * g.rows:
		var p: Vector2 = g.cell_center(c)
		var d: float = Vector2(p.x - arena.core_x, p.y - arena.core_z).length()
		if g.blocked[c] == 0 and d <= arena.approach_radius:
			assert_float(f.cost[c]).is_equal(0.0)
			goals += 1
			if d > 0.5:
				var to_core: Vector2 = Vector2(arena.core_x - p.x, arena.core_z - p.y).normalized()
				assert_float(to_core.dot(Vector2(f.dir_x[c], f.dir_z[c]))).is_greater(0.99)
		elif g.blocked[c] == 0:
			assert_float(f.cost[c]).is_greater(0.0)
	assert_int(goals).is_greater(150)


func test_sampling_blends_directions_and_costs() -> void:
	var arena: ArenaDef = _arena()
	var f: FlowField = FlowField.build(arena)
	var far: float = f.sample_cost(10.8, 3.0)
	var mid: float = f.sample_cost(6.0, 3.0)
	var near: float = f.sample_cost(2.0, 3.0)
	assert_float(far).is_greater(mid)
	assert_float(mid).is_greater(near)
	assert_float(far).is_between(8.0, 11.0)
	for p: Vector2 in [Vector2(10.8, 3.0), Vector2(7.3, -2.2), Vector2(2.2, 9.1), Vector2(9.5, -14.0)]:
		var dir: Vector2 = f.sample_dir(p.x, p.y)
		assert_float(dir.length()).is_equal_approx(1.0, 0.001)
		var along: Vector2 = Vector2(arena.core_x - p.x, arena.core_z - p.y).normalized()
		assert_float(dir.dot(along)).is_greater(0.3)
	var inside: Vector2 = f.sample_dir(arena.core_x + 8.0, arena.core_z)
	assert_float(inside.x).is_less(-0.9)
	var wall: Vector2 = f.sample_dir(arena.obstacles[2].x, arena.obstacles[2].z)
	assert_bool(wall.is_finite()).is_true()


func test_following_the_field_from_every_spawn_cell_reaches_the_goal_without_touching_props() -> void:
	var arena: ArenaDef = _arena()
	var f: FlowField = FlowField.build(arena)
	for r: SpawnRegionDef in arena.spawn_regions:
		for s: int in 9:
			var t: float = float(s) / 8.0
			var pos: Vector2 = Vector2(r.x0 + (r.x1 - r.x0) * t, r.z0 + (r.z1 - r.z0) * t)
			var steps: int = 0
			while Vector2(pos.x - arena.core_x, pos.y - arena.core_z).length() > arena.approach_radius and steps < 2000:
				pos += f.sample_dir(pos.x, pos.y) * 0.05
				for o: ObstacleDef in arena.obstacles:
					assert_bool(o.contains(pos.x, pos.y, 0.0)).is_false()
				steps += 1
			assert_int(steps).is_less(2000)


func test_build_is_deterministic() -> void:
	var a: FlowField = FlowField.build(_arena())
	var b: FlowField = FlowField.build(_arena())
	assert_bool(a.cost == b.cost).is_true()
	assert_bool(a.dir_x == b.dir_x).is_true()
	assert_bool(a.dir_z == b.dir_z).is_true()


func test_ascii_dump_shows_blocks_spawns_goal_and_arrows() -> void:
	var f: FlowField = FlowField.build(_arena())
	var text: String = f.to_ascii()
	var lines: PackedStringArray = text.split("\n")
	assert_int(lines.size()).is_equal(1 + 32)
	var body: String = ""
	for k: int in range(1, lines.size()):
		assert_int(lines[k].length()).is_equal(24)
		body += lines[k]
	for glyph: String in ["#", "S", "C", "o", ">", "<", "v", "^"]:
		assert_bool(body.contains(glyph)).is_true()
	assert_bool(body.contains("?")).is_false()
