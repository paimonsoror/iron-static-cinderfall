extends GdUnitTestSuite
## V4-R: the seven new weapons on the Warden (VARIETY_SPEC 3.5) and the holstered weapon on the pack (3.1, 12.2): every weapon fits the
## Warden's loadout budget, has a muzzle at the front of its model and grips the arms can reach, and the other slot's weapon rides on
## the pack on MID and HIGH in the hard-surface looks only (a sibling node of the Warden, placed on the pack part every frame).

const STYLED: int = LookDevStyle.Look.STYLISED
const NEW_WEAPONS: Array[StringName] = [
	&"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"arc_projector", &"rail_lance",
]
const LA: float = LookDevWarden.ARM_UPPER
const LB: float = LookDevWarden.ARM_FORE


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookActorsStyle.rollout_override = -1


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func _layer(w: SimWorld = null) -> ActorLayer:
	var world: SimWorld = w if w != null else VarietyFKit.world()
	return VarietyFKit.bound_layer(self, world)


func test_every_weapon_fits_the_warden_loadout_budget() -> void:
	for look: int in [STYLED, LookDevStyle.Look.STYLISED_PLUS]:
		var body: int = ActorMeshes.warden_triangles(look, 0) - ActorMeshes.triangle_count(ActorMeshes.warden_part(&"pistol", look))
		for id: StringName in NEW_WEAPONS:
			var total: int = body + ActorMeshes.triangle_count(ActorMeshes.new_weapon(id))
			assert_int(total).override_failure_message("%s: body %d + weapon = %d" % [id, body, total]).is_less_equal(ActorMeshes.WARDEN_LOADOUT_BUDGET)
	assert_int(ActorMeshes.TRI_BUDGET[&"warden"]).is_equal(2500)  # the pistol and the SMG keep the old budget


func test_every_weapon_has_a_muzzle_at_the_front_of_its_model_and_grips_the_arms_can_reach() -> void:
	var reach: float = LA + LB
	for id: StringName in Ids.WEAPONS:
		var index: int = Ids.weapon_index(id)
		var mesh: ArrayMesh = ActorMeshes.warden_part(id, STYLED)
		var bb: AABB = mesh.get_aabb()
		var tip: Vector3 = WeaponMeshes.muzzle(index)
		var near: Vector3 = tip.clamp(bb.position, bb.end)  # the muzzle lies on or very near its own model
		assert_float(tip.distance_to(near)).override_failure_message("%s muzzle %s is off its model %s" % [id, tip, bb]).is_less(0.07)
		assert_float(tip.z).is_less(-0.3)  # the front half of the weapon
		assert_float(bb.position.z).is_less(tip.z + 0.07)  # nothing in front of the muzzle but the muzzle's own flare
		for hand: Vector3 in [LookDevGear.grip_r(index), LookDevGear.grip_l(index), LookDevGear.mag_point(index)]:
			assert_bool(hand.is_finite()).is_true()
			assert_float(hand.z).is_between(bb.position.z - 0.02, bb.end.z + 0.02)  # a hand holds the weapon, not the air
		var at_rest: Transform3D = Transform3D(Basis.IDENTITY, LookDevWarden.HAND_R)
		var right: Vector3 = WardenMotion.wrist_target(LookDevWarden.SHOULDER_R, at_rest * LookDevGear.grip_r(index))
		var left: Vector3 = WardenMotion.wrist_target(LookDevWarden.SHOULDER_L, at_rest * LookDevGear.grip_l(index))
		assert_float(LookDevWarden.SHOULDER_R.distance_to(right)).override_failure_message("%s: the weapon hand cannot reach" % id).is_less(reach)
		assert_float(LookDevWarden.SHOULDER_L.distance_to(left)).override_failure_message("%s: the support hand cannot reach" % id).is_less(reach + 0.02)


func test_the_hands_stay_on_the_grips_of_every_weapon_while_firing_and_reloading() -> void:
	var layer: ActorLayer = _layer()
	layer.set_look(STYLED)
	for id: StringName in Ids.WEAPONS:
		var index: int = Ids.weapon_index(id)
		Events.weapon_changed.emit(id)
		for i: int in 30:
			if i == 5 or i == 15:
				Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
			layer.render(0.5, 0.016)
			for side: String in ["r", "l"]:
				var err: Array[float] = _arm_error(layer, side, index, 0.0)
				assert_float(err[0]).override_failure_message("%s %s hand is %.3f m off its grip (short %.3f)" % [id, side, err[0], err[1]]).is_less(0.03)
		layer.warden.debug_hold_reload(true)
		for _i: int in 60:
			layer.render(0.5, 0.016)
		var reload: Array[float] = _arm_error(layer, "l", index, layer.warden.reload_amount())
		assert_float(reload[0]).override_failure_message("%s: the support hand misses the magazine by %.3f" % [id, reload[0]]).is_less(0.06)
		layer.warden.debug_hold_reload(false)
		for _i: int in 30:
			layer.render(0.5, 0.016)


## Distance between the wrist the solver posed and the wrist target of a grip, and the reach shortfall (the pattern of look_dev_arms_test).
func _arm_error(layer: ActorLayer, side: String, weapon: int, reload: float) -> Array[float]:
	var hand: Node3D = layer.warden.get_node("Upper/Body/Hand") as Node3D
	var weapon_xf: Transform3D = Transform3D(Basis.from_euler(hand.rotation), hand.position)
	var parts: WardenParts = layer.warden.parts()
	var upper: MeshInstance3D = parts.extras[WardenParts.index_of(&"arm_ru" if side == "r" else &"arm_lu")]
	var fore: MeshInstance3D = parts.extras[WardenParts.index_of(&"arm_rf" if side == "r" else &"arm_lf")]
	var grip: Vector3 = LookDevGear.grip_r(weapon)
	if side == "l":
		grip = LookDevGear.grip_l(weapon).lerp(LookDevGear.mag_point(weapon), reload)
	var shoulder: Vector3 = upper.position
	var target: Vector3 = WardenMotion.wrist_target(shoulder, weapon_xf * grip)
	var wrist: Vector3 = LookDevIk.wrist_of(fore, LB)
	return [wrist.distance_to(target), maxf(0.0, shoulder.distance_to(target) - (LA + LB))]


func test_the_other_slots_weapon_rides_on_the_pack_on_mid_and_high_in_the_hard_surface_looks() -> void:
	var w: SimWorld = VarietyFKit.world()
	w.arsenal.slot_weapon[1] = Ids.WP_RAIL_LANCE
	var layer: ActorLayer = _layer(w)
	layer.set_look(STYLED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	layer.render(0.5, 0.016)
	var warden: WardenView = layer.warden
	var holster: MeshInstance3D = warden.parts().holster
	assert_object(holster).is_not_null()
	assert_object(holster.get_parent()).is_same(layer)  # a sibling of the Warden: its own subtree keeps the pinned set of mesh instances
	assert_int(warden.holstered_weapon()).is_equal(Ids.WP_RAIL_LANCE)
	assert_bool(holster.visible).is_true()
	assert_object(holster.mesh).is_same(ActorMeshes.new_weapon(&"rail_lance"))  # it reuses the weapon mesh
	for tier: int in [VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		layer.set_quality(tier)
		assert_bool(holster.visible).is_true()
	layer.set_quality(VisualQuality.Tier.LOW)
	assert_bool(holster.visible).is_false()  # MID and HIGH only
	layer.set_quality(VisualQuality.Tier.MID)
	layer.set_look(LookDevStyle.Look.CURRENT)
	assert_bool(holster.visible).is_false()  # the flat look has no pack to carry it
	layer.set_look(LookDevStyle.Look.STYLISED_PLUS)
	assert_bool(holster.visible).is_true()
	for s: int in holster.mesh.get_surface_count():
		assert_object(holster.get_surface_override_material(s)).is_not_null()  # dressed with the Warden's materials like the weapon in hand


func test_the_holster_follows_the_loadout_and_an_empty_slot_shows_the_pistol() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = _layer(w)
	layer.set_look(STYLED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	layer.render(0.5, 0.016)
	assert_int(layer.warden.holstered_weapon()).is_equal(Ids.WP_PISTOL)  # slot 1 is empty
	w.arsenal.slot_weapon[1] = Ids.WP_SLAG_MORTAR
	layer.render(0.5, 0.016)
	assert_int(layer.warden.holstered_weapon()).is_equal(Ids.WP_SLAG_MORTAR)
	assert_object(layer.warden.parts().holster.mesh).is_same(ActorMeshes.new_weapon(&"slag_mortar"))
	w.arsenal.active = 1  # a swap: the pistol of slot 0 goes on the pack
	layer.render(0.5, 0.016)
	assert_int(layer.warden.holstered_weapon()).is_equal(Ids.WP_PISTOL)
	w.arsenal.slot_weapon[0] = Ids.WP_LMG
	layer.render(0.5, 0.016)
	assert_int(layer.warden.holstered_weapon()).is_equal(Ids.WP_LMG)
	w.arsenal.slot_count = 3  # the third sling: the next slot after the active one is on the pack
	w.arsenal.slot_weapon[2] = Ids.WP_HORNET_RACK
	layer.render(0.5, 0.016)
	assert_int(layer.warden.holstered_weapon()).is_equal(Ids.WP_HORNET_RACK)


func test_the_holster_sits_on_the_pack_follows_its_springs_and_never_leaves_the_warden() -> void:
	var layer: ActorLayer = _layer()
	layer.set_look(STYLED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	var warden: WardenView = layer.warden
	var holster: MeshInstance3D = warden.parts().holster
	var pack: MeshInstance3D = warden.parts().extras[WardenParts.index_of(&"pack")]
	var seen: Array[Vector3] = []
	for frame: int in 40:
		if frame == 5:
			Events.shot_fired.emit(DamageSource.Id.WARDEN, 0)  # the kick whips the pack: the holster rides with it
		layer.render(0.5, 1.0 / 60.0)
		var want: Transform3D = pack.global_transform * warden.parts().holster_local
		assert_bool(holster.global_transform.is_equal_approx(want)).is_true()
		assert_float(holster.global_position.distance_to(pack.global_position)).is_less(0.7)
		assert_float(holster.global_position.distance_to(warden.global_position)).is_less(1.6)
		seen.append(holster.global_position)
	var moved: float = 0.0
	for p: Vector3 in seen:
		moved = maxf(moved, p.distance_to(seen[0]))
	assert_float(moved).is_greater(0.0005)  # it moves with the pack, not a fixed decoration
	for id: StringName in Ids.WEAPONS:  # every weapon, scaled to the pack: no holstered model is longer than the pack is tall
		var m: ArrayMesh = ActorMeshes.warden_part(id, STYLED)
		var xf: Transform3D = WardenParts.holster_transform(m)
		var length: float = m.get_aabb().size.z * xf.basis.get_scale().z
		assert_float(length).is_less_equal(0.75)
		assert_float(xf.basis.get_scale().x).is_between(0.5, 0.9)


func test_the_warden_subtree_keeps_the_pinned_set_of_mesh_instances() -> void:
	var layer: ActorLayer = _layer()
	for look: int in 3:
		layer.set_look(look)
		var names: Array[String] = []
		for n: Node in ViewIntegrationKit.nodes_of(layer.warden, "MeshInstance3D"):
			names.append(String(n.name))
		assert_int(names.size()).is_equal(12)  # legs, torso, three weapon mounts, four arm parts, pack, antenna, cable
		assert_bool(names.has("WardenHolster")).is_false()
		for id: StringName in Ids.WEAPONS:
			Events.weapon_changed.emit(id)  # swapping weapons creates no node
		assert_int(ViewIntegrationKit.nodes_of(layer.warden, "MeshInstance3D").size()).is_equal(12)


func test_unbinding_hides_the_holster_and_freeing_the_layer_frees_it() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = _layer(w)
	layer.set_look(STYLED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	layer.render(0.5, 0.016)
	var holster: MeshInstance3D = layer.warden.parts().holster
	assert_bool(holster.visible).is_true()
	layer.unbind()
	assert_bool(holster.visible).is_false()
	layer.bind(w)
	layer.render(0.5, 0.016)
	assert_bool(layer.warden.parts().holster.visible).is_true()
	assert_int(layer.get_children().filter(func(n: Node) -> bool: return n.name == "WardenHolster").size()).is_equal(1)  # bound twice, one holster
