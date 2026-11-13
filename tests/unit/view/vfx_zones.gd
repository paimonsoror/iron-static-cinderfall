extends GdUnitTestSuite
## V4-X zones that follow enemies (SPEC 10.3 `fx_ward_ring`, `fx_tether`): a dashed ring under every ward and aura, a line for every tether,
## importance first when the tier's pool is full, wards and auras down during a static front, a broken ward without its ring, High Contrast.


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)


## Renders the actors (they adopt the store) and then the effects, so the zones see where the enemies are drawn.
func _frame(rig: VfxXTestKit.Rig) -> void:
	rig.layer.render(1.0, 0.016)
	rig.vfx.render(1.0, 0.016)


func _zones(rig: VfxXTestKit.Rig) -> FxZones:
	return rig.vfx.chaos().zones


func _has(radii: Array[float], radius: float) -> bool:
	for r: float in radii:
		if is_equal_approx(r, radius):
			return true
	return false


func _radii(zones: FxZones) -> Array[float]:
	var out: Array[float] = []
	for i: int in zones.rings.drawn():
		out.append(zones.rings.transform_of(i).basis.x.length())
	return out


func test_a_shieldbearer_wears_a_ward_ring_of_its_radius_until_the_ward_breaks() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var i: int = VfxXTestKit.enemy(w, Ids.EN_SHIELDBEARER, 2.0, -3.0)
	_frame(rig)
	var zones: FxZones = _zones(rig)
	var radius: float = w.content.enemies[Ids.EN_SHIELDBEARER].beh(&"ward_radius")
	assert_float(radius).is_greater(2.0)
	assert_int(zones.rings.drawn()).is_equal(1)
	assert_float(zones.rings.transform_of(0).basis.x.length()).is_equal_approx(radius, 0.001)
	assert_float(zones.rings.transform_of(0).origin.x).is_equal_approx(2.0, 0.05)
	Events.ward_changed.emit(w.enemies.id[i], 0.0)  # the sim says the ward is down
	_frame(rig)
	assert_bool(zones.is_broken(w.enemies.id[i])).is_true()
	assert_int(zones.rings.drawn()).is_equal(0)
	Events.ward_changed.emit(w.enemies.id[i], 0.4)  # ... and back up
	_frame(rig)
	assert_int(zones.rings.drawn()).is_equal(1)


func test_a_jammer_wears_its_aura_ring_and_a_static_front_takes_every_ring_down() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var _j: int = VfxXTestKit.enemy(w, Ids.EN_JAMMER, 0.0, 0.0)
	var _s: int = VfxXTestKit.enemy(w, Ids.EN_SHIELDBEARER, 3.0, 0.0)
	_frame(rig)
	var zones: FxZones = _zones(rig)
	var aura: float = w.content.enemies[Ids.EN_JAMMER].beh(&"aura_radius")
	assert_float(aura).is_greater_equal(6.0)
	assert_int(zones.rings.drawn()).is_equal(2)
	assert_bool(_has(_radii(zones), aura)).is_true()
	w.events_state.ability_lock_ticks = 300  # a static front: wards and auras are down
	_frame(rig)
	assert_int(zones.rings.drawn()).is_equal(0)
	w.events_state.ability_lock_ticks = 0
	_frame(rig)
	assert_int(zones.rings.drawn()).is_equal(2)


func test_elite_affixes_draw_a_personal_ward_and_an_overclock_ring() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var warded: int = VfxXTestKit.affix_bit(w.content, &"aff_warded")
	var clock: int = VfxXTestKit.affix_bit(w.content, &"aff_overclock")
	assert_int(warded).is_greater_equal(0)
	assert_int(clock).is_greater_equal(0)
	var a: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -1.0, -4.0)
	var b: int = VfxXTestKit.enemy(w, Ids.EN_RUSHER, 4.0, -4.0)
	w.ext.affix_mask[a] = 1 << warded
	w.ext.affix_mask[b] = 1 << clock
	_frame(rig)
	var zones: FxZones = _zones(rig)
	var radii: Array[float] = _radii(zones)
	assert_int(radii.size()).is_equal(2)
	assert_bool(_has(radii, FxZones.PERSONAL_WARD_M)).is_true()
	assert_bool(_has(radii, FxZones.OVERCLOCK_M)).is_true()
	Events.ward_changed.emit(w.enemies.id[a], 0.0)
	_frame(rig)
	assert_int(zones.rings.drawn()).is_equal(1)  # a broken personal ward loses its ring, the overclock stays


func test_rings_come_most_important_first_when_the_pool_is_full() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	for n: int in 6:
		var _s: int = VfxXTestKit.enemy(w, Ids.EN_SHIELDBEARER, -3.0 + float(n), -8.0)
	for n: int in 6:
		var _j: int = VfxXTestKit.enemy(w, Ids.EN_JAMMER, -3.0 + float(n), -3.0)
	rig.vfx.set_quality(VisualQuality.Tier.LOW)  # 8 rings
	_frame(rig)
	var zones: FxZones = _zones(rig)
	var wards: int = 0
	var auras: int = 0
	for r: float in _radii(zones):
		if is_equal_approx(r, w.content.enemies[Ids.EN_SHIELDBEARER].beh(&"ward_radius")):
			wards += 1
		else:
			auras += 1
	assert_int(zones.rings.drawn()).is_equal(8)
	assert_int(wards).is_equal(6)  # every ward first ...
	assert_int(auras).is_equal(2)  # ... then as many auras as fit
	assert_int(zones.rings.dropped).is_greater(0)
	rig.vfx.set_quality(VisualQuality.Tier.HIGH)
	_frame(rig)
	assert_int(zones.rings.drawn()).is_equal(12)


func test_a_reclaimer_is_tethered_to_the_nearest_three_damaged_enemies_in_range() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var _r: int = VfxXTestKit.enemy(w, Ids.EN_RECLAIMER, 0.0, 0.0)
	var near_a: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 1.0, 0.0, 0.5)
	var _near_b: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 0.0, 2.0, 0.5)
	var _near_c: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -3.0, 0.0, 0.5)
	var _far: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 5.0, 0.0, 0.5)  # damaged, in range, but the fourth
	var _whole: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 0.5, 0.5, 1.0)  # not damaged: nothing to heal
	var _out: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, 9.0, 9.0, 0.5)  # out of range
	_frame(rig)
	var zones: FxZones = _zones(rig)
	assert_int(zones.tethers.drawn()).is_equal(3)
	var ends: Array[float] = []
	for k: int in 3:
		var t: Transform3D = zones.tethers.transform_of(k)
		ends.append(snappedf(t.origin.x * 2.0, 0.01))  # a line from the reclaimer at x = 0: its centre is half of the far end's x
	assert_array(ends).contains([1.0, 0.0, -3.0])  # the lines to the skitters at x = 1, 0 and -3
	w.enemies.hp[near_a] = w.enemies.max_hp[near_a]  # healed: its tether ends, the next damaged one takes the place
	_frame(rig)
	assert_int(zones.tethers.drawn()).is_equal(3)


func test_a_magnetic_elite_is_tethered_to_the_shooters_within_twelve_metres() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	var bit: int = VfxXTestKit.affix_bit(w.content, &"aff_magnetic")
	assert_int(bit).is_greater_equal(0)
	var i: int = VfxXTestKit.enemy(w, Ids.EN_RUSHER, -3.0, 2.0)
	w.ext.affix_mask[i] = 1 << bit
	_frame(rig)
	var zones: FxZones = _zones(rig)
	assert_int(zones.tethers.drawn()).is_equal(1)  # the Warden is within 12 m
	w.turrets.active[0] = 1
	_frame(rig)
	_frame(rig)
	assert_int(zones.tethers.drawn()).is_equal(2)  # ... and so is the first turret
	var far: int = VfxXTestKit.enemy(w, Ids.EN_RUSHER, 9.0, -14.0)
	w.ext.affix_mask[far] = 1 << bit
	_frame(rig)
	assert_int(zones.tethers.drawn()).is_equal(2)  # out of reach of every shooter: no line


func test_tether_lines_are_capped_by_the_tier() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var w: SimWorld = rig.world
	for n: int in 4:
		var _r: int = VfxXTestKit.enemy(w, Ids.EN_RECLAIMER, -6.0 + float(n) * 4.0, -10.0)
	for n: int in 12:
		var _d: int = VfxXTestKit.enemy(w, Ids.EN_SKITTER, -7.0 + float(n) * 1.3, -9.0, 0.4)
	var want: Array[int] = [6, 9, 12]
	for t: int in VfxXTestKit.TIERS:
		rig.vfx.set_quality(t)
		_frame(rig)
		assert_int(_zones(rig).tethers.drawn()).is_equal(want[t])


func test_the_ring_is_dashed_so_it_never_reads_like_the_solid_danger_outline() -> void:
	var dashed: ArrayMesh = VfxMeshes.dashed_ring(FxZones.RING_INNER, FxZones.RING_DASHES, FxZones.RING_DUTY, &"add_red")
	var solid: ArrayMesh = VfxMeshes.ring(FxTelegraph.OUTLINE_INNER, 48, &"add_red", &"add_red")
	assert_int(VfxMeshes.triangles(dashed)).is_less(VfxMeshes.triangles(solid))
	var verts: PackedVector3Array = dashed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var angles: Array[float] = []
	for v: Vector3 in verts:
		if absf(v.length() - 1.0) < 0.001:
			angles.append(fposmod(atan2(v.z, v.x), TAU))
	angles.sort()
	var widest: float = 0.0
	for k: int in angles.size():
		var next: float = angles[(k + 1) % angles.size()] + (TAU if k + 1 == angles.size() else 0.0)
		widest = maxf(widest, next - angles[k])
	assert_float(widest).is_greater(0.3 * TAU / float(FxZones.RING_DASHES))  # a gap between the dashes
	assert_object(dashed.surface_get_material(0)).is_same(MatLib.mat(&"add_red"))  # no hatch: it hurts nobody on our side


func test_high_contrast_thickens_the_rings_and_the_lines() -> void:
	var rig: VfxXTestKit.Rig = VfxXTestKit.rig(self)
	var layer: ActorLayer = rig.layer
	var zones: FxZones = _zones(rig)
	var lit: Mesh = zones.rings.node.multimesh.mesh
	layer.set_high_contrast(true)
	rig.vfx.render(1.0, 0.016)  # the layer picks the switch up from the actors by itself
	assert_bool(rig.vfx.chaos().ctx.contrast).is_true()
	var bold: Mesh = zones.rings.node.multimesh.mesh
	assert_bool(bold == lit).is_false()
	assert_float(FxZones.LINE_WIDTH_CONTRAST_M).is_greater(FxZones.LINE_WIDTH_M)
	assert_float(FxZones.RING_INNER_CONTRAST).is_less(FxZones.RING_INNER)
	layer.set_high_contrast(false)
	rig.vfx.render(1.0, 0.016)
	assert_bool(zones.rings.node.multimesh.mesh == lit).is_true()
