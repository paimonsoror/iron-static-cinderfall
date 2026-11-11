extends GdUnitTestSuite
## VfxLayer: every effect comes from an Events signal or from the shield and overdrive state of the sim (ARCH 8, 13).


## Advances the layer by `seconds` in 0.1 s frames.
func _age(vfx: VfxLayer, seconds: float) -> void:
	vfx.render(1.0, 0.0)  # the first draw of a new effect does not age it
	var left: float = seconds
	while left > 0.0:
		vfx.render(1.0, 0.1)
		left -= 0.1


func _rig(count: int) -> Array:
	var w: SimWorld = ActorsTestKit.world()
	for n: int in count:
		var _i: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0 + float(n % 8), 3.0 - float(floori(float(n) / 8.0)))
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	var vfx: VfxLayer = ActorsTestKit.vfx_layer(self, w, layer)
	auto_free(vfx)
	layer.bind(w)
	vfx.bind(w)
	layer.render(1.0, 0.016)
	vfx.render(1.0, 0.016)
	return [w, layer, vfx]


func test_tracer_pool_never_exceeds_forty_eight() -> void:
	var rig: Array = _rig(3)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	for n: int in 300:
		Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[n % 3])
		assert_int(vfx.tracer_count()).is_less_equal(48)
	assert_int(vfx.tracer_count()).is_equal(48)
	assert_int(vfx.tracer_capacity()).is_equal(VfxLayer.TRACER_CAP)
	_age(vfx, 0.5)
	assert_int(vfx.tracer_count()).is_equal(0)


func test_a_warden_shot_spawns_a_tracer_a_muzzle_flash_and_impact_sparks() -> void:
	var rig: Array = _rig(2)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[0])
	assert_int(vfx.tracer_count()).is_equal(1)
	assert_int(vfx.muzzle_count()).is_equal(1)
	assert_int(vfx.spark_count()).is_equal(VfxLayer.SPARKS_PER_HIT[VisualQuality.Tier.HIGH])
	vfx.render(1.0, 0.0)  # first draw: everything is still there
	assert_int(vfx.muzzle_count()).is_equal(1)
	vfx.render(1.0, 0.1)
	assert_int(vfx.muzzle_count()).is_equal(0)  # 0.07 s flash is over
	assert_int(vfx.tracer_count()).is_equal(1)  # 0.12 s tracer is not
	vfx.render(1.0, 0.1)
	assert_int(vfx.tracer_count()).is_equal(0)
	vfx.render(1.0, 0.1)
	assert_int(vfx.spark_count()).is_equal(0)


func test_a_turret_shot_needs_a_deployed_turret() -> void:
	var rig: Array = _rig(2)
	var w: SimWorld = rig[0]
	var layer: ActorLayer = rig[1]
	var vfx: VfxLayer = rig[2]
	Events.shot_fired.emit(DamageSource.Id.TURRET_0, w.enemies.id[0])
	assert_int(vfx.tracer_count()).is_equal(0)
	w.turrets.active[0] = 1
	layer.render(1.0, 0.016)
	Events.shot_fired.emit(DamageSource.Id.TURRET_0, w.enemies.id[0])
	assert_int(vfx.tracer_count()).is_equal(1)


func test_a_shot_at_a_vanished_target_still_draws_a_tracer_to_the_aim_point() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 424242)
	assert_int(vfx.tracer_count()).is_equal(1)
	assert_int(vfx.spark_count()).is_equal(0)  # nothing was hit in the view


func test_quality_tiers_scale_spark_counts_and_text_caps() -> void:
	var rig: Array = _rig(2)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		vfx.set_quality(tier)
		_age(vfx, 1.0)
		Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[0])
		assert_int(vfx.spark_count()).is_equal(VfxLayer.SPARKS_PER_HIT[tier])
		for n: int in 40:
			Events.enemy_died_at.emit(900 + n, &"skitter", 1.0, 1.0, 20)
		assert_int(vfx.text_count()).is_equal(VfxLayer.TEXT_CAP_BY_TIER[tier])
		vfx.floating_texts().clear()
	assert_int(VfxLayer.SPARKS_PER_HIT[0]).is_less(VfxLayer.SPARKS_PER_HIT[2])


func test_a_death_spawns_a_burst_debris_and_a_floating_scrap_text() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	Events.enemy_died_at.emit(77, &"skitter", 4.0, 2.0, 20)
	assert_int(vfx.burst_count()).is_equal(1)
	assert_int(vfx.debris_count()).is_equal(VfxLayer.DEBRIS_PER_DEATH[VisualQuality.Tier.HIGH])
	assert_int(vfx.text_count()).is_equal(1)
	assert_array(vfx.floating_texts().texts()).contains(["+20"])
	Events.enemy_died_at.emit(78, &"unknown_kind", 4.0, 2.0, 20)  # ignored
	assert_int(vfx.burst_count()).is_equal(1)
	_age(vfx, 0.5)
	assert_int(vfx.burst_count()).is_equal(0)


func test_the_boss_death_is_heavier_than_a_skitter_death() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	Events.enemy_died_at.emit(77, &"skitter", 4.0, 2.0, 20)
	var light_debris: int = vfx.debris_count()
	var light_bursts: int = vfx.burst_count()
	vfx.floating_texts().clear()
	Events.enemy_died_at.emit(78, &"siege_hulk", 4.0, 2.0, 400)
	assert_int(vfx.debris_count() - light_debris).is_greater(light_debris)
	assert_int(vfx.burst_count() - light_bursts).is_greater(light_bursts)
	assert_array(vfx.floating_texts().texts()).contains(["+400"])


func test_death_bursts_never_exceed_their_pool() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	for n: int in 200:
		Events.enemy_died_at.emit(n + 10, &"rusher", 1.0, 1.0, 25)
	assert_int(vfx.burst_count()).is_less_equal(VfxLayer.BURST_CAP)
	assert_int(vfx.debris_count()).is_less_equal(VfxLayer.BURST_CAP * VfxLayer.DEBRIS_PER_BURST)
	assert_int(vfx.text_count()).is_less_equal(FloatingTexts.CAPACITY)


func test_reduced_flash_disables_the_full_screen_flash_node() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	var lit: float = vfx.flash_alpha()
	vfx.set_reduced_flash(false)
	Events.ability_activated.emit(&"emp")
	assert_bool(vfx.screen_flash().is_flash_visible()).is_true()
	vfx.set_reduced_flash(true)
	assert_float(vfx.flash_alpha()).is_less(lit * 0.6)  # muzzle and EMP flashes are capped too
	assert_bool(vfx.is_reduced_flash()).is_true()
	assert_bool(vfx.screen_flash().is_flash_visible()).is_false()
	Events.ability_activated.emit(&"emp")
	assert_bool(vfx.screen_flash().is_flash_visible()).is_false()
	Events.core_hit.emit(5, &"hollow_warden", 30.0, 0.0)
	assert_bool(vfx.screen_flash().is_flash_visible()).is_false()
	assert_object(vfx.screen_flash().rect).is_not_null()
	vfx.set_reduced_flash(false)
	assert_float(vfx.flash_alpha()).is_equal(lit)
	Events.ability_activated.emit(&"emp")
	assert_bool(vfx.screen_flash().is_flash_visible()).is_true()
	_age(vfx, 0.5)
	assert_bool(vfx.screen_flash().is_flash_visible()).is_false()


func test_emp_spawns_an_expanding_ring_capped_at_two() -> void:
	var rig: Array = _rig(1)
	var vfx: VfxLayer = rig[2]
	Events.ability_activated.emit(&"shield")
	assert_int(vfx.ring_count()).is_equal(0)
	for _n: int in 5:
		Events.ability_activated.emit(&"emp")
	assert_int(vfx.ring_count()).is_equal(2)
	_age(vfx, 1.0)
	assert_int(vfx.ring_count()).is_equal(0)


func test_shield_dome_and_overdrive_glow_follow_the_sim_state() -> void:
	var rig: Array = _rig(1)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	assert_bool(vfx.auras().dome_visible()).is_false()
	assert_bool(vfx.auras().glow_visible()).is_false()
	w.shield_hp = 100.0
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 300
	vfx.render(1.0, 0.016)
	assert_bool(vfx.auras().dome_visible()).is_true()
	assert_bool(vfx.auras().glow_visible()).is_true()
	assert_float(vfx.auras().dome_opacity()).is_between(0.1, 0.7)
	w.shield_hp = 0.0
	w.abilities.active_left[Ids.AB_OVERDRIVE] = 0
	vfx.render(1.0, 0.016)
	assert_bool(vfx.auras().dome_visible()).is_false()
	assert_bool(vfx.auras().glow_visible()).is_false()


func test_a_core_hit_throws_sparks_and_an_absorbed_hit_flares_the_dome() -> void:
	var rig: Array = _rig(2)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	Events.core_hit.emit(w.enemies.id[0], &"skitter", 12.0, 0.0)
	assert_int(vfx.spark_count()).is_greater(0)
	assert_int(vfx.muzzle_count()).is_equal(1)
	assert_float(vfx.auras().hit_amount()).is_equal(0.0)
	Events.core_hit.emit(w.enemies.id[0], &"skitter", 0.0, 12.0)
	assert_float(vfx.auras().hit_amount()).is_equal(1.0)


func test_boss_footfall_raises_dust_except_on_low_quality() -> void:
	var rig: Array = _rig(1)
	var layer: ActorLayer = rig[1]
	var vfx: VfxLayer = rig[2]
	layer.footfall.emit(Vector3(1.0, 0.0, 1.0), 1.0)
	assert_int(vfx.dust_count()).is_equal(2 + VisualQuality.Tier.HIGH)
	assert_int(vfx.debris_count()).is_greater(0)
	vfx.set_quality(VisualQuality.Tier.LOW)
	_age(vfx, 1.0)
	layer.footfall.emit(Vector3(1.0, 0.0, 1.0), 1.0)
	assert_int(vfx.dust_count()).is_equal(0)


func test_unbind_clears_every_pool_and_stops_listening() -> void:
	var rig: Array = _rig(2)
	var w: SimWorld = rig[0]
	var vfx: VfxLayer = rig[2]
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[0])
	Events.enemy_died_at.emit(5, &"rusher", 1.0, 1.0, 25)
	Events.ability_activated.emit(&"emp")
	assert_int(vfx.tracer_count() + vfx.burst_count() + vfx.ring_count() + vfx.text_count()).is_greater(3)
	vfx.unbind()
	assert_int(vfx.tracer_count() + vfx.burst_count() + vfx.ring_count() + vfx.text_count()).is_equal(0)
	assert_int(vfx.spark_count() + vfx.debris_count() + vfx.muzzle_count()).is_equal(0)
	assert_bool(vfx.screen_flash().is_flash_visible()).is_false()
	Events.shot_fired.emit(DamageSource.Id.WARDEN, w.enemies.id[0])
	Events.enemy_died_at.emit(6, &"rusher", 1.0, 1.0, 25)
	assert_int(vfx.tracer_count() + vfx.burst_count()).is_equal(0)
