extends GdUnitTestSuite
## V5-B view defects: hornets are short streaks, the High Contrast elite ring is thicker, the scattergun fans, the rifle's tracer goes on
## through its target, the LMG throws brass (not on LOW), and a turret removed without an event disappears (the view polls the store).


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _tracers_after_shot(rig: VfxXTestKit.Rig, weapon: StringName, tier: int) -> Array[int]:
	var w: SimWorld = rig.world
	rig.vfx.set_quality(tier)
	var i: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -4.0, -3.0)
	w.warden.weapon_index = Ids.WEAPONS.find(weapon)
	w.warden.aim_x = -4.0
	w.warden.aim_z = -3.0
	rig.layer.render(1.0, 0.016)
	var before: int = rig.vfx.tracer_count()
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[i])
	return [rig.vfx.tracer_count() - before, rig.vfx.weapon_shots().brass.live_count()]


func test_a_hornet_is_a_short_streak_along_its_flight_not_a_ball() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var lobs: FxLobs = rig.vfx.chaos().lobs
	assert_float(lobs.hornets.streak_len).is_greater(0.5)
	Events.delayed_hit.emit(HazardState.K_MISSILE, 6.0, -3.0, 30)
	rig.vfx.render(1.0, 0.1)
	var slot: int = -1
	for s: int in lobs.hornets.capacity:
		if lobs.hornets.progress(s) >= 0.0:
			slot = s
	assert_int(slot).is_greater(-1)
	var basis: Basis = lobs.hornets.slot_transform(slot).basis
	assert_float(basis.z.length()).is_greater(0.6)  # long along its flight
	assert_float(basis.x.length()).is_less(0.4)  # and thin
	assert_object(lobs.hornets.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_cyan"))
	assert_float(lobs.shells.streak_len).is_equal(0.0)  # a shell and a bolt stay balls
	assert_float(lobs.bolts.streak_len).is_equal(0.0)


func _min_radius(mesh: ArrayMesh) -> float:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var best: float = INF
	for v: Vector3 in verts:
		best = minf(best, Vector2(v.x, v.z).length())
	return best


func test_the_high_contrast_elite_ring_is_a_thicker_band() -> void:
	assert_float(_min_radius(ActorMeshes.elite_ring(true))).is_less(_min_radius(ActorMeshes.elite_ring(false)) - 0.1)
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var ring_mesh: Mesh = rig.layer.decals().ring_node.multimesh.mesh
	assert_object(ring_mesh).is_same(ActorMeshes.elite_ring(false))
	rig.layer.set_high_contrast(true)
	assert_object(rig.layer.decals().ring_node.multimesh.mesh).is_same(ActorMeshes.elite_ring(true))
	rig.layer.set_high_contrast(false)
	assert_object(rig.layer.decals().ring_node.multimesh.mesh).is_same(ActorMeshes.elite_ring(false))


func test_the_scattergun_fans_eight_streaks_and_kicks_dust() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var base: int = _tracers_after_shot(rig, &"pistol", VisualQuality.Tier.MID)[0]
	var rig2: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var fan: int = _tracers_after_shot(rig2, &"scattergun", VisualQuality.Tier.MID)[0]
	assert_int(fan - base).is_equal(FxWeaponShots.FAN_STREAKS)
	assert_int(rig2.vfx.dust_count()).is_greater(0)


func test_the_rifle_tracer_goes_on_through_its_target() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var base: int = _tracers_after_shot(rig, &"pistol", VisualQuality.Tier.MID)[0]
	var rig2: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	assert_int(_tracers_after_shot(rig2, &"assault_rifle", VisualQuality.Tier.MID)[0] - base).is_equal(1)


func test_the_lmg_throws_brass_on_mid_and_high_and_none_on_low() -> void:
	for tier: int in VfxXTestKit.TIERS:
		var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
		var brass: int = _tracers_after_shot(rig, &"lmg", tier)[1]
		assert_int(brass).is_equal(0 if tier == VisualQuality.Tier.LOW else 1)
	var pistol_rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	assert_int(_tracers_after_shot(pistol_rig, &"pistol", VisualQuality.Tier.HIGH)[1]).is_equal(0)


func test_a_turret_removed_without_an_event_disappears() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	rig.world.turrets.active[0] = 1
	rig.layer.render(1.0, 0.1)
	assert_bool(rig.layer.turrets[0].is_deployed()).is_true()
	rig.world.turrets.active[0] = 0  # single_point takes it away and pushes nothing
	rig.layer.render(1.0, 0.1)
	assert_bool(rig.layer.turrets[0].is_deployed()).is_false()
	assert_bool(rig.layer.turrets[0].visible).is_false()


func _boss_rig(boss_type: int) -> VfxXTestKit.Rig:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var i: int = VfxXTestKit.enemy(rig.world, boss_type, 4.0, -4.0)
	rig.world.boss.boss_id = rig.world.enemies.id[i]
	rig.world.boss.boss_type = boss_type
	rig.layer.render(1.0, 0.016)
	return rig


func test_a_tremor_rig_breach_shows_cracks_at_its_points_until_it_ends() -> void:
	var rig: VfxXTestKit.Rig = _boss_rig(Ids.EN_TREMOR_RIG)
	var tele: FxTelegraph = rig.vfx.chaos().telegraph
	rig.vfx.render(1.0, 0.1)
	assert_int(tele.cracks.live_count()).is_equal(0)  # no breach yet
	var b: BossState = rig.world.boss
	b.timers[BossTremorRig.T_BREACH] = 200
	b.timers[BossTremorRig.T_POINT] = 1
	b.timers[BossTremorRig.T_POINT + 1] = 2
	VfxXTestKit.age(rig.vfx, 0.5)  # the cracks are renewed every 0.4 s
	assert_int(tele.cracks.live_count()).is_equal(2)
	assert_int(tele.hatches.live_count()).is_equal(2)  # the hatched disc is the danger rule of 5.6: red and hatched
	b.timers[BossTremorRig.T_BREACH] = 0
	VfxXTestKit.age(rig.vfx, 1.5)
	assert_int(tele.cracks.live_count()).is_equal(0)


func test_an_open_aegis_window_shows_a_cyan_ring_that_contracts() -> void:
	var rig: VfxXTestKit.Rig = _boss_rig(Ids.EN_AEGIS_ARRAY)
	var tele: FxTelegraph = rig.vfx.chaos().telegraph
	rig.vfx.render(1.0, 0.1)
	assert_int(tele.rings_cyan.live_count()).is_equal(0)  # pylons up: closed
	rig.world.boss.set_flag(BossState.F_EXPOSED, true)
	rig.world.boss.exposed_left = BossKit.ticks(rig.world, &"exposed_s", 10.0)
	rig.vfx.render(1.0, 0.1)
	assert_int(tele.rings_cyan.live_count()).is_greater(0)
	var first: int = -1
	for s: int in tele.rings_cyan.capacity:
		if tele.rings_cyan.progress(s) >= 0.0:
			first = s
	var wide: float = tele.rings_cyan.slot_transform(first).basis.x.length()
	rig.world.boss.exposed_left = int(float(rig.world.boss.exposed_left) * 0.1)
	VfxXTestKit.age(rig.vfx, 0.3)
	rig.vfx.render(1.0, 0.1)
	var last: int = -1
	for s: int in tele.rings_cyan.capacity:
		if tele.rings_cyan.progress(s) >= 0.0:
			last = s
	assert_float(tele.rings_cyan.slot_transform(last).basis.x.length()).is_less(wide)
