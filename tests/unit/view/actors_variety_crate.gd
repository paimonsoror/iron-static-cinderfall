extends GdUnitTestSuite
## V2-F: the salvage crate and its progress ring (VARIETY_SPEC 3.4): shown while the sim has a crate on the field, dropped in on
## landing, a ring that fills with the secure timer and turns red while it stalls, one transform-only MultiMesh, nothing allocated.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func _rig() -> Array:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	return [w, layer, layer.crate]


func test_the_crate_is_shown_only_while_the_sim_has_one_on_the_field() -> void:
	var rig: Array = _rig()
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	layer.render(1.0, 0.016)
	assert_bool(crate.is_crate_visible()).is_false()
	assert_bool(crate.crate_position().is_finite()).is_false()
	w.salvage.crate_active = true
	w.salvage.crate_x = 5.5
	w.salvage.crate_z = 3.5
	layer.render(1.0, 0.016)
	assert_bool(crate.is_crate_visible()).is_true()
	assert_float(crate.crate_position().x).is_equal_approx(5.5, 0.0001)
	assert_float(crate.crate_position().z).is_equal_approx(3.5, 0.0001)
	assert_float(crate.position.x).is_equal_approx(5.5, 0.0001)
	w.salvage.crate_active = false
	layer.render(1.0, 0.016)
	assert_bool(crate.is_crate_visible()).is_false()
	w.salvage.crate_active = true
	layer.render(1.0, 0.016)
	layer.unbind()
	assert_bool(crate.is_crate_visible()).is_false()  # an unbound view shows nothing


func test_the_ring_fills_with_the_secure_timer() -> void:
	var rig: Array = _rig()
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	var secure: int = w.content.run.salvage_secure_ticks
	assert_int(secure).is_equal(720)  # 12 s of 60 ticks
	assert_float(crate.radius()).is_equal_approx(w.content.run.salvage_contest_radius_m, 0.0001)
	w.salvage.crate_active = true
	var want: Array[int] = [0, 8, 16, 24, 32]
	for k: int in want.size():
		w.salvage.crate_progress = floori(float(secure) * float(k) / 4.0)
		layer.render(1.0, 0.016)
		assert_int(crate.ring_segments()).is_equal(want[k])
		assert_float(crate.progress_fraction()).is_equal_approx(float(k) / 4.0, 0.001)
	w.salvage.crate_progress = secure + 100  # never past a full ring
	layer.render(1.0, 0.016)
	assert_int(crate.ring_segments()).is_equal(CrateView.SEGMENTS)


func test_the_ring_turns_red_while_the_timer_stalls_and_cyan_while_it_runs() -> void:
	var rig: Array = _rig()
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	w.salvage.crate_active = true
	w.salvage.crate_progress = 100
	layer.render(1.0, 0.016)
	var fill: MultiMeshInstance3D = crate.get_node("RingFill") as MultiMeshInstance3D
	assert_bool(crate.is_contested()).is_false()
	assert_object(fill.material_override).is_same(MatLib.mat(&"add_cyan"))
	for _n: int in 4:  # four ticks pass and the timer does not move: someone stands on the crate
		w.tick += 1
		layer.render(1.0, 0.016)
	assert_bool(crate.is_contested()).is_true()
	assert_object(fill.material_override).is_same(MatLib.mat(&"add_red"))
	w.tick += 1
	w.salvage.crate_progress = 101
	layer.render(1.0, 0.016)
	assert_bool(crate.is_contested()).is_false()
	assert_object(fill.material_override).is_same(MatLib.mat(&"add_cyan"))
	w.tick += 1
	w.salvage.crate_progress = w.content.run.salvage_secure_ticks  # secured: a full ring is not a contest
	layer.render(1.0, 0.016)
	assert_bool(crate.is_contested()).is_false()


func test_the_crate_drops_in_on_landing_and_settles_on_the_ground() -> void:
	var rig: Array = _rig()
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	w.salvage.crate_active = true
	Events.crate_dropped.emit(2.0, -3.0)
	assert_bool(crate.is_falling()).is_true()
	layer.render(1.0, 0.05)
	var body: MeshInstance3D = crate.get_node("Body") as MeshInstance3D
	var early: float = body.position.y
	assert_float(early).is_greater(1.0)  # still in the air
	layer.render(1.0, 0.1)
	assert_float(body.position.y).is_less(early)  # and coming down
	layer.render(1.0, 0.5)
	assert_bool(crate.is_falling()).is_false()
	assert_float(body.position.y).is_equal_approx(0.0, 0.0001)


func test_the_crate_is_one_prop_and_a_transform_only_ring_with_nothing_allocated_per_frame() -> void:
	var rig: Array = _rig()
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	assert_int(ActorMeshes.triangle_count(ActorMeshes.crate())).is_less_equal(ActorMeshes.TRI_BUDGET[&"crate"])
	var fill: MultiMeshInstance3D = crate.get_node("RingFill") as MultiMeshInstance3D
	assert_int(fill.multimesh.instance_count).is_equal(CrateView.SEGMENTS)
	assert_int(fill.multimesh.transform_format).is_equal(MultiMesh.TRANSFORM_3D)
	assert_bool(fill.multimesh.use_colors).is_false()
	assert_bool(fill.multimesh.use_custom_data).is_false()
	assert_int(crate.get_child_count()).is_equal(3)  # Body, RingBack, RingFill
	w.salvage.crate_active = true
	layer.render(1.0, 0.016)
	var nodes: int = ActorsTestKit.count_nodes(layer)
	for n: int in 100:  # warm up
		w.tick += 1
		w.salvage.crate_progress = n % 700
		layer.render(1.0, 0.016)
	var objects: int = VarietyFKit.objects()
	for n: int in 300:
		w.tick += 1
		w.salvage.crate_progress = n % 700
		layer.render(1.0, 0.016)
	var grown: int = VarietyFKit.objects() - objects  # measured before the first assert: an assertion is an object too
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_int(grown).is_less_equal(2)


func test_the_crate_wears_the_look_and_the_legacy_content_has_no_ring_to_fill() -> void:
	var rig: Array = _rig()
	var layer: ActorLayer = rig[1]
	var crate: CrateView = rig[2]
	var body: MeshInstance3D = crate.get_node("Body") as MeshInstance3D
	for s: int in body.mesh.get_surface_count():
		assert_object(body.get_surface_override_material(s)).is_null()  # CURRENT: the flat palette
	layer.set_look(LookDevStyle.Look.STYLISED)
	var m: ArrayMesh = body.mesh as ArrayMesh
	for s: int in m.get_surface_count():
		var role: StringName = StringName(m.surface_get_material(s).resource_name)
		assert_object(body.get_surface_override_material(s)).is_same(LookDevMat.surface(role, LookDevStyle.Look.STYLISED, layer.quality()))
	var w: SimWorld = ActorsTestKit.world()
	var old: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(old)
	old.bind(w)
	w.salvage.crate_active = true  # the legacy content has no run: no secure time, no crash, an empty ring
	old.render(1.0, 0.016)
	assert_int(old.crate.ring_segments()).is_equal(0)
