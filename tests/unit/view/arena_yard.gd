extends GdUnitTestSuite
## V4-X yard props of the events (SPEC 7.1, 12.2, 13.6; GDD 12.3): two faint rail lines, the fuel drums read from the sim, the freight car that crosses
## in 1.2 s on the lane the warning showed.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _steps(vfx: VfxLayer, n: int, dt: float = 0.1) -> void:
	for _k: int in n:
		vfx.render(1.0, dt)


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func test_the_rails_are_two_faint_lines_of_the_arena_data_and_the_legacy_yard_has_none() -> void:
	var arena: ArenaDef = TestContent.variety().arena
	var mesh: ArrayMesh = RailLines.build(arena)
	assert_object(mesh).is_not_null()
	assert_object(RailLines.build(TestContent.baseline().arena)).is_null()  # the legacy yard is untouched
	assert_int(VfxMeshes.triangles(mesh)).is_between(100, 1500)
	var verts: PackedVector3Array = PackedVector3Array()
	for s: int in mesh.get_surface_count():
		var part: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		verts.append_array(part)
	for p: Vector3 in verts:
		assert_float(p.y).is_between(0.0, 0.03)  # flat on the ground
		var on_a_line: bool = false
		for k: int in arena.rail_z.size():
			if absf(p.z - arena.rail_z[k]) <= RailLines.SLEEPER_LENGTH_M * 0.5 + 0.001:
				on_a_line = true
		assert_bool(on_a_line).override_failure_message("a rail vertex off the lines at %s" % p).is_true()
	for k: int in arena.rail_z.size():
		assert_float(arena.rail_z[k]).is_equal(RailLines.nearest_z(arena, arena.rail_z[k] + 0.4))
	var materials: Array[StringName] = []
	for s: int in mesh.get_surface_count():
		materials.append(StringName(mesh.surface_get_material(s).resource_name))
	for id: StringName in materials:
		assert_bool([&"steel_grey", &"dark_frame"].has(id)).is_true()  # palette materials only
	var ground: float = _luma(MatLib.mat(&"concrete").albedo_color)
	assert_float(absf(_luma(MatLib.mat(&"steel_grey").albedo_color) - ground)).is_less(0.2)  # low contrast against the concrete (GDD 12.3)


func test_the_yard_gets_its_rails_on_variety_content_and_stays_inside_the_node_budget() -> void:
	var content: ContentSet = TestContent.variety()
	var view: ArenaView = auto_free(ArenaView.new())
	view.setup(content.arena, content.tokens)
	assert_object(view.get_node_or_null("Rails")).is_not_null()
	assert_int(view.node_count()).is_between(15, 60)
	var legacy: ContentSet = TestContent.baseline()
	var old: ArenaView = auto_free(ArenaView.new())
	old.setup(legacy.arena, legacy.tokens)
	assert_object(old.get_node_or_null("Rails")).is_null()
	assert_int(view.node_count() - old.node_count()).is_between(0, 2)


func test_drums_are_the_living_drums_of_the_sim_and_nothing_else() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var drums: DrumView = vfx.chaos().drums
	var arena: ArenaDef = w.content.arena
	assert_int(arena.drum_points.size()).is_equal(6)
	vfx.render(1.0, 0.016)
	assert_int(drums.drum_count()).is_equal(0)  # none placed yet
	w.hazards.d_point = PackedInt32Array([0, 3, 5])
	w.hazards.d_alive = PackedInt32Array([1, 1, 1])
	vfx.render(1.0, 0.016)
	assert_int(drums.drum_count()).is_equal(3)  # three per act (CONTENT 6)
	assert_float(drums.drum_position(1).x).is_equal_approx(arena.drum_points[3].x, 0.001)
	assert_float(drums.drum_position(1).z).is_equal_approx(arena.drum_points[3].y, 0.001)
	w.hazards.d_alive[1] = 0  # one went off
	vfx.render(1.0, 0.016)
	assert_int(drums.drum_count()).is_equal(2)
	w.hazards.d_point = PackedInt32Array([0, 99])  # a point the arena does not have is never drawn
	w.hazards.d_alive = PackedInt32Array([1, 1])
	vfx.render(1.0, 0.016)
	assert_int(drums.drum_count()).is_equal(1)
	vfx.unbind()
	assert_int(drums.drum_count()).is_equal(0)


func test_a_drum_is_a_small_unlit_barrel_in_one_multimesh() -> void:
	var drums: DrumView = VfxXTestKit.rig(self).vfx.chaos().drums
	assert_int(VfxXTestKit.triangles_of(drums.node)).is_less_equal(80)  # SPEC 12.2
	assert_int(drums.node.multimesh.instance_count).is_equal(DrumView.MAX)
	assert_bool(drums.node.multimesh.use_custom_data).is_false()  # transform-only: per-instance data is unreliable on a PowerVR phone
	var mesh: Mesh = drums.node.multimesh.mesh
	for s: int in mesh.get_surface_count():
		assert_bool((mesh.surface_get_material(s) as StandardMaterial3D).emission_enabled).is_false()  # nothing but an optic glows on that side


func test_the_freight_car_is_hidden_until_a_freight_event_and_is_a_dead_boxcar() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var freight: FreightView = vfx.chaos().freight
	assert_bool(freight.car.visible).is_false()
	assert_int(VfxXTestKit.triangles_of(freight.car)).is_less_equal(600)  # SPEC 12.2
	assert_int(freight.car.mesh.get_surface_count()).is_less_equal(5)
	for s: int in freight.car.mesh.get_surface_count():
		assert_bool((freight.car.mesh.surface_get_material(s) as StandardMaterial3D).emission_enabled).is_false()
	Events.event_started.emit(&"deadfall_strike")
	assert_bool(freight.car.visible).is_false()  # only the freight events launch it


func test_the_car_crosses_the_lane_of_the_warning_right_to_left_in_one_and_a_fifth_seconds() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var arena: ArenaDef = rig.world.content.arena
	var freight: FreightView = vfx.chaos().freight
	Events.event_warned.emit(&"runaway_freight", 240, 0.0, 10.0)
	assert_float(freight.lane_z()).is_equal(arena.rail_z[1])
	Events.event_started.emit(&"runaway_freight")
	assert_bool(freight.running()).is_true()
	assert_bool(freight.car.visible).is_true()
	assert_float(freight.car.position.z).is_equal(arena.rail_z[1])
	assert_float(freight.car.position.x).is_greater(arena.max_x)  # it starts beyond the right edge
	var x0: float = freight.car.position.x
	_steps(vfx, 6)  # 0.6 s: halfway
	assert_float(freight.progress()).is_between(0.4, 0.6)
	assert_float(freight.car.position.x).is_less(x0)
	assert_float(freight.car.position.x).is_between(arena.min_x, arena.max_x)  # mid-crossing it is in the yard
	_steps(vfx, 7)
	assert_bool(freight.running()).is_false()
	assert_bool(freight.car.visible).is_false()
	assert_int(freight.crossings).is_equal(1)


func test_two_events_that_name_the_car_launch_one_car_and_the_player_call_works_too() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var freight: FreightView = vfx.chaos().freight
	Events.event_started.emit(&"freight_call")
	Events.event_started.emit(&"runaway_freight")  # the same crossing named twice
	assert_int(freight.crossings).is_equal(1)
	_steps(vfx, 20)
	assert_bool(freight.running()).is_false()
	Events.event_started.emit(&"runaway_freight")  # a later one is a new car
	assert_int(freight.crossings).is_equal(2)


func test_the_wake_throws_sparks_by_tier_and_the_pass_shakes_the_camera() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var freight: FreightView = vfx.chaos().freight
	var cos: FxCosmetic = vfx.chaos().cosmetic
	var seen: Array[int] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		_steps(vfx, 30)
		Events.event_started.emit(&"runaway_freight")
		if t != VisualQuality.Tier.LOW:
			assert_float(cos.trauma).is_greater(0.0)  # a freight car passing shakes the yard
		var peak: int = 0
		for _n: int in 14:
			vfx.render(1.0, 0.1)
			peak = maxi(peak, vfx.spark_count())
		seen.append(peak)
		assert_bool(freight.running()).is_false()
	assert_int(seen[0]).is_equal(0)  # none on LOW
	assert_int(seen[1]).is_greater(0)
	assert_int(seen[2]).is_greater_equal(seen[1])  # thin on MID, steady on HIGH
	vfx.set_reduced_flash(true)
	_steps(vfx, 30)
	Events.event_started.emit(&"runaway_freight")
	assert_float(cos.trauma).is_equal(0.0)  # Reduced Flash: no shake at all
	assert_bool(freight.running()).is_true()  # ... but the car itself is information and stays
