extends GdUnitTestSuite
## W3-C round 2: the two-bone arm solve (LookDevIk) and the poses that use it: the weapon hand and the support hand hold the
## weapon while firing, and the support hand reaches the magazine in the reload pose, for both weapons.

const LA: float = LookDevWarden.ARM_UPPER
const LB: float = LookDevWarden.ARM_FORE


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)


func _layer() -> ActorLayer:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	layer.set_look(LookDevStyle.Look.STYLISED)
	return layer


func _node(layer: ActorLayer, part: StringName) -> MeshInstance3D:
	return layer.warden.parts().extras[WardenParts.index_of(part)]


## Distance between the wrist the solver posed and the wrist target of the weapon grip, and the reach shortfall.
func _arm_error(layer: ActorLayer, side: String, weapon: int, reload: float) -> Array[float]:
	var hand: Node3D = layer.warden.get_node("Upper/Body/Hand") as Node3D
	var weapon_xf: Transform3D = Transform3D(Basis.from_euler(hand.rotation), hand.position)
	var upper: MeshInstance3D = _node(layer, &"arm_ru" if side == "r" else &"arm_lu")
	var fore: MeshInstance3D = _node(layer, &"arm_rf" if side == "r" else &"arm_lf")
	var grip: Vector3 = LookDevGear.grip_r(weapon)
	if side == "l":
		grip = LookDevGear.grip_l(weapon).lerp(LookDevGear.mag_point(weapon), reload)
	var shoulder: Vector3 = upper.position
	var target: Vector3 = WardenMotion.wrist_target(shoulder, weapon_xf * grip)
	var wrist: Vector3 = LookDevIk.wrist_of(fore, LB)
	var shortfall: float = maxf(0.0, shoulder.distance_to(target) - (LA + LB))
	return [wrist.distance_to(target), shortfall]


func test_two_bone_solve_keeps_the_bone_lengths_and_reaches_a_reachable_wrist() -> void:
	var shoulder: Vector3 = Vector3(0.3, 0.5, 0.0)
	for target: Vector3 in [Vector3(0.1, 0.3, -0.4), Vector3(0.45, 0.2, -0.3), Vector3(-0.1, 0.5, -0.5), Vector3(0.3, 0.1, 0.1)]:
		var elbow: Vector3 = LookDevIk.elbow(shoulder, target, LA, LB, Vector3(1.0, -0.3, 0.4))
		var wrist: Vector3 = LookDevIk.reach_point(shoulder, target, LA, LB)
		assert_float(shoulder.distance_to(elbow)).is_equal_approx(LA, 0.0005)
		assert_float(elbow.distance_to(wrist)).is_equal_approx(LB, 0.0005)
		assert_float(wrist.distance_to(target)).is_less(0.0005)


func test_two_bone_solve_clamps_an_unreachable_target_instead_of_breaking_the_arm() -> void:
	var shoulder: Vector3 = Vector3.ZERO
	var far: Vector3 = Vector3(0.0, 0.0, -2.0)
	var wrist: Vector3 = LookDevIk.reach_point(shoulder, far, LA, LB)
	assert_float(wrist.length()).is_less(LA + LB)
	assert_float(wrist.length()).is_greater(LA + LB - 0.01)
	var elbow: Vector3 = LookDevIk.elbow(shoulder, far, LA, LB, Vector3.UP)
	assert_float(shoulder.distance_to(elbow)).is_equal_approx(LA, 0.0005)
	assert_float(elbow.distance_to(wrist)).is_equal_approx(LB, 0.0005)
	# a target on top of the shoulder is folded, not NaN
	var near: Vector3 = LookDevIk.elbow(shoulder, shoulder, LA, LB, Vector3.RIGHT)
	assert_bool(near.is_finite()).is_true()


func test_the_elbow_bends_toward_the_pole() -> void:
	var shoulder: Vector3 = Vector3(0.37, 0.56, 0.02)
	var target: Vector3 = Vector3(0.1, 0.35, -0.3)
	var out: Vector3 = LookDevIk.elbow(shoulder, target, LA, LB, Vector3(1.0, 0.0, 0.0))
	var inward: Vector3 = LookDevIk.elbow(shoulder, target, LA, LB, Vector3(-1.0, 0.0, 0.0))
	assert_float(out.x).is_greater(inward.x)
	var low: Vector3 = LookDevIk.elbow(shoulder, target, LA, LB, Vector3(0.0, -1.0, 0.0))
	var high: Vector3 = LookDevIk.elbow(shoulder, target, LA, LB, Vector3(0.0, 1.0, 0.0))
	assert_float(low.y).is_less(high.y)


func test_pose_arm_connects_the_segments_and_looks_along_the_bones() -> void:
	var upper: Node3D = Node3D.new()
	var fore: Node3D = Node3D.new()
	auto_free(upper)
	auto_free(fore)
	var shoulder: Vector3 = LookDevWarden.SHOULDER_R
	var target: Vector3 = Vector3(0.1, 0.34, -0.3)
	LookDevIk.pose_arm(upper, fore, shoulder, target, LA, LB, LookDevWarden.POLE_R)
	var elbow: Vector3 = upper.position + upper.basis * Vector3(0.0, 0.0, -LA)
	assert_vector(elbow).is_equal_approx(fore.position, Vector3(0.001, 0.001, 0.001))
	assert_vector(LookDevIk.wrist_of(fore, LB)).is_equal_approx(
		LookDevIk.reach_point(shoulder, target, LA, LB), Vector3(0.001, 0.001, 0.001)
	)
	assert_float(upper.basis.determinant()).is_equal_approx(1.0, 0.001)


func test_firing_holds_the_weapon_with_both_hands_for_both_weapons() -> void:
	var layer: ActorLayer = _layer()
	for weapon: int in 2:
		Events.weapon_changed.emit(&"pistol" if weapon == 0 else &"smg")
		for i: int in 40:
			if i == 5 or i == 20:
				Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)  # recoil kicks must not pull a hand off the grip
			layer.render(0.5, 0.016)
			for side: String in ["r", "l"]:
				var err: Array[float] = _arm_error(layer, side, weapon, 0.0)
				assert_float(err[1]).is_equal(0.0)  # in reach
				assert_float(err[0]).is_less(0.005)


func test_the_support_hand_reaches_the_magazine_in_the_reload_pose() -> void:
	var layer: ActorLayer = _layer()
	for weapon: int in 2:
		Events.weapon_changed.emit(&"pistol" if weapon == 0 else &"smg")
		layer.render(0.5, 0.016)
		layer.warden.debug_hold_reload(true)
		for i: int in 60:
			layer.render(0.5, 0.016)
		assert_float(layer.warden.reload_amount()).is_greater(0.95)
		var err: Array[float] = _arm_error(layer, "l", weapon, layer.warden.reload_amount())
		assert_float(err[1]).is_less(0.005)
		assert_float(err[0]).is_less(0.03)  # within 3 cm of the magazine (v1 missed by several)
		var right: Array[float] = _arm_error(layer, "r", weapon, layer.warden.reload_amount())
		assert_float(right[0]).is_less(0.03)
		layer.warden.debug_hold_reload(false)


func test_the_arm_segments_are_two_parts_per_arm_with_an_elbow_between() -> void:
	var layer: ActorLayer = _layer()
	layer.render(0.5, 0.016)
	for side: String in ["r", "l"]:
		var upper: MeshInstance3D = _node(layer, &"arm_ru" if side == "r" else &"arm_lu")
		var fore: MeshInstance3D = _node(layer, &"arm_rf" if side == "r" else &"arm_lf")
		var shoulder: Vector3 = upper.position
		var elbow: Vector3 = fore.position
		var wrist: Vector3 = LookDevIk.wrist_of(fore, LB)
		var bend: float = (elbow - shoulder).normalized().dot((wrist - elbow).normalized())
		assert_float(bend).is_less(0.995)  # a visible bend, not a straight pipe
		assert_float(shoulder.distance_to(elbow)).is_equal_approx(LA, 0.002)
		assert_float(elbow.distance_to(wrist)).is_equal_approx(LB, 0.002)


func test_arm_meshes_have_a_forearm_gauntlet_on_the_weapon_arm_only() -> void:
	var right: ArrayMesh = ActorMeshes.warden_part(&"arm_rf", LookDevStyle.Look.STYLISED)
	var left: ArrayMesh = ActorMeshes.warden_part(&"arm_lf", LookDevStyle.Look.STYLISED)
	assert_int(ActorMeshes.triangle_count(right)).is_greater(ActorMeshes.triangle_count(left))
	for m: ArrayMesh in [right, left]:
		assert_float(m.get_aabb().position.z).is_less(-LB)  # the glove reaches past the wrist
