extends GdUnitTestSuite
## V2-F chain arcs, telegraphs, ground pools and the hatch material (VARIETY_SPEC 3.5, 5.6, 7.2, 10.3, 12.2, 12.3): three jittered
## segments per jump from the Warden's muzzle through each enemy, a small ring on the ground under each, segment pools by tier,
## cyan rings for what is ours and a RED HATCH for what can hurt the player's side, never tier-gated, and the whole thing from `Events`.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _chaos(vfx: VfxLayer) -> FxChaos:
	return vfx.chaos()


func _rig_with(count: int, type_index: int = Ids.EN_SKITTER) -> Array:
	var rig: Array = VarietyFKit.rig(self)
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var ids: Array[int] = VarietyFKit.spawn(w, type_index, count)
	layer.render(1.0, 0.016)
	rig.append(ids)
	return rig


func test_a_chain_draws_three_segments_per_jump_and_a_ring_under_each_enemy() -> void:
	var rig: Array = _rig_with(5)
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = rig[3]
	var from_id: int = 0
	for enemy_id: int in ids:
		Events.chain_arc.emit(from_id, enemy_id)
		from_id = enemy_id
	assert_int(_chaos(vfx).arcs.segments.live_count()).is_equal(15)  # five jumps of three segments
	assert_int(_chaos(vfx).arcs.jumps).is_equal(5)
	assert_int(_chaos(vfx).blasts.rings_cyan.live_count()).is_equal(5)  # a small blue-white ring under each target
	assert_int(_chaos(vfx).blasts.rings_amber.live_count()).is_equal(0)
	VarietyFKit.age(vfx, 0.5)
	assert_int(_chaos(vfx).arcs.segments.live_count()).is_equal(0)  # a bolt is a crack, not a beam
	assert_int(_chaos(vfx).blasts.rings_cyan.live_count()).is_equal(0)


func test_an_arc_is_thin_jagged_and_runs_from_the_muzzle_to_the_enemy() -> void:
	var rig: Array = _rig_with(1)
	var layer: ActorLayer = rig[1]
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = rig[3]
	var from: Vector3 = layer.warden_muzzle_position()
	var to: Vector3 = layer.enemy_hit_position(ids[0])
	Events.chain_arc.emit(0, ids[0])
	var arcs: FxArcs = _chaos(vfx).arcs
	vfx.render(1.0, 0.0)  # first draw: the segments are at age 0
	var reach: float = 0.0
	var width: float = 0.0
	for slot: int in 3:
		var t: Transform3D = arcs.segments.slot_transform(slot)
		reach += t.basis.z.length()
		width = maxf(width, t.basis.x.length())
	assert_float(reach).is_greater(from.distance_to(to) * 0.3)  # the three pieces together span the way (at age 0 each shows 60 percent)
	assert_float(width).is_less_equal(FxArcs.WIDTH_START + 0.001)  # friendly arcs are thinner than a danger decal is wide
	assert_float(FxArcs.WIDTH_START).is_less(FxTelegraph.COLUMN_WIDTH_M)
	var jagged: bool = false
	var a: Vector3 = arcs.segments.slot_transform(0).basis.z.normalized()
	var b: Vector3 = arcs.segments.slot_transform(1).basis.z.normalized()
	if a.distance_to(b) > 0.01:
		jagged = true
	assert_bool(jagged).is_true()  # the pieces do not lie on one straight line


func test_arc_segment_pools_by_tier_and_the_same_frame_rule() -> void:
	var rig: Array = _rig_with(8)
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = rig[3]
	var want_segments: Array[int] = [18, 30, 45]
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		VarietyFKit.age(vfx, 1.0)
		var arcs: FxArcs = _chaos(vfx).arcs
		var dropped: int = arcs.dropped
		for n: int in 20:  # twenty jumps arrive between two frames
			Events.chain_arc.emit(ids[n % 8], ids[(n + 1) % 8])
		assert_int(arcs.segments.limit).is_equal(want_segments[tier])
		assert_int(arcs.segments.capacity).is_equal(45)  # allocated once for HIGH
		assert_int(arcs.segments.live_count()).is_equal(want_segments[tier])  # 6, 10 and 15 whole jumps
		assert_int(arcs.dropped - dropped).is_equal(20 - floori(float(want_segments[tier]) / 3.0))
		vfx.render(1.0, 0.016)
		Events.chain_arc.emit(ids[0], ids[1])  # the next frame may draw again
		assert_int(arcs.segments.live_count()).is_greater(0)


func test_arcs_to_unknown_enemies_draw_nothing_and_a_killed_target_is_still_found_for_the_next_jump() -> void:
	var rig: Array = _rig_with(3)
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = rig[3]
	Events.chain_arc.emit(0, 987654)
	Events.chain_arc.emit(987654, ids[0])
	assert_int(_chaos(vfx).arcs.segments.live_count()).is_equal(0)
	Events.chain_arc.emit(0, ids[0])
	var drawn: int = _chaos(vfx).arcs.segments.live_count()
	var index: int = w.enemies.index_of(ids[0])
	w.kill_enemy(index, DamageSource.Id.WARDEN)
	Events.enemy_killed.emit(ids[0], DamageSource.Id.WARDEN)
	layer.render(1.0, 0.016)
	assert_bool(layer.enemy_hit_position(ids[0]).is_finite()).is_false()  # the view has let go of it
	Events.chain_arc.emit(ids[0], ids[1])  # ... but the chain goes on from where it was
	assert_int(_chaos(vfx).arcs.segments.live_count()).is_equal(drawn + 3)


func test_an_arc_reaches_a_mini_through_the_store() -> void:
	var rig: Array = _rig_with(2, Ids.EN_MOTE)
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = rig[3]
	Events.chain_arc.emit(0, ids[0])
	Events.chain_arc.emit(ids[0], ids[1])
	assert_int(_chaos(vfx).arcs.jumps).is_equal(2)  # a mote has no view of its own, and arcs love motes anyway


func test_an_event_warning_is_a_cyan_ring_that_closes_for_exactly_its_ticks() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var tele: FxTelegraph = _chaos(vfx).telegraph
	Events.event_warned.emit(&"deadfall_strike", 120, 3.0, 2.0)  # a player strike: it hurts enemies, so no hatch
	assert_int(tele.rings_cyan.live_count()).is_equal(2)  # the outline and the closing ring
	assert_int(tele.rings_red.live_count()).is_equal(0)
	assert_int(tele.hatches.live_count()).is_equal(0)
	var content: ContentSet = TestContent.variety()
	var radius: float = content.events[content.event_index(&"deadfall_strike")].param(&"radius_m")
	vfx.render(1.0, 0.0)
	var outline: Transform3D = tele.rings_cyan.slot_transform(0)
	var closing: Transform3D = tele.rings_cyan.slot_transform(1)
	assert_float(outline.basis.x.length()).is_equal_approx(radius, 0.001)  # the zone is drawn at its real radius
	assert_float(closing.basis.x.length()).is_greater(radius * 1.5)  # ... and the ring starts well outside it
	VarietyFKit.age(vfx, 1.8)
	assert_int(tele.rings_cyan.live_count()).is_equal(2)  # still warning at 1.8 s
	assert_float(tele.rings_cyan.slot_transform(1).basis.x.length()).is_less(radius * 1.25)
	VarietyFKit.age(vfx, 0.4)
	assert_int(tele.rings_cyan.live_count()).is_equal(0)  # over at 2.0 s: the strike lands


func test_a_harmful_zone_is_a_red_hatch_with_a_shrinking_outline() -> void:
	var rig: Array = VarietyFKit.rig(self)
	var vfx: VfxLayer = rig[2]
	var rig_world: SimWorld = rig[0]
	var content: ContentSet = rig_world.content
	content.events[content.event_index(&"deadfall_strike")].harmful = true  # stands in for a harmful world event of V4-V
	var tele: FxTelegraph = _chaos(vfx).telegraph
	Events.event_warned.emit(&"deadfall_strike", 150, 1.0, 1.0)
	assert_int(tele.hatches.live_count()).is_equal(1)
	assert_int(tele.rings_red.live_count()).is_equal(2)
	assert_int(tele.rings_cyan.live_count()).is_equal(0)
	var hatch: StandardMaterial3D = tele.hatches.node.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
	assert_object(hatch).is_same(MatLib.mat(&"hatch_red"))
	Events.delayed_hit.emit(HazardState.K_BOLT, 5.0, 5.0, 40)  # a spitter bolt on its way to the core
	assert_int(tele.hatches.live_count()).is_equal(2)
	Events.event_warned.emit(&"no_such_event", 60, 0.0, 0.0)  # an unknown id is a plain, helpful ring
	assert_int(tele.rings_cyan.live_count()).is_equal(2)


func test_telegraphs_are_never_tier_gated_and_reduced_flash_never_removes_them() -> void:
	var rig: Array = VarietyFKit.rig(self)
	var vfx: VfxLayer = rig[2]
	var rig_world: SimWorld = rig[0]
	var content: ContentSet = rig_world.content
	content.events[content.event_index(&"deadfall_strike")].harmful = true
	var tele: FxTelegraph = _chaos(vfx).telegraph
	var counts: Array[int] = []
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		VarietyFKit.age(vfx, 3.0)
		for n: int in 3:
			Events.event_warned.emit(&"deadfall_strike", 90, float(n), 0.0)
		Events.delayed_hit.emit(HazardState.K_BOLT, 2.0, 2.0, 60)
		Events.delayed_hit.emit(HazardState.K_STRIKE, 2.0, 2.0, 60)
		counts.append(tele.live_count())
		assert_int(tele.hatches.limit).is_equal(8)  # the same 8 slots on every tier
		assert_int(tele.rings_red.limit).is_equal(8)
	assert_int(counts[0]).is_equal(counts[1])
	assert_int(counts[1]).is_equal(counts[2])
	vfx.set_reduced_flash(true)
	VarietyFKit.age(vfx, 3.0)
	Events.event_warned.emit(&"deadfall_strike", 90, 0.0, 0.0)
	assert_int(tele.hatches.live_count()).is_equal(1)  # a danger zone is information, not a flash
	for n: int in 12:
		Events.event_warned.emit(&"deadfall_strike", 90, float(n), 0.0)
	assert_int(tele.hatches.live_count()).is_equal(8)  # at most 8 decals, the oldest dropped


func test_the_strike_column_falls_onto_the_target_for_its_ticks() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var tele: FxTelegraph = _chaos(vfx).telegraph
	Events.delayed_hit.emit(HazardState.K_STRIKE, 4.0, -2.0, 60)
	assert_int(tele.columns.live_count()).is_equal(1)
	Events.delayed_hit.emit(HazardState.K_FREIGHT, 4.0, -2.0, 60)  # kinds without a telegraph yet draw nothing
	Events.delayed_hit.emit(HazardState.K_DRUM, 4.0, -2.0, 60)
	assert_int(tele.live_count()).is_equal(1)
	VarietyFKit.age(vfx, 0.8)
	assert_int(tele.columns.live_count()).is_equal(1)
	VarietyFKit.age(vfx, 0.4)
	assert_int(tele.columns.live_count()).is_equal(0)


func test_ground_pools_open_and_close_by_id_with_caps_by_tier() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var ground: FxPools = _chaos(vfx).ground
	Events.pool_changed.emit(1, 2.0, 3.0, 2.2, true)
	Events.pool_changed.emit(2, -2.0, 3.0, 1.5, true)
	vfx.render(1.0, 0.016)
	assert_int(ground.live_count()).is_equal(2)
	assert_int(ground.drawn_count()).is_equal(2)
	assert_int(ground.node.multimesh.visible_instance_count).is_equal(2)
	Events.pool_changed.emit(1, 2.0, 3.0, 0.0, false)  # the burn ended
	vfx.render(1.0, 0.016)
	assert_int(ground.live_count()).is_equal(1)
	Events.pool_changed.emit(99, 0.0, 0.0, 0.0, false)  # an unknown id is ignored
	assert_int(ground.live_count()).is_equal(1)
	var want: Array[int] = [6, 8, 10]
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		for n: int in 14:
			Events.pool_changed.emit(100 + n, float(n), 0.0, 1.0, true)
		vfx.render(1.0, 0.016)
		assert_int(ground.limit()).is_equal(want[tier])
		assert_int(ground.live_count()).is_equal(want[tier])
		assert_int(ground.node.multimesh.instance_count).is_equal(10)
		Events.pool_changed.emit(113, 13.0, 0.0, 0.0, false)  # the newest is still there (the oldest were dropped)
		assert_int(ground.live_count()).is_equal(want[tier] - 1)
		ground.clear()


func test_the_crate_pulses_and_a_rebind_listens_again_while_an_unbind_stops_everything() -> void:
	var rig: Array = _rig_with(2)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	w.salvage.crate_active = true
	w.salvage.crate_x = 2.0
	w.salvage.crate_z = 1.0
	var layer: ActorLayer = rig[1]
	var ids: Array[int] = rig[3]
	layer.render(1.0, 0.016)
	Events.crate_dropped.emit(2.0, 1.0)
	Events.crate_secured.emit()
	Events.crate_lost.emit()
	assert_int(_chaos(vfx).blasts.rings_cyan.live_count()).is_equal(2)  # landing and secured: cyan, ours
	assert_int(_chaos(vfx).blasts.rings_amber.live_count()).is_equal(1)  # lost: amber
	vfx.unbind()
	Events.area_blast.emit(HazardState.K_BLAST, 1.0, 1.0, 2.0)
	Events.chain_arc.emit(0, ids[0])
	Events.event_warned.emit(&"deadfall_strike", 60, 0.0, 0.0)
	Events.pool_changed.emit(1, 0.0, 0.0, 1.0, true)
	assert_int(_chaos(vfx).blasts.live_rings()).is_equal(0)
	assert_int(_chaos(vfx).arcs.segments.live_count() + _chaos(vfx).telegraph.live_count() + _chaos(vfx).ground.live_count()).is_equal(0)
	vfx.bind(w)
	Events.area_blast.emit(HazardState.K_BLAST, 1.0, 1.0, 2.0)
	assert_int(_chaos(vfx).blasts.live_rings()).is_equal(1)  # listening again, and never twice for one event


func test_the_hatch_is_one_unshaded_alpha_material_that_the_warmup_draws() -> void:
	assert_bool(MatLib.IDS.has(&"hatch_red")).is_true()
	var m: StandardMaterial3D = MatLib.mat(&"hatch_red")
	assert_int(m.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(m.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_int(m.blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_MIX)  # alpha, not additive: a hatch is a stripe, not a light
	assert_bool(m.texture_repeat).is_true()
	assert_object(m.albedo_texture).is_same(MatLib.hatch_texture())
	assert_float(m.albedo_color.r).is_greater(m.albedo_color.g * 2.0)  # the palette red (chorus_red)
	assert_that(m.albedo_color.r).is_equal(TestContent.variety().tokens.color(&"chorus_red").r)
	var img: Image = MatLib.hatch_image()
	var lit: int = 0
	var gap: int = 0
	for y: int in 64:
		for x: int in 64:
			assert_float(img.get_pixel(x, y).a).is_equal(img.get_pixel((x + 16) % 64, y).a)  # tiles seamlessly
			if img.get_pixel(x, y).a > 0.5:
				lit += 1
			else:
				gap += 1
	assert_float(float(lit) / float(lit + gap)).is_between(0.3, 0.5)  # stripes and gaps, not a solid fill
	var mesh: ArrayMesh = ShaderWarmup.build_mesh([])
	assert_int(ShaderWarmup.material_count(mesh)).is_equal(MatLib.IDS.size())  # the warm-up draws the hatch with every palette material
	var warm: Array[StringName] = []
	for s: int in mesh.get_surface_count():
		warm.append(StringName(mesh.surface_get_material(s).resource_name))
	assert_bool(warm.has(&"hatch_red")).is_true()


func test_a_full_blast_chain_with_real_bodies_stays_countable_and_pools_stay_in_their_caps() -> void:
	var content: ContentSet = TestContent.variety()
	var view: BattleView = ViewIntegrationKit.battle_view(self, content)
	var p: SimPuppet = SimPuppet.new()
	auto_free(p)
	add_child(p)
	p.setup(content, "chain", 1, true)
	view.bind(p.world)
	var peak_flash: int = 0
	var peak_rings: int = 0
	var max_bursters: int = 0
	for _t: int in PuppetChaos.CYCLE:
		p.step_once()
		view.render(1.0, SimPuppet.TICK_DT)
		var chaos: FxChaos = view.vfx_layer.chaos()
		peak_flash = maxi(peak_flash, chaos.blasts.flashes.live_count())
		peak_rings = maxi(peak_rings, chaos.blasts.rings_amber.live_count() + chaos.blasts.rings_cyan.live_count())
		var bursters: int = 0
		for index: int in p.world.enemies.high_water:
			if p.world.enemies.alive[index] == 1 and p.world.enemies.type[index] == Ids.EN_BURSTER:
				bursters += 1
		max_bursters = maxi(max_bursters, bursters)
		assert_int(view.actor_layer.visible_enemy_count()).is_less_equal(content.mission.enemy_cap + 8)
	print("CHAIN peak flashes=%d peak rings=%d bursters=%d blasts=%d arcs=%d" % [peak_flash, peak_rings, max_bursters, p.chaos.blasts, p.chaos.arcs])
	assert_int(max_bursters).is_equal(PuppetChaos.CHAIN_LEN)  # the line is real bodies, drawn from pooled views
	assert_int(peak_flash).is_between(1, VisualQuality.blast_flashes(VisualQuality.Tier.HIGH))
	assert_int(peak_rings).is_between(2, 2 * VisualQuality.blast_rings(VisualQuality.Tier.HIGH))
	assert_int(view.vfx_layer.chaos().arcs.jumps).is_greater(8)  # the arcs of the scenario were drawn
	assert_int(view.vfx_layer.chaos().ground.live_count()).is_less_equal(10)
