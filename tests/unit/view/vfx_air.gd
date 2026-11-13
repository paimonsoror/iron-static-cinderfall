extends GdUnitTestSuite
## V4-X things in the air and beams (SPEC 3.5, 10.3 `fx_beam`, `fx_lob`) and the telegraphs of the bosses (SPEC 6): the torch ribbon follows its
## target, the lance charges thin and fires thick, shells and hornets fly in exactly the ticks the sim gives, a spitter's bolt is red and never
## tier-gated, a boss telegraph is red, hatched where it covers ground, and drawn on every tier.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


func _frame(rig: VfxXTestKit.Rig) -> void:
	rig.layer.render(1.0, 0.016)
	rig.vfx.render(1.0, 0.016)


## `n` frames of exactly 0.1 s (the first draw of an effect does not age it, so `n` steps are `n` tenths of a second).
func _steps(vfx: VfxLayer, n: int) -> void:
	for _k: int in n:
		vfx.render(1.0, 0.1)


func _chaos(rig: VfxXTestKit.Rig) -> FxChaos:
	return rig.vfx.chaos()


func _live_slot(pool: VfxPool) -> int:
	for s: int in pool.capacity:
		if pool.progress(s) >= 0.0:
			return s
	return -1


func test_the_torch_ribbon_follows_its_target_thickens_with_the_ramp_and_ends_with_the_lock() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var i: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -5.0, -3.0)
	w.warden.weapon_index = Ids.WP_CUTTING_TORCH
	w.arsenal.beam_target = w.enemies.id[i]
	w.arsenal.beam_hits = 0
	_frame(rig)
	var beams: FxBeams = _chaos(rig).beams
	assert_int(beams.beams.live_count()).is_equal(1)
	var thin: float = beams.beams.slot_transform(_live_slot(beams.beams)).basis.x.length()
	w.arsenal.beam_hits = 12
	for _n: int in 30:
		_frame(rig)
	assert_int(beams.beams.live_count()).is_equal(1)  # one slot follows: the ribbon never piles up
	var thick: float = beams.beams.slot_transform(_live_slot(beams.beams)).basis.x.length()
	assert_float(thick).is_greater(thin)
	assert_float(thick).is_less_equal(FxBeams.TORCH_WIDTH_MAX_M)
	assert_float(FxBeams.TORCH_WIDTH_MAX_M).is_less(2.0 * FxBoss.LANCE_HALF_WIDTH_M)  # a friendly beam is thinner than a danger decal is wide
	var end: Vector3 = beams.beams.slot_transform(_live_slot(beams.beams)).origin
	assert_float(end.x).is_between(-5.5, -0.5)  # its middle lies between the muzzle and the target
	w.enemies.x[i] = 4.0
	w.enemies.prev_x[i] = 4.0
	for _n: int in 3:
		_frame(rig)
	assert_float(beams.beams.slot_transform(_live_slot(beams.beams)).origin.x).is_greater(end.x)  # it followed the target
	w.arsenal.beam_target = 0  # the lock is gone
	_frame(rig)
	assert_int(beams.beams.live_count()).is_equal(0)
	w.warden.weapon_index = Ids.WP_PISTOL
	w.arsenal.beam_target = w.enemies.id[i]  # another weapon in hand: the stale lock draws nothing
	_frame(rig)
	assert_int(beams.beams.live_count()).is_equal(0)


func test_a_torch_shot_is_a_ribbon_and_sparks_not_a_tracer() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var i: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -5.0, -3.0)
	w.warden.weapon_index = Ids.WP_CUTTING_TORCH
	_frame(rig)
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[i])
	assert_int(vfx.tracer_count()).is_equal(0)
	assert_int(vfx.muzzle_count()).is_equal(0)
	assert_int(vfx.spark_count()).is_greater(0)  # sparks at the contact point
	w.warden.weapon_index = Ids.WP_PISTOL
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[i])
	assert_int(vfx.tracer_count()).is_equal(1)  # every other weapon keeps its tracer


func test_the_lance_charges_a_thin_line_and_fires_a_thick_white_one_with_sparks_on_the_line() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var a: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -3.0, 2.0)
	var _b: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 4.0, -2.5)  # not on the line
	var _off: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 8.0, 8.0)  # not on the line
	w.warden.weapon_index = Ids.WP_RAIL_LANCE
	w.arsenal.charge_left = 40
	w.arsenal.charge_x = -3.0
	w.arsenal.charge_z = 2.0
	_frame(rig)
	var beams: FxBeams = _chaos(rig).beams
	assert_int(beams.beams.live_count()).is_equal(1)
	var charge: float = beams.beams.slot_transform(_live_slot(beams.beams)).basis.x.length()
	assert_float(charge).is_less_equal(FxBeams.CHARGE_WIDTH_M + 0.0001)
	w.arsenal.charge_left = 0
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[a])
	assert_int(vfx.tracer_count()).is_equal(0)
	assert_int(beams.shots).is_equal(1)
	assert_int(beams.beams.live_count()).is_equal(2)  # the charge line (until the next frame retires it) and the shot
	var shot_slot: int = -1
	for s: int in beams.beams.capacity:
		if beams.beams.progress(s) >= 0.0 and beams.beams.slot_transform(s).basis.x.length() > charge * 2.0:
			shot_slot = s
	assert_int(shot_slot).is_greater_equal(0)
	assert_float(beams.beams.slot_transform(shot_slot).basis.x.length()).is_equal_approx(FxBeams.SHOT_WIDTH_M, 0.001)
	assert_float(beams.beams.slot_transform(shot_slot).basis.z.length()).is_greater(20.0)  # it runs to the end of its range
	assert_int(vfx.spark_count()).is_equal(VfxLayer.SPARKS_PER_HIT[VisualQuality.Tier.HIGH] + 2)  # the contact sparks and two at the one enemy on the line
	_steps(vfx, 3)
	assert_int(beams.beams.live_count()).is_equal(0)  # 0.12 s: gone


func test_beams_are_pooled_two_two_three_and_reduced_flash_dims_them() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var beams: FxBeams = _chaos(rig).beams
	var lit: float = beams.beams.mesh_alpha()
	rig.vfx.set_reduced_flash(true)
	assert_float(beams.beams.mesh_alpha()).is_less(lit * 0.6)
	rig.vfx.set_reduced_flash(false)
	assert_float(beams.beams.mesh_alpha()).is_equal(lit)
	var want: Array[int] = [2, 2, 3]
	for t: int in VfxXTestKit.TIERS:
		rig.vfx.set_quality(t)
		assert_int(beams.beams.limit).is_equal(want[t])


func test_a_shell_flies_its_arc_for_exactly_the_ticks_the_sim_gives() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var lobs: FxLobs = _chaos(rig).lobs
	Events.delayed_hit.emit(HazardState.K_SHELL, 6.0, -4.0, 42)  # a slag shell: 0.7 s
	assert_int(lobs.shells.live_count()).is_equal(1)
	assert_int(lobs.hornets.live_count() + lobs.bolts.live_count()).is_equal(0)
	assert_object(lobs.shells.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_amber"))
	vfx.render(1.0, 0.0)
	var slot: int = _live_slot(lobs.shells)
	var start: Vector3 = lobs.shells.slot_transform(slot).origin
	_steps(vfx, 3)
	var mid: Vector3 = lobs.shells.slot_transform(slot).origin
	assert_float(mid.y).is_greater(start.y + 1.0)  # up on an arc ...
	assert_float(mid.x).is_between(minf(start.x, 6.0), maxf(start.x, 6.0))
	_steps(vfx, 3)
	assert_int(lobs.shells.live_count()).is_equal(1)  # still in the air at 0.6 s
	_steps(vfx, 2)
	assert_int(lobs.shells.live_count()).is_equal(0)  # landed at 0.7 s: the blast and its ring take over
	assert_int(lobs.launched).is_equal(1)


func test_a_hornet_salvo_is_six_small_cyan_balls_capped_by_the_tier() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var vfx: VfxLayer = rig.vfx
	var lobs: FxLobs = _chaos(rig).lobs
	for n: int in 6:
		Events.delayed_hit.emit(HazardState.K_MISSILE, 2.0 + float(n), -3.0, 30)
	assert_int(lobs.hornets.live_count()).is_equal(6)
	assert_object(lobs.hornets.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_cyan"))
	vfx.render(1.0, 0.0)
	var xs: Dictionary[float, bool] = {}
	for s: int in lobs.hornets.capacity:
		if lobs.hornets.progress(s) >= 0.0:
			xs[snappedf(lobs.hornets.slot_transform(s).origin.x, 0.01)] = true
	assert_int(xs.size()).is_greater(1)  # they fan out of the rack, not one ball six times
	VfxXTestKit.age(vfx, 1.0)
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		for _n: int in 40:
			Events.delayed_hit.emit(HazardState.K_MISSILE, 3.0, -3.0, 60)
		assert_int(lobs.hornets.live_count()).is_equal(VisualQuality.lob_cap(t) - lobs.shells.limit)
		VfxXTestKit.age(vfx, 1.2)


func test_a_spitter_bolt_is_red_starts_at_its_spitter_and_is_never_tier_gated() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var lobs: FxLobs = _chaos(rig).lobs
	var s: int = VfxXTestKit.enemy(w, Ids.EN_SPITTER, 4.0, 2.0)
	w.ext.aux_cd[s] = 100  # it fired just now
	_frame(rig)
	Events.delayed_hit.emit(HazardState.K_BOLT, -6.0, 3.0, 48)
	assert_int(lobs.bolts.live_count()).is_equal(1)
	assert_object(lobs.bolts.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_red"))
	vfx.render(1.0, 0.0)
	assert_float(lobs.bolts.slot_transform(_live_slot(lobs.bolts)).origin.x).is_equal_approx(4.0, 0.2)
	var counts: Array[int] = []
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 1.5)
		for _n: int in 12:
			Events.delayed_hit.emit(HazardState.K_BOLT, -6.0, 3.0, 48)
		counts.append(lobs.bolts.live_count())
	assert_array(counts).is_equal([12, 12, 12])
	Events.delayed_hit.emit(HazardState.K_FREIGHT, 1.0, 1.0, 30)  # kinds that fly nothing draw nothing
	Events.delayed_hit.emit(HazardState.K_DRUM, 1.0, 1.0, 30)
	assert_int(lobs.shells.live_count() + lobs.hornets.live_count()).is_equal(0)


func test_a_lance_platform_telegraph_is_a_hatched_strip_to_the_core_and_then_a_red_beam() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var arena: ArenaDef = w.content.arena
	var i: int = VfxXTestKit.enemy(w, Ids.EN_LANCE_PLATFORM, 6.0, 3.0)
	w.boss.boss_id = w.enemies.id[i]
	_frame(rig)
	var boss: FxBoss = _chaos(rig).boss
	Events.boss_telegraph.emit(0, 180)  # the 3 s charge
	assert_int(boss.lance_hatch.live_count()).is_equal(1)
	assert_int(_chaos(rig).telegraph.lanes_red.live_count()).is_equal(2)
	assert_object(boss.lance_hatch.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"hatch_red"))
	vfx.render(1.0, 0.0)
	var strip: Transform3D = boss.lance_hatch.slot_transform(_live_slot(boss.lance_hatch))
	var mid: Vector2 = Vector2((6.0 + arena.core_x) * 0.5, (3.0 + arena.core_z) * 0.5)
	assert_float(strip.origin.x).is_equal_approx(mid.x, 0.3)  # from the boss to the core
	assert_float(strip.basis.x.length()).is_equal_approx(Vector2(6.0 - arena.core_x, 3.0 - arena.core_z).length() * 0.5, 0.5)
	assert_float(strip.basis.z.length() * 2.0).is_greater(FxBeams.TORCH_WIDTH_MAX_M)  # the zone is wider than any friendly beam
	_steps(vfx, 26)
	assert_int(boss.fire.live_count()).is_equal(0)  # the shot leaves when the 3 s charge ends, not before
	_steps(vfx, 5)
	assert_int(boss.fire.live_count()).is_equal(1)
	assert_object(boss.fire.node.multimesh.mesh.surface_get_material(0)).is_same(MatLib.mat(&"add_red"))
	_steps(vfx, 5)
	assert_int(boss.fire.live_count()).is_equal(0)


func test_a_tremor_stomp_is_an_expanding_red_ring_and_a_hulk_charge_a_hatched_lane() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var tele: FxTelegraph = _chaos(rig).telegraph
	var rig_i: int = VfxXTestKit.enemy(w, Ids.EN_TREMOR_RIG, 4.0, -2.0)
	w.boss.boss_id = w.enemies.id[rig_i]
	_frame(rig)
	Events.boss_telegraph.emit(0, 90)  # the 1.5 s wind-up of a stomp
	assert_int(tele.rings_red.live_count()).is_equal(1)
	vfx.render(1.0, 0.0)
	var slot: int = _live_slot(tele.rings_red)
	var small: float = tele.rings_red.slot_transform(slot).basis.x.length()
	_steps(vfx, 8)
	assert_float(tele.rings_red.slot_transform(slot).basis.x.length()).is_greater(small * 3.0)  # it expands
	_steps(vfx, 10)
	assert_int(tele.rings_red.live_count()).is_equal(0)
	w.kill_enemy(rig_i, DamageSource.Id.WARDEN)
	var hulk: int = VfxXTestKit.enemy(w, Ids.EN_HULK, 5.0, 0.0)
	w.boss.boss_id = w.enemies.id[hulk]
	_frame(rig)
	Events.boss_telegraph.emit(1, 90)
	assert_int(tele.bands.live_count()).is_equal(1)
	assert_int(tele.lanes_red.live_count()).is_equal(2)


func test_a_boss_telegraph_is_never_tier_gated_and_nothing_is_drawn_without_a_boss() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var vfx: VfxLayer = rig.vfx
	var boss: FxBoss = _chaos(rig).boss
	Events.boss_telegraph.emit(0, 60)
	assert_int(boss.started).is_equal(0)  # no boss alive: nothing to warn about
	var i: int = VfxXTestKit.enemy(w, Ids.EN_LANCE_PLATFORM, 6.0, 3.0)
	w.boss.boss_id = w.enemies.id[i]
	_frame(rig)
	var counts: Array[int] = []
	vfx.set_reduced_flash(true)  # a telegraph is information, not a flash
	for t: int in VfxXTestKit.TIERS:
		vfx.set_quality(t)
		VfxXTestKit.age(vfx, 4.0)
		Events.boss_telegraph.emit(0, 60)
		counts.append(boss.lance_hatch.live_count() + _chaos(rig).telegraph.lanes_red.live_count())
	assert_array(counts).is_equal([3, 3, 3])
