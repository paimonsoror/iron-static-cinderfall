extends GdUnitTestSuite
## V2-F: the arc projector in the Warden's hands (VARIETY_SPEC 3.5): a third weapon node, shown for `weapon_changed`,
## `weapon_swapped` and the sim's weapon index; weapons that have no model yet are drawn with the SMG; the muzzle is the arc's; the
## hard-surface looks dress it with the shared materials; the old two weapons keep their behaviour.

const ARC: int = 2


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func _warden() -> WardenView:
	var layer: ActorLayer = VarietyFKit.bound_layer(self, VarietyFKit.world())
	return layer.warden


func test_the_warden_has_three_weapon_nodes_and_only_the_one_in_hand_is_visible() -> void:
	var warden: WardenView = _warden()
	assert_bool(warden.weapon_visible(0)).is_true()
	assert_bool(warden.weapon_visible(1)).is_false()
	assert_bool(warden.weapon_visible(ARC)).is_false()
	assert_bool(warden.weapon_visible(3)).is_false()  # no such node
	var names: Array[String] = []
	for mi: Node in ViewIntegrationKit.nodes_of(warden, "MeshInstance3D"):
		names.append(String(mi.name))
	assert_array(names).contains(["Pistol", "Smg", "ArcProjector"])
	assert_int(WeaponMeshes.model_index(Ids.WP_PISTOL)).is_equal(0)
	assert_int(WeaponMeshes.model_index(Ids.WP_SMG)).is_equal(1)
	assert_int(WeaponMeshes.model_index(Ids.WP_ARC_PROJECTOR)).is_equal(ARC)
	assert_int(ActorMeshes.WARDEN_WEAPON_NODES.size()).is_equal(3)


func test_weapon_changed_and_weapon_swapped_bring_the_arc_projector_into_the_hand() -> void:
	var warden: WardenView = _warden()
	Events.weapon_changed.emit(&"arc_projector")
	assert_int(warden.weapon_index()).is_equal(ARC)
	assert_bool(warden.weapon_visible(ARC)).is_true()
	assert_bool(warden.weapon_visible(0)).is_false()
	assert_bool(warden.weapon_visible(1)).is_false()
	Events.weapon_swapped.emit(1, &"smg")  # tap the holstered weapon
	assert_int(warden.weapon_index()).is_equal(1)
	assert_bool(warden.weapon_visible(1)).is_true()
	assert_bool(warden.weapon_visible(ARC)).is_false()
	Events.weapon_swapped.emit(0, &"arc_projector")
	assert_int(warden.weapon_index()).is_equal(ARC)
	Events.weapon_swapped.emit(0, &"pistol")
	assert_int(warden.weapon_index()).is_equal(0)
	Events.weapon_changed.emit(&"no_such_weapon")  # ignored
	Events.weapon_swapped.emit(0, &"")
	assert_int(warden.weapon_index()).is_equal(0)


func test_a_weapon_without_a_model_yet_is_drawn_with_the_smg_and_never_vanishes() -> void:
	var warden: WardenView = _warden()
	for id: StringName in [&"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"rail_lance"]:
		Events.weapon_changed.emit(id)
		assert_int(warden.weapon_index()).is_equal(1)
		assert_bool(warden.weapon_visible(1)).is_true()


func test_the_sim_weapon_index_decides_what_is_in_hand_when_the_view_binds() -> void:
	var w: SimWorld = VarietyFKit.world()
	w.warden.weapon_index = Ids.WP_ARC_PROJECTOR  # a debug write in a test, like the puppet's
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	assert_int(layer.warden.weapon_index()).is_equal(ARC)
	var legacy: SimWorld = TestContent.world(1)
	legacy.warden.weapon_index = Ids.WP_SMG
	var old: ActorLayer = ActorsTestKit.actor_layer(self, legacy)
	auto_free(old)
	old.bind(legacy)
	assert_int(old.warden.weapon_index()).is_equal(1)  # the legacy two keep their node indices


func test_the_muzzle_is_the_arc_projectors_and_the_hands_hold_its_grips() -> void:
	var warden: WardenView = _warden()
	Events.weapon_changed.emit(&"smg")
	var smg_tip: Vector3 = warden.muzzle_position()
	Events.weapon_changed.emit(&"arc_projector")
	var arc_tip: Vector3 = warden.muzzle_position()
	assert_bool(arc_tip.is_finite()).is_true()
	assert_bool(arc_tip.distance_to(smg_tip) > 0.02).is_true()  # a different weapon, a different place the tracers leave from
	assert_float(WeaponMeshes.muzzle(ARC).z).is_equal(WeaponMeshes.ARC_MUZZLE.z)
	assert_float(WeaponMeshes.muzzle(1).z).is_equal(HeroMeshes.SMG_MUZZLE.z)
	assert_float(WeaponMeshes.muzzle(0).z).is_equal(HeroMeshes.PISTOL_MUZZLE.z)
	assert_that(LookDevGear.grip_r(ARC)).is_equal(WeaponMeshes.ARC_GRIP_R)
	assert_that(LookDevGear.grip_l(ARC)).is_equal(WeaponMeshes.ARC_GRIP_L)
	assert_that(LookDevGear.mag_point(ARC)).is_equal(WeaponMeshes.ARC_MAG)
	assert_that(LookDevGear.grip_r(1)).is_equal(LookDevGear.SMG_GRIP_R)  # the old weapons' grips did not move
	assert_that(LookDevGear.grip_l(0)).is_equal(LookDevGear.PISTOL_GRIP_L)
	var tip: AABB = ActorMeshes.new_weapon(&"arc_projector").get_aabb()
	assert_float(tip.position.z).is_less_equal(WeaponMeshes.ARC_MUZZLE.z + 0.06)


func test_the_styled_arms_follow_the_arc_projector_for_every_pose() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	layer.set_look(LookDevStyle.Look.STYLISED)
	Events.weapon_changed.emit(&"arc_projector")
	var warden: WardenView = layer.warden
	for frame: int in 40:
		if frame == 10:
			Events.shot_fired.emit(DamageSource.Id.WARDEN, 0)
		if frame == 20:
			warden.debug_hold_reload(true)
		layer.render(1.0, 1.0 / 60.0)
	for mi: MeshInstance3D in warden.parts().extras:
		assert_bool(mi.transform.origin.is_finite()).is_true()
		assert_bool(mi.transform.basis.determinant() != 0.0).is_true()
	var shoulder: Vector3 = LookDevWarden.SHOULDER_R
	var reach: float = LookDevWarden.ARM_UPPER + LookDevWarden.ARM_FORE
	var hand: Vector3 = LookDevWarden.HAND_R + WeaponMeshes.ARC_GRIP_R
	assert_float(shoulder.distance_to(hand)).is_less(reach)  # the weapon hand can reach its grip without stretching the arm
	assert_float(LookDevWarden.SHOULDER_L.distance_to(LookDevWarden.HAND_R + WeaponMeshes.ARC_GRIP_L)).is_less(reach + 0.1)


func test_every_look_dresses_the_arc_projector_with_the_shared_materials() -> void:
	var w: SimWorld = VarietyFKit.world()
	var layer: ActorLayer = VarietyFKit.bound_layer(self, w)
	var node: MeshInstance3D = layer.warden.parts().weapons[ARC]
	assert_object(node.mesh).is_same(ActorMeshes.new_weapon(&"arc_projector"))
	for s: int in node.mesh.get_surface_count():
		assert_object(node.get_surface_override_material(s)).is_null()  # CURRENT: the flat palette, no override
	layer.set_look(LookDevStyle.Look.STYLISED)
	layer.set_quality(VisualQuality.Tier.HIGH)
	var m: ArrayMesh = node.mesh as ArrayMesh
	for s: int in m.get_surface_count():
		var role: StringName = StringName(m.surface_get_material(s).resource_name)
		assert_object(node.get_surface_override_material(s)).is_same(LookDevMat.surface(role, LookDevStyle.Look.STYLISED, VisualQuality.Tier.HIGH))
	var cyan: Material = LookDevMat.surface(&"emit_cyan", LookDevStyle.Look.STYLISED, VisualQuality.Tier.HIGH)
	var found: bool = false
	for s: int in m.get_surface_count():
		found = found or node.get_surface_override_material(s) == cyan
	assert_bool(found).is_true()  # the one cyan accent is the Warden's own accent material
	var before: int = ActorsTestKit.count_nodes(layer.warden)
	for _n: int in 20:
		layer.set_look(LookDevStyle.Look.CURRENT)
		layer.set_look(LookDevStyle.Look.STYLISED_PLUS)
	assert_int(ActorsTestKit.count_nodes(layer.warden)).is_equal(before)  # switching looks never creates a node
