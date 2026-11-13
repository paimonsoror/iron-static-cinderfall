extends GdUnitTestSuite
## V4-X cosmetic chaos and readable blasts: scorch marks that persist and stay calm, embers that rise, a ghost swarm that never enters the yard and
## has no optic, and the small blast of a volatile skitter at the far edge of the yard drawn big enough to see (found on the slice captures).


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _cos(vfx: VfxLayer) -> FxCosmetic:
	return vfx.chaos().cosmetic


func _steps(vfx: VfxLayer, n: int) -> void:
	for _k: int in n:
		vfx.render(1.0, 0.1)


func test_a_blast_leaves_a_calm_dark_mark_that_stays_and_a_vent_or_a_freight_leaves_none() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var cos: FxCosmetic = _cos(vfx)
	Events.area_blast.emit(HazardState.K_BLAST, 4.0, 2.0, 2.6)
	assert_int(cos.scorch.live_count()).is_equal(1)
	vfx.render(1.0, 0.0)
	var t: Transform3D = cos.scorch.slot_transform(0)
	assert_float(t.origin.x).is_equal_approx(4.0, 0.001)
	assert_float(t.origin.y).is_between(0.03, 0.04)  # a hair above the blob shadows, below every decal and pool
	assert_float(t.basis.x.length()).is_equal_approx(2.6 * FxCosmetic.SCORCH_SHARE, 0.001)
	Events.area_blast.emit(HazardState.K_VENT, 0.0, 0.0, 6.0)
	Events.area_blast.emit(HazardState.K_FREIGHT, 0.0, 0.0, 1.3)
	assert_int(cos.scorch.live_count()).is_equal(1)
	_steps(vfx, 300)  # 30 s later
	assert_int(cos.scorch.live_count()).is_equal(1)  # a persistent ring buffer, not a timer of seconds
	var mesh: ArrayMesh = cos.scorch.node.multimesh.mesh as ArrayMesh
	var dark: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
	assert_str(dark.resource_name).is_equal("shadow_blob")  # the black shadow material, no emission ...
	assert_bool(dark.emission_enabled).is_false()
	assert_float(dark.albedo_color.a).is_less(MatLib.mat(&"shadow_blob").albedo_color.a)  # ... a little lighter than a blob shadow: a mark, not a hole
	Events.area_blast.emit(HazardState.K_STRIKE, 0.0, 0.0, 4.0)
	vfx.render(1.0, 0.0)
	assert_float(cos.scorch.slot_transform(1).basis.x.length()).is_less_equal(FxCosmetic.SCORCH_MAX_M + 0.001)


func test_the_scorch_ring_buffer_recycles_its_oldest_mark_by_tier() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var cos: FxCosmetic = _cos(vfx)
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		for n: int in 30:
			Events.area_blast.emit(HazardState.K_BLAST, float(n % 9) - 4.0, float(n % 4), 2.0)
		assert_int(cos.scorch.live_count()).is_equal(VisualQuality.scorch_marks(t))
		assert_int(cos.scorch.capacity).is_equal(16)
	var area: float = 0.0
	for s: int in 16:
		var r: float = cos.scorch.slot_transform(s).basis.x.length()
		area += PI * r * r
	var arena: ArenaDef = TestContent.variety().arena
	assert_float(area / ((arena.max_x - arena.min_x) * (arena.max_z - arena.min_z))).is_less(0.25)  # the ground stays calm (the marks overlap in practice)


func test_embers_rise_and_burn_out() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var cos: FxCosmetic = _cos(vfx)
	Events.area_blast.emit(HazardState.K_BLAST, 1.0, 1.0, 2.6)
	assert_int(cos.embers.live_count()).is_equal(VisualQuality.embers_per_blast(VisualQuality.Tier.HIGH))
	vfx.render(1.0, 0.0)
	var low: float = cos.embers.slot_transform(0).origin.y
	_steps(vfx, 4)
	assert_float(cos.embers.slot_transform(0).origin.y).is_greater(low + 0.3)
	_steps(vfx, 10)
	assert_int(cos.embers.live_count()).is_equal(0)


func test_the_ghost_swarm_stays_outside_the_yard_has_no_optic_and_follows_the_pressure() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var ghosts: FxGhosts = _cos(vfx).ghosts
	var arena: ArenaDef = w.content.arena
	for i: int in FxGhosts.CAP_HIGH:
		var p: Vector2 = ghosts.resting_place(i)
		var inside: bool = p.x > arena.min_x and p.x < arena.max_x and p.y > arena.min_z and p.y < arena.max_z
		assert_bool(inside).override_failure_message("ghost %d stands inside the playable rectangle at %s" % [i, p]).is_false()
	vfx.render(1.0, 0.016)
	assert_int(ghosts.shown()).is_equal(0)  # nothing alive, nobody massing
	VarietyFKit.spawn(w, Ids.EN_SKITTER, 40)
	rig.layer.render(1.0, 0.016)
	var want: Array[int] = [0, 40, 80]
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		vfx.render(1.0, 0.016)
		assert_int(ghosts.shown()).is_equal(want[t])
	var mesh: ArrayMesh = ghosts.node.multimesh.mesh as ArrayMesh
	for s: int in mesh.get_surface_count():
		var m: StandardMaterial3D = mesh.surface_get_material(s) as StandardMaterial3D
		assert_bool(m.emission_enabled).is_false()  # one red optic per enemy and nothing else glows
		assert_object(m).is_same(MatLib.mat(&"steel_red"))
	assert_int(VfxXTestKit.triangles_of(ghosts.node)).is_less_equal(40)


func test_the_ghosts_hold_still_under_reduced_flash() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	VarietyFKit.spawn(rig.world, Ids.EN_SKITTER, 40)
	rig.layer.render(1.0, 0.016)
	vfx.set_reduced_flash(true)
	vfx.render(1.0, 0.1)
	var ghosts: FxGhosts = _cos(vfx).ghosts
	assert_int(ghosts.shown()).is_greater(0)
	var first: Vector3 = ghosts.transform_of(0).origin
	_steps(vfx, 12)
	assert_vector(ghosts.transform_of(0).origin).is_equal(first)
	vfx.set_reduced_flash(false)
	_steps(vfx, 6)
	assert_vector(ghosts.transform_of(0).origin).is_not_equal(first)  # they sway again when the player has not asked for calm


func test_a_small_blast_at_the_far_edge_is_drawn_at_least_as_big_as_the_floor_says() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var blasts: FxBlasts = vfx.chaos().blasts
	var volatile_m: float = 1.2  # the blast of a volatile skitter (mod_volatile)
	assert_float(FxBlasts.MIN_RING_M).is_greater(volatile_m)
	Events.area_blast.emit(HazardState.K_BLAST, 2.0, -15.0, volatile_m)  # the far edge of the yard
	Events.area_blast.emit(HazardState.K_BLAST, -2.0, 9.0, volatile_m)  # beside the Warden
	vfx.render(1.0, 0.0)
	var far: float = blasts.rings_amber.slot_transform(0).basis.x.length() / 0.2  # a ring starts at a fifth of its radius
	var near: float = blasts.rings_amber.slot_transform(1).basis.x.length() / 0.2
	assert_float(near).is_greater_equal(FxBlasts.MIN_RING_M - 0.001)
	assert_float(far).is_greater(near)  # the farther one is drawn bigger in the world ...
	var cam: CameraRig = vfx.chaos().ctx.rig
	var px_far: float = absf(cam.world_to_screen(Vector3(2.0 + far, 0.0, -15.0)).x - cam.world_to_screen(Vector3(2.0 - far, 0.0, -15.0)).x)
	var px_near: float = absf(cam.world_to_screen(Vector3(-2.0 + near, 0.0, 9.0)).x - cam.world_to_screen(Vector3(-2.0 - near, 0.0, 9.0)).x)
	var px_far_plain: float = absf(cam.world_to_screen(Vector3(2.0 + near, 0.0, -15.0)).x - cam.world_to_screen(Vector3(2.0 - near, 0.0, -15.0)).x)
	assert_float(px_far).is_greater(px_far_plain)  # ... so it keeps more of its size on the screen
	assert_float(px_far / px_near).is_greater(px_far_plain / px_near)
	var flash: Transform3D = blasts.flashes.slot_transform(0)
	assert_float(flash.basis.x.length()).is_greater_equal(FxBlasts.FLASH_MIN_M - 0.001)  # the old flash of a 1.2 m blast was 0.84 m
	assert_float(FxBlasts.FLASH_LIFE_S).is_less_equal(0.25)  # and it still never washes out an optic for longer than a blast flash


func test_a_big_blast_is_drawn_at_its_true_radius() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var blasts: FxBlasts = vfx.chaos().blasts
	Events.area_blast.emit(HazardState.K_STRIKE, 0.0, -14.0, 4.0)  # a real zone: the ring must not lie about it
	vfx.render(1.0, 0.0)
	assert_float(blasts.rings_cyan.slot_transform(0).basis.x.length() / 0.2).is_equal_approx(4.0, 0.001)
	assert_float(blasts.flashes_cyan.slot_transform(0).basis.x.length()).is_less_equal(FxBlasts.FLASH_MAX_M + 0.001)
