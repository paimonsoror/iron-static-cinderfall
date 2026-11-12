extends GdUnitTestSuite
## V2-F blasts (VARIETY_SPEC 10.3, 10.4, 12.3): a ring per `area_blast`, a flash on MID and HIGH, four streaks on HIGH, pools sized by
## tier, drop-the-oldest, a blast never draws on a slot that was already used in the same frame, Reduced Flash removes the flash, and
## nothing is allocated after setup.

const BLASTS: int = 40


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _blasts(vfx: VfxLayer) -> FxBlasts:
	return vfx.chaos().blasts


func test_the_visual_quality_tables_are_the_numbers_of_the_spec() -> void:
	var tiers: Array[int] = [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]
	var want_rings: Array[int] = [8, 12, 16]
	var want_flash: Array[int] = [0, 8, 12]
	var want_streaks: Array[int] = [0, 0, 4]
	var want_arcs: Array[int] = [18, 30, 45]
	for t: int in tiers:
		assert_int(VisualQuality.blast_rings(t)).is_equal(want_rings[t])
		assert_int(VisualQuality.blast_flashes(t)).is_equal(want_flash[t])
		assert_int(VisualQuality.blast_streaks(t)).is_equal(want_streaks[t])
		assert_int(VisualQuality.arc_segments(t)).is_equal(want_arcs[t])
		assert_int(VisualQuality.telegraph_decals(t)).is_equal(8)  # what can hurt you is always drawn, on every tier
		assert_int(VisualQuality.mini_bodies(t)).is_equal(40)
	assert_int(VisualQuality.blast_rings(99)).is_equal(16)  # clamped like every tier lookup


func test_a_pool_limit_stops_the_slots_beyond_it_and_allocates_nothing() -> void:
	var pool: VfxPool = VarietyFKit.pool(self, 10, VfxPool.Mode.FLAT)
	for n: int in 10:
		var _s: int = pool.spawn(Vector3(float(n), 0.0, 0.0), Vector3.ZERO, 1.0, 1.0, 5.0)
	assert_int(pool.live_count()).is_equal(10)
	var slots: Array[int] = []
	slots.resize(9)
	var objects: int = VarietyFKit.objects()
	pool.set_limit(4)
	for n: int in 9:
		slots[n] = pool.spawn(Vector3.ZERO, Vector3.ZERO, 1.0, 1.0, 5.0)
	pool.set_limit(10)
	var grown: int = VarietyFKit.objects() - objects  # measured before the first assert: an assertion is an object too
	assert_int(grown).is_less_equal(1)  # limiting and unlimiting a pool allocates nothing
	pool.set_limit(4)
	assert_int(pool.live_count()).is_equal(4)  # slots 4..9 were stopped
	assert_int(pool.capacity).is_equal(10)  # allocated once, never resized
	assert_int(pool.limit).is_equal(4)
	for s: int in slots:
		assert_int(s).is_between(0, 3)  # only the first four slots are ever used
	pool.set_limit(0)
	assert_int(pool.live_count()).is_equal(0)
	assert_int(pool.spawn(Vector3.ZERO, Vector3.ZERO, 1.0, 1.0, 1.0)).is_equal(-1)  # a pool limited to nothing draws nothing
	pool.set_limit(99)
	assert_int(pool.limit).is_equal(10)  # clamped to the allocation


func test_a_blast_is_a_ring_a_flash_and_streaks_by_tier() -> void:
	var rig: Array = VarietyFKit.rig(self)
	var vfx: VfxLayer = rig[2]
	var want_flashes: Array[int] = [0, 1, 1]
	var want_streaks: Array[int] = [0, 0, 4]
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		VarietyFKit.age(vfx, 1.5)
		var sparks: int = vfx.spark_count()
		Events.area_blast.emit(HazardState.K_BLAST, 4.0, -2.0, 2.6)
		assert_int(_blasts(vfx).rings_amber.live_count()).is_equal(1)
		assert_int(_blasts(vfx).rings_cyan.live_count()).is_equal(0)
		assert_int(_blasts(vfx).flashes.live_count()).is_equal(want_flashes[tier])
		assert_int(vfx.spark_count() - sparks).is_equal(want_streaks[tier])


func test_ours_is_cyan_and_theirs_is_amber() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	for kind: int in [HazardState.K_BLAST, HazardState.K_SHELL, HazardState.K_MISSILE, HazardState.K_DRUM]:
		Events.area_blast.emit(kind, 1.0, 1.0, 2.0)
	assert_int(_blasts(vfx).rings_amber.live_count()).is_equal(4)
	assert_int(_blasts(vfx).rings_cyan.live_count()).is_equal(0)
	assert_int(_blasts(vfx).flashes_cyan.live_count()).is_equal(0)  # their flash is amber
	for kind: int in [HazardState.K_STRIKE, HazardState.K_VENT]:  # the Deadfall Strike and the Core Vent are ours
		Events.area_blast.emit(kind, 1.0, 1.0, 4.0)
	assert_int(_blasts(vfx).rings_cyan.live_count()).is_equal(2)
	assert_int(_blasts(vfx).flashes_cyan.live_count()).is_equal(2)  # ... and so is the colour of our flash, the ring's colour
	assert_int(_blasts(vfx).flashes.live_count()).is_equal(4)


func test_pool_caps_by_tier_and_the_surplus_is_dropped() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var want_rings: Array[int] = [8, 12, 16]
	var want_flash: Array[int] = [0, 8, 12]
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		VarietyFKit.age(vfx, 1.5)
		var dropped: int = _blasts(vfx).dropped
		for n: int in BLASTS:
			Events.area_blast.emit(HazardState.K_BLAST, float(n % 8), float(floori(float(n) / 8.0)), 2.6)
		assert_int(_blasts(vfx).rings_amber.live_count()).is_equal(want_rings[tier])
		assert_int(_blasts(vfx).rings_amber.limit).is_equal(want_rings[tier])
		assert_int(_blasts(vfx).rings_amber.capacity).is_equal(16)  # allocated once for HIGH
		assert_int(_blasts(vfx).flashes.live_count()).is_equal(want_flash[tier])
		assert_int(_blasts(vfx).dropped - dropped).is_equal(BLASTS - want_rings[tier])
		assert_int(vfx.spark_count()).is_less_equal(64)  # the streaks share the spark pool and respect its cap


func test_a_blast_never_draws_on_a_recycled_slot_twice_in_a_frame() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var blasts: FxBlasts = _blasts(vfx)
	vfx.set_quality(VisualQuality.Tier.MID)  # 12 slots
	var slots: Array[int] = []
	for n: int in 20:
		slots.append(blasts.ring(false, Vector3(float(n), 0.0, 0.0), 1.0, 2.0, 1.0))
	var seen: Dictionary[int, bool] = {}
	for n: int in 20:
		if n < 12:
			assert_bool(seen.has(slots[n])).is_false()  # every slot of the frame is a different one
			seen[slots[n]] = true
		else:
			assert_int(slots[n]).is_equal(-1)  # the surplus is dropped, never written over a blast of this frame
	assert_int(blasts.rings_amber.live_count()).is_equal(12)
	vfx.render(1.0, 0.016)  # the frame is over
	assert_float(blasts.rings_amber.slot_transform(slots[0]).origin.x).is_equal_approx(0.0, 0.0001)  # the first blast is still there
	assert_float(blasts.rings_amber.slot_transform(slots[11]).origin.x).is_equal_approx(11.0, 0.0001)
	var next: int = blasts.ring(false, Vector3(50.0, 0.0, 0.0), 1.0, 2.0, 1.0)
	assert_int(next).is_equal(slots[0])  # in the next frame the OLDEST slot is recycled (ARCH 13)
	assert_float(blasts.rings_amber.slot_transform(next).origin.x).is_equal_approx(50.0, 0.0001)


func test_the_same_rule_holds_for_blasts_sent_as_events_between_two_frames() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	vfx.set_quality(VisualQuality.Tier.LOW)  # 8 slots
	for n: int in 14:
		Events.area_blast.emit(HazardState.K_BLAST, float(n), 0.0, 2.0)
	vfx.render(1.0, 0.016)
	var pool: VfxPool = _blasts(vfx).rings_amber
	var xs: Array[float] = []
	for slot: int in 8:
		xs.append(pool.slot_transform(slot).origin.x)
	for n: int in 8:
		assert_bool(xs.has(float(n))).override_failure_message("blast %d lost its slot" % n).is_true()
	for n: int in range(8, 14):
		assert_bool(xs.has(float(n))).is_false()


func test_reduced_flash_removes_the_flash_and_dims_the_ring() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	var lit: float = _blasts(vfx).rings_amber.mesh_alpha()
	Events.area_blast.emit(HazardState.K_BLAST, 1.0, 1.0, 2.6)
	assert_int(_blasts(vfx).flashes.live_count()).is_equal(1)
	VarietyFKit.age(vfx, 1.0)
	vfx.set_reduced_flash(true)
	assert_float(_blasts(vfx).rings_amber.mesh_alpha()).is_less(lit * 0.6)
	assert_float(_blasts(vfx).rings_cyan.mesh_alpha()).is_less(lit * 0.6)
	Events.area_blast.emit(HazardState.K_BLAST, 1.0, 1.0, 2.6)
	Events.area_blast.emit(HazardState.K_STRIKE, 2.0, 1.0, 4.0)
	assert_int(_blasts(vfx).flashes.live_count() + _blasts(vfx).flashes_cyan.live_count()).is_equal(0)  # no flash at all
	assert_int(_blasts(vfx).rings_amber.live_count()).is_equal(1)  # the ring is still the information
	assert_int(_blasts(vfx).rings_cyan.live_count()).is_equal(1)
	vfx.set_reduced_flash(false)
	assert_float(_blasts(vfx).rings_amber.mesh_alpha()).is_equal(lit)


func test_a_flash_is_short_and_small_enough_never_to_wash_out_an_optic() -> void:
	assert_float(FxBlasts.FLASH_LIFE_S).is_less_equal(0.25)  # GDD 6.7 / SPEC 5.6 rule 2: at most the 0.25 s of a blast flash
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	Events.area_blast.emit(HazardState.K_STRIKE, 0.0, 0.0, 12.0)  # the biggest blast there is
	var flash_progress: float = _blasts(vfx).flashes_cyan.progress(0)
	assert_float(flash_progress).is_between(0.0, 0.2)
	vfx.render(1.0, 0.0)
	vfx.render(1.0, 0.1)
	assert_int(_blasts(vfx).flashes_cyan.live_count()).is_equal(1)
	vfx.render(1.0, 0.1)
	assert_int(_blasts(vfx).flashes_cyan.live_count()).is_equal(0)  # gone before 0.25 s
	var arena: ArenaDef = TestContent.variety().arena
	var yard_m2: float = (arena.max_x - arena.min_x) * (arena.max_z - arena.min_z)
	var biggest: float = PI * 2.6 * 2.6  # the largest flash star, in square meters of ground
	assert_float(biggest / yard_m2).is_less(0.05)  # a flash over 5 percent of the screen would have to be removed by Reduced Flash
	var ring: ArrayMesh = VfxMeshes.ring(0.72, 40, &"add_amber", &"add_white")
	assert_int(VfxMeshes.triangles(ring)).is_less(200)  # a ring is a band: the inside of a blast (where the optics are) stays clear


func test_the_streaks_come_from_the_spark_pool_on_high_only() -> void:
	var vfx: VfxLayer = VarietyFKit.rig(self)[2]
	vfx.set_quality(VisualQuality.Tier.HIGH)
	var before: int = vfx.spark_count()
	for n: int in 6:
		Events.area_blast.emit(HazardState.K_BLAST, float(n), 0.0, 2.6)
	assert_int(vfx.spark_count() - before).is_equal(24)  # a 6 blast chain: 4 streaks each
	VarietyFKit.age(vfx, 1.0)
	assert_int(vfx.spark_count()).is_equal(0)


func test_blasts_arcs_and_telegraphs_allocate_nothing_after_setup() -> void:
	var rig: Array = VarietyFKit.rig(self)
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var vfx: VfxLayer = rig[2]
	var ids: Array[int] = VarietyFKit.spawn(w, Ids.EN_SKITTER, 6)
	layer.render(1.0, 0.016)
	var nodes: int = ActorsTestKit.count_nodes(vfx)
	for n: int in 200:  # warm up: lazy engine-side allocations settle here
		Events.area_blast.emit(HazardState.K_BLAST, float(n % 9), 1.0, 2.6)
		Events.chain_arc.emit(ids[n % 6], ids[(n + 1) % 6])
		vfx.render(1.0, 0.016)
	var objects: int = VarietyFKit.objects()
	for n: int in 500:
		Events.area_blast.emit(HazardState.K_BLAST if n % 3 != 0 else HazardState.K_STRIKE, float(n % 9), 1.0, 2.6)
		Events.chain_arc.emit(0 if n % 5 == 0 else ids[n % 6], ids[(n + 1) % 6])
		Events.delayed_hit.emit(HazardState.K_STRIKE if n % 4 == 0 else HazardState.K_SHELL, 2.0, 1.0, 30)
		Events.pool_changed.emit(n % 7, float(n % 5), 2.0, 2.0, n % 2 == 0)
		Events.event_warned.emit(&"deadfall_strike", 40, float(n % 5), 3.0)
		vfx.render(1.0, 0.016)
	var grown: int = VarietyFKit.objects() - objects  # measured before the first assert: an assertion is an object too
	assert_int(ActorsTestKit.count_nodes(vfx)).is_equal(nodes)
	assert_int(grown).is_less_equal(2)  # the counter test: 500 frames of chaos, nothing created
	assert_int(_blasts(vfx).rings_amber.live_count() + _blasts(vfx).rings_cyan.live_count()).is_less_equal(32)
