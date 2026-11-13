extends GdUnitTestSuite
## V4-X event warnings (SPEC 7.2: "a ground decal where it will happen (lane, ring, cracks, edge arrows)", 5.6 rule 4): every event of CONTENT 6 has
## its decal, harmful ones are red and hatched, helpful ones cyan and not, nothing is tier-gated, and the strike and the static front have their
## own warning and aftermath.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _tele(vfx: VfxLayer) -> FxTelegraph:
	return vfx.chaos().telegraph


## The first live slot of a pool (a ring buffer: where the next effect landed depends on what came before).
func _live_slot(pool: VfxPool) -> int:
	for s: int in pool.capacity:
		if pool.progress(s) >= 0.0:
			return s
	return -1


func test_every_event_has_a_look_and_an_unknown_id_is_a_plain_ring() -> void:
	var ids: Array[StringName] = [
		&"deadfall_strike", &"core_vent", &"freight_call", &"accord_window", &"supply_drop", &"power_surge", &"runaway_freight",
		&"static_front", &"floor_breach", &"recount",
	]
	var looks: Dictionary[int, bool] = {}
	for id: StringName in ids:
		looks[FxTelegraph.look_of(id)] = true
	assert_int(FxTelegraph.look_of(&"deadfall_strike")).is_equal(FxTelegraph.Look.RING)
	assert_int(FxTelegraph.look_of(&"supply_drop")).is_equal(FxTelegraph.Look.RING)
	assert_int(FxTelegraph.look_of(&"no_such_event")).is_equal(FxTelegraph.Look.RING)
	assert_int(FxTelegraph.look_of(&"runaway_freight")).is_equal(FxTelegraph.Look.LANE)
	assert_int(FxTelegraph.look_of(&"freight_call")).is_equal(FxTelegraph.Look.LANE)
	assert_int(FxTelegraph.look_of(&"floor_breach")).is_equal(FxTelegraph.Look.CRACKS)
	assert_int(FxTelegraph.look_of(&"recount")).is_equal(FxTelegraph.Look.BAND)
	assert_int(looks.size()).is_greater_equal(6)  # lane, ring, cracks, band, pads, core, none: the grammar has several shapes


func test_a_freight_lane_runs_along_the_rail_line_nearest_to_the_warning_and_closes_in() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var arena: ArenaDef = rig.world.content.arena
	Events.event_warned.emit(&"runaway_freight", 240, 0.0, -6.0)
	var tele: FxTelegraph = _tele(vfx)
	assert_int(tele.lanes_cyan.live_count()).is_equal(2)  # the bars of the lane and the wider pair that closes in
	assert_int(tele.hatches.live_count()).is_equal(0)  # a freight car hurts enemies only: no hatch
	assert_int(tele.lanes_red.live_count()).is_equal(0)
	vfx.render(1.0, 0.0)
	var edge: Transform3D = tele.lanes_cyan.slot_transform(0)
	var closing: Transform3D = tele.lanes_cyan.slot_transform(1)
	assert_float(edge.origin.z).is_equal_approx(arena.rail_z[0], 0.001)  # snapped to the rail line at z = -7
	assert_float(edge.basis.z.length()).is_equal_approx(arena.rail_half_width[0], 0.001)
	assert_float(edge.basis.x.length()).is_greater((arena.max_x - arena.min_x) * 0.5)  # the lane runs past both edges of the yard
	assert_float(closing.basis.z.length()).is_greater(edge.basis.z.length() * 1.5)
	VfxXTestKit.age(vfx, 3.6)
	assert_int(tele.lanes_cyan.live_count()).is_equal(2)  # 4 s warning: still there at 3.6 s
	VfxXTestKit.age(vfx, 0.8)
	assert_int(tele.lanes_cyan.live_count()).is_equal(0)
	Events.event_warned.emit(&"freight_call", 240, 0.0, 9.0)  # the player's call picks the other line
	vfx.render(1.0, 0.0)
	assert_float(tele.lanes_cyan.slot_transform(_live_slot(tele.lanes_cyan)).origin.z).is_equal_approx(arena.rail_z[1], 0.001)


func test_a_floor_breach_draws_hatched_cracks_at_every_breach_point() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var tele: FxTelegraph = _tele(vfx)
	var points: Array[Vector2] = [Vector2(2.5, -2.0), Vector2(6.0, 2.5), Vector2(5.0, -4.5)]
	for p: Vector2 in points:
		Events.event_warned.emit(&"floor_breach", 150, p.x, p.y)
	assert_int(tele.cracks.live_count()).is_equal(3)
	assert_int(tele.hatches.live_count()).is_equal(3)  # a breach is harmful: the red hatch under the cracks
	assert_int(tele.rings_red.live_count()).is_equal(6)  # with the shrinking outline
	assert_int(tele.rings_cyan.live_count()).is_equal(0)
	vfx.render(1.0, 0.0)
	assert_float(tele.cracks.slot_transform(1).origin.x).is_equal_approx(6.0, 0.001)
	assert_object(tele.cracks.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_red"))
	VfxXTestKit.age(vfx, 2.6)
	assert_int(tele.cracks.live_count()).is_equal(0)


func test_a_recount_draws_a_hatched_band_along_the_spawn_edge_it_enters_from() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var tele: FxTelegraph = _tele(vfx)
	Events.event_warned.emit(&"recount", 180, 10.8, 0.0)  # the right edge
	assert_int(tele.bands.live_count()).is_equal(1)
	assert_int(tele.lanes_red.live_count()).is_equal(2)
	vfx.render(1.0, 0.0)
	var band: Transform3D = tele.bands.slot_transform(0)
	assert_float(band.origin.x).is_equal_approx(10.8, 0.001)
	assert_float(absf(band.basis.x.normalized().dot(Vector3.BACK))).is_equal_approx(1.0, 0.001)  # it runs along z, down the edge
	assert_object(tele.bands.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"hatch_red"))
	Events.event_warned.emit(&"recount", 180, 3.0, -17.0)  # the top edge
	vfx.render(1.0, 0.0)
	assert_float(absf(tele.bands.slot_transform(1).basis.x.normalized().dot(Vector3.RIGHT))).is_equal_approx(1.0, 0.001)


func test_a_core_surge_rings_both_pads_a_vent_rings_the_core_and_a_relay_window_has_no_decal() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var arena: ArenaDef = rig.world.content.arena
	var tele: FxTelegraph = _tele(vfx)
	Events.event_warned.emit(&"power_surge", 240, 0.0, 0.0)
	assert_int(tele.rings_cyan.live_count()).is_equal(2 * arena.turret_pads.size())
	VfxXTestKit.age(vfx, 5.0)
	Events.event_warned.emit(&"core_vent", 30, 0.0, 0.0)
	vfx.render(1.0, 0.0)
	var ring: Transform3D = tele.rings_cyan.slot_transform(_live_slot(tele.rings_cyan))
	assert_float(ring.origin.x).is_equal_approx(arena.core_x, 0.001)
	assert_float(ring.basis.x.length()).is_equal_approx(FxTelegraph.CORE_VENT_RADIUS_M, 0.001)
	VfxXTestKit.age(vfx, 1.0)
	Events.event_warned.emit(&"accord_window", 0, 0.0, 0.0)
	Events.event_warned.emit(&"static_front", 360, 0.0, 0.0)
	assert_int(tele.live_count()).is_equal(0)  # no ground decal: the static front warns at the screen edge


func test_a_harmful_event_is_red_and_hatched_and_a_helpful_one_is_cyan_and_not() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var content: ContentSet = rig.world.content
	var tele: FxTelegraph = _tele(vfx)
	var def: EventDef = content.events[content.event_index(&"deadfall_strike")]
	def.harmful = false
	Events.event_warned.emit(&"deadfall_strike", 60, 1.0, 1.0)
	assert_int(tele.rings_cyan.live_count()).is_equal(2)
	assert_int(tele.hatches.live_count()).is_equal(0)
	VfxXTestKit.age(vfx, 1.5)
	def.harmful = true  # what the data of a harmful world event says
	Events.event_warned.emit(&"deadfall_strike", 60, 1.0, 1.0)
	assert_int(tele.hatches.live_count()).is_equal(1)
	assert_int(tele.rings_red.live_count()).is_equal(2)
	assert_int(tele.rings_cyan.live_count()).is_equal(0)


func test_high_contrast_thickens_the_outline_of_a_danger_decal_and_the_lane_bars() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var tele: FxTelegraph = _tele(rig.vfx)
	var red: Mesh = tele.rings_red.node.multimesh.mesh
	var lane: Mesh = tele.lanes_cyan.node.multimesh.mesh
	rig.layer.set_high_contrast(true)
	rig.vfx.render(1.0, 0.016)
	assert_bool(tele.rings_red.node.multimesh.mesh == red).is_false()
	assert_bool(tele.lanes_cyan.node.multimesh.mesh == lane).is_false()
	assert_float(FxTelegraph.OUTLINE_INNER_CONTRAST).is_less(FxTelegraph.OUTLINE_INNER)
	assert_float(FxTelegraph.LANE_THICK_CONTRAST).is_greater(FxTelegraph.LANE_THICK)
	rig.layer.set_high_contrast(false)
	rig.vfx.render(1.0, 0.016)
	assert_bool(tele.rings_red.node.multimesh.mesh == red).is_true()


func test_the_strike_has_a_beacon_a_column_and_an_aftermath_by_tier() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var strike: FxStrike = vfx.chaos().strike
	var columns: Array[int] = []
	var sparks: Array[int] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 3.0)
		Events.delayed_hit.emit(HazardState.K_STRIKE, 3.0, -2.0, 120)
		assert_bool(strike.beacon.visible).is_true()  # stands on the target while the round is in the air
		assert_float(strike.beacon.position.x).is_equal(3.0)
		VfxXTestKit.age(vfx, 1.0)
		assert_bool(strike.beacon.visible).is_true()
		Events.area_blast.emit(HazardState.K_STRIKE, 3.0, -2.0, 4.0)
		assert_bool(strike.beacon.visible).is_false()
		assert_bool(strike.aftermath_active()).is_true()
		columns.append(strike.column.live_count())
		VfxXTestKit.age(vfx, 0.3)
		sparks.append(vfx.spark_count())  # the wreck sparks of the crater (the blast's own streaks are gone by now)
	assert_array(columns).is_equal([0, 1, 1])  # the flash of the column is MID and above
	assert_int(sparks[0]).is_equal(0)
	assert_int(sparks[1]).is_greater(0)
	assert_int(sparks[2]).is_greater(0)
	assert_int(strike.impacts).is_equal(3)
	assert_int(VfxXTestKit.triangles_of(strike.beacon)).is_less_equal(100)  # SPEC 12.2: the strike beacon is 100 triangles


func test_the_static_front_warns_at_the_screen_edges_in_red_and_runs_as_static() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var overlay: FxStatic = vfx.chaos().overlay
	assert_bool(overlay.is_showing()).is_false()
	Events.event_warned.emit(&"static_front", 360, 0.0, 0.0)
	assert_int(overlay.phase()).is_equal(1)
	assert_bool(overlay.left.visible and overlay.right.visible).is_true()
	assert_float(overlay.left.anchor_right).is_less_equal(0.1)  # the edges only, never the centre of the battlefield
	assert_float(overlay.right.anchor_left).is_greater_equal(0.9)
	VfxXTestKit.age(vfx, 3.0)
	assert_float(overlay.left.modulate.a).is_greater(0.0)
	assert_float(overlay.left.modulate.r).is_greater(overlay.left.modulate.b)  # red: the hatch of a danger
	Events.event_started.emit(&"static_front")
	assert_int(overlay.phase()).is_equal(2)
	VfxXTestKit.age(vfx, 0.5)
	assert_float(overlay.left.modulate.a).is_equal_approx(FxStatic.ACTIVE_ALPHA, 0.001)
	Events.event_ended.emit(&"static_front")
	assert_bool(overlay.is_showing()).is_false()
	assert_bool(overlay.left.visible).is_false()
	w.events_state.ability_lock_ticks = 200  # a front that is already running when the view binds
	vfx.render(1.0, 0.016)
	assert_int(overlay.phase()).is_equal(2)
	w.events_state.ability_lock_ticks = 0
	vfx.render(1.0, 0.016)
	assert_bool(overlay.is_showing()).is_false()


func test_reduced_flash_holds_the_static_still() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var overlay: FxStatic = vfx.chaos().overlay
	vfx.set_reduced_flash(true)
	Events.event_started.emit(&"static_front")
	vfx.render(1.0, 0.05)
	var first: Texture2D = overlay.left.texture
	for _n: int in 8:
		vfx.render(1.0, 0.05)
		assert_bool(overlay.left.texture == first).is_true()  # one frame, never cycled: nothing flickers
	vfx.set_reduced_flash(false)
	var seen: Dictionary[int, bool] = {}
	for _n: int in 12:
		vfx.render(1.0, 0.05)
		seen[overlay.left.texture.get_instance_id()] = true
	assert_int(seen.size()).is_greater(1)


func test_a_brownout_hatches_the_pads_and_a_surge_rings_them_for_the_ticks_the_sim_says() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var tele: FxTelegraph = _tele(vfx)
	var pads: int = w.content.arena.turret_pads.size()
	w.events_state.turret_rate_milli = 2000
	w.events_state.turret_rate_ticks = 600  # a core surge: 10 s of double fire
	vfx.render(1.0, 0.0)
	assert_int(tele.rings_cyan.live_count()).is_equal(pads)
	vfx.render(1.0, 0.0)
	assert_int(tele.rings_cyan.live_count()).is_equal(pads)  # drawn once, on the edge, not again every frame
	w.events_state.turret_rate_ticks = 0
	w.events_state.turret_offline_ticks = 300  # ... then the brownout: 5 s without turrets
	vfx.render(1.0, 0.0)
	assert_int(tele.hatches.live_count()).is_equal(pads)  # a red hatch on every pad: the tools are gone
	for _n: int in 20:
		vfx.render(1.0, 0.0)
	assert_int(tele.hatches.live_count()).is_equal(pads)
	vfx.unbind()
	vfx.bind(w)
	vfx.render(1.0, 0.0)
	assert_int(tele.hatches.live_count()).is_equal(pads)  # a view that binds in the middle of a brownout shows it


func test_a_relay_window_ripples_amber_at_the_core_and_has_no_other_decal() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var blasts: FxBlasts = vfx.chaos().blasts
	Events.event_started.emit(&"accord_window")
	assert_int(blasts.rings_amber.live_count()).is_equal(1)
	vfx.render(1.0, 0.0)
	assert_float(blasts.rings_amber.slot_transform(0).origin.x).is_equal_approx(rig.world.content.arena.core_x, 0.001)
	assert_int(_tele(vfx).live_count()).is_equal(0)
