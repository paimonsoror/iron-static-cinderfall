extends GdUnitTestSuite
## V4-X tier tables (ARCH 13.2, VARIETY_SPEC 10.3 and 10.4): every pool is allocated once at its HIGH size and limited by the tier; what can
## hurt the player's side is never tier-gated; Reduced Flash removes flashes and shake; the cosmetic extras grow from none to full.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func test_the_tier_tables_are_the_numbers_of_the_architecture() -> void:
	var want: Dictionary = {
		"lob": [12, 18, 24], "bolt": [12, 12, 12], "beam": [2, 2, 3], "pool": [6, 8, 10], "ward": [8, 10, 12],
		"elite": [4, 4, 4], "tether": [6, 9, 12], "scorch": [0, 8, 16], "ghost": [0, 40, 80],
	}
	for t: int in VfxXTestKit.TIERS:
		assert_int(VisualQuality.lob_cap(t)).is_equal(want["lob"][t])
		assert_int(VisualQuality.bolt_cap(t)).is_equal(want["bolt"][t])
		assert_int(VisualQuality.beam_cap(t)).is_equal(want["beam"][t])
		assert_int(VisualQuality.pool_cap(t)).is_equal(want["pool"][t])
		assert_int(VisualQuality.ward_rings(t)).is_equal(want["ward"][t])
		assert_int(VisualQuality.elite_rings(t)).is_equal(want["elite"][t])
		assert_int(VisualQuality.tethers(t)).is_equal(want["tether"][t])
		assert_int(VisualQuality.scorch_marks(t)).is_equal(want["scorch"][t])
		assert_int(VisualQuality.ghost_swarm(t)).is_equal(want["ghost"][t])
	assert_int(VisualQuality.lob_cap(99)).is_equal(24)  # clamped like every tier lookup
	assert_float(VisualQuality.shake_gain(VisualQuality.Tier.LOW)).is_equal(0.0)
	assert_float(VisualQuality.shake_gain(VisualQuality.Tier.MID)).is_between(0.1, 0.9)
	assert_float(VisualQuality.shake_gain(VisualQuality.Tier.HIGH)).is_equal(1.0)
	assert_int(VisualQuality.embers(VisualQuality.Tier.LOW)).is_equal(0)
	assert_int(VisualQuality.embers_per_blast(VisualQuality.Tier.MID)).is_less(VisualQuality.embers_per_blast(VisualQuality.Tier.HIGH))
	assert_int(VisualQuality.rain_burst(VisualQuality.Tier.LOW)).is_equal(0)


func test_every_pool_is_allocated_at_its_high_size_and_limited_by_the_tier() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var c: FxChaos = vfx.chaos()
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		assert_int(c.beams.beams.limit).is_equal(VisualQuality.beam_cap(t))
		assert_int(c.lobs.shells.limit + c.lobs.hornets.limit).is_equal(VisualQuality.lob_cap(t))
		assert_int(c.lobs.bolts.limit).is_equal(12)  # an enemy projectile is never tier-gated
		assert_int(c.zones.rings.limit).is_equal(VisualQuality.ward_rings(t))
		assert_int(c.zones.tethers.limit).is_equal(VisualQuality.tethers(t))
		assert_int(c.cosmetic.scorch.limit).is_equal(VisualQuality.scorch_marks(t))
		assert_int(c.cosmetic.ghosts.limit()).is_equal(VisualQuality.ghost_swarm(t))
		assert_int(c.ground.limit()).is_equal(VisualQuality.pool_cap(t))
		assert_int(c.telegraph.hatches.limit).is_equal(8)  # telegraph decals: the same 8 on every tier
	assert_int(c.beams.beams.capacity).is_equal(3)
	assert_int(c.lobs.shells.capacity + c.lobs.hornets.capacity).is_equal(24)
	assert_int(c.zones.rings.capacity).is_equal(12)
	assert_int(c.zones.tethers.capacity).is_equal(12)
	assert_int(c.cosmetic.scorch.capacity).is_equal(16)
	assert_int(c.cosmetic.ghosts.limit()).is_equal(80)


func test_a_danger_decal_and_an_enemy_projectile_are_drawn_on_every_tier() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var content: ContentSet = rig.world.content
	content.events[content.event_index(&"deadfall_strike")].harmful = true  # stands in for a harmful world event
	var seen: Array[int] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 3.0)
		Events.event_warned.emit(&"deadfall_strike", 60, 1.0, 1.0)
		Events.event_warned.emit(&"floor_breach", 60, 2.0, 2.0)
		Events.event_warned.emit(&"recount", 60, 10.0, 0.0)
		Events.delayed_hit.emit(HazardState.K_BOLT, -7.0, 3.0, 40)
		var c: FxChaos = vfx.chaos()
		assert_int(c.telegraph.hatches.live_count()).is_equal(3)  # the zone, the breach and the bolt's ring
		assert_int(c.telegraph.bands.live_count()).is_equal(1)
		assert_int(c.telegraph.cracks.live_count()).is_equal(1)
		assert_int(c.lobs.bolts.live_count()).is_equal(1)  # the bolt itself
		seen.append(c.telegraph.live_count() + c.lobs.live_count())
	assert_int(seen[0]).is_equal(seen[1])
	assert_int(seen[1]).is_equal(seen[2])


func test_reduced_flash_removes_the_flashes_the_shake_and_the_strike_column() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var c: FxChaos = vfx.chaos()
	vfx.set_quality(VisualQuality.Tier.HIGH)
	Events.area_blast.emit(HazardState.K_STRIKE, 2.0, 2.0, 4.0)
	assert_int(c.blasts.flashes_cyan.live_count()).is_equal(1)
	assert_int(c.strike.column.live_count()).is_equal(1)
	assert_float(c.cosmetic.trauma).is_greater(0.0)
	VfxXTestKit.age(vfx, 2.0)
	vfx.set_reduced_flash(true)
	assert_float(c.cosmetic.trauma).is_equal(0.0)
	Events.area_blast.emit(HazardState.K_STRIKE, 2.0, 2.0, 4.0)
	Events.area_blast.emit(HazardState.K_BLAST, 3.0, 2.0, 2.6)
	assert_int(c.blasts.flashes_cyan.live_count() + c.blasts.flashes.live_count()).is_equal(0)
	assert_int(c.strike.column.live_count()).is_equal(0)
	assert_float(c.cosmetic.trauma).is_equal(0.0)
	assert_int(c.blasts.rings_cyan.live_count() + c.blasts.rings_amber.live_count()).is_greater(0)  # the ring stays: it is the information
	vfx.render(1.0, 0.05)
	assert_float(c.cosmetic.shake_offset().length()).is_equal(0.0)
	vfx.set_reduced_flash(false)
	Events.area_blast.emit(HazardState.K_STRIKE, 2.0, 2.0, 4.0)
	assert_float(c.cosmetic.trauma).is_greater(0.0)


func test_the_shake_grows_with_the_tier_and_stays_inside_its_limit() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var c: FxChaos = vfx.chaos()
	var peaks: Array[float] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 1.0)
		c.cosmetic.shake(1.0)
		var peak: float = 0.0
		for _n: int in 12:
			vfx.render(1.0, 0.01)
			peak = maxf(peak, c.cosmetic.shake_offset().length())
		peaks.append(peak)
		assert_float(peak).is_less_equal(FxCosmetic.SHAKE_MAX_M * 1.5 * VisualQuality.shake_gain(t) + 0.0001)
	assert_float(peaks[0]).is_equal(0.0)  # none on LOW
	assert_float(peaks[1]).is_greater(0.0)
	assert_float(peaks[2]).is_greater(peaks[1])  # light on MID, full on HIGH


func test_the_shake_moves_the_camera_and_gives_it_back() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var c: FxChaos = vfx.chaos()
	var cam: Camera3D = c.ctx.rig.camera
	vfx.set_quality(VisualQuality.Tier.HIGH)
	c.cosmetic.shake(1.0)
	var moved: bool = false
	for _n: int in 10:
		vfx.render(1.0, 0.01)
		moved = moved or absf(cam.h_offset) + absf(cam.v_offset) > 0.001
	assert_bool(moved).is_true()
	VfxXTestKit.age(vfx, 2.0)
	assert_float(cam.h_offset).is_equal(0.0)
	assert_float(cam.v_offset).is_equal(0.0)
	c.cosmetic.shake(1.0)
	vfx.unbind()
	assert_float(cam.h_offset).is_equal(0.0)  # an unbound layer never leaves the camera shaken


func test_cosmetic_chaos_grows_from_none_to_full() -> void:
	var vfx: VfxLayer = VfxXTestKit.rig(self).vfx
	var c: FxChaos = vfx.chaos()
	var embers: Array[int] = []
	var marks: Array[int] = []
	var rain: Array[int] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 2.0)
		var before: int = c.cosmetic.marks
		for n: int in 20:
			Events.area_blast.emit(HazardState.K_BLAST, float(n % 7) - 3.0, float(n % 5), 2.0)
			vfx.render(1.0, 0.0)
		embers.append(c.cosmetic.embers.live_count())
		marks.append(c.cosmetic.scorch.live_count())
		assert_int(c.cosmetic.marks - before).is_equal(20 if t != VisualQuality.Tier.LOW else 0)
		Events.event_started.emit(&"deadfall_strike")  # a player event: no downpour
		var drops: int = c.cosmetic.rain.live_count()
		c.cosmetic.event_started()
		rain.append(c.cosmetic.rain.live_count() - drops)
	assert_array(embers).is_equal([0, 24, 48])  # 2 and 4 per blast, the pool of the tier is the limit
	assert_array(marks).is_equal([0, 8, 16])
	assert_array(rain).is_equal([0, 24, 48])


func test_nothing_is_allocated_after_setup_while_the_new_effects_run() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var ids: Array[int] = VarietyFKit.spawn(w, Ids.EN_SKITTER, 8)
	rig.layer.render(1.0, 0.016)
	var nodes: int = ActorsTestKit.count_nodes(vfx)
	Sfx.disabled = true
	for n: int in 200:  # warm up: lazy engine-side allocations settle here
		Events.area_blast.emit(HazardState.K_BLAST, float(n % 9), 1.0, 1.2)
		Events.delayed_hit.emit(HazardState.K_SHELL, float(n % 9), 2.0, 30)
		vfx.render(1.0, 0.016)
	var objects: int = VarietyFKit.objects()
	for n: int in 500:
		Events.area_blast.emit(HazardState.K_BLAST if n % 3 != 0 else HazardState.K_STRIKE, float(n % 9), 1.0, 1.2)
		Events.delayed_hit.emit(HazardState.K_MISSILE if n % 2 == 0 else HazardState.K_BOLT, float(n % 9), 2.0, 30)
		Events.event_warned.emit(&"runaway_freight" if n % 4 == 0 else &"floor_breach", 40, float(n % 5), 3.0)
		Events.event_started.emit(&"runaway_freight")
		Events.boss_telegraph.emit(0, 30)
		Events.ward_changed.emit(ids[n % 8], float(n % 2))
		vfx.render(1.0, 0.016)
	var grown: int = VarietyFKit.objects() - objects
	Sfx.disabled = false
	assert_int(ActorsTestKit.count_nodes(vfx)).is_equal(nodes)
	assert_int(grown).is_less_equal(2)
