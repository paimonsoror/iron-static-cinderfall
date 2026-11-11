extends GdUnitTestSuite
## WardenView and TurretView: aim yaw, recoil, weapon swap, reload pose, deploy rise (WORK_PLAN W1-F).


func _bound() -> Array:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	return [w, layer]


func _yaw_toward(from_x: float, from_z: float, to_x: float, to_z: float) -> float:
	return atan2(-(to_x - from_x), -(to_z - from_z))


func test_warden_upper_body_yaws_to_the_aim_point_and_legs_stay_planted() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	w.warden.aim_x = w.warden.x + 4.0
	w.warden.aim_z = w.warden.z - 3.0
	layer.render(0.5, 1.0)
	assert_float(layer.warden.upper_yaw()).is_equal_approx(
		_yaw_toward(w.warden.x, w.warden.z, w.warden.aim_x, w.warden.aim_z), 0.01
	)
	var legs: Node3D = layer.warden.get_node("Legs") as Node3D
	assert_float(legs.rotation.y).is_equal_approx(0.0, 0.0001)
	assert_float(layer.warden.position.x).is_equal_approx(w.warden.x, 0.0001)
	assert_float(layer.warden.position.z).is_equal_approx(w.warden.z, 0.0001)
	w.warden.aim_x = w.warden.x - 5.0
	w.warden.aim_z = w.warden.z + 1.0
	layer.render(0.5, 1.0)
	assert_float(angle_difference(layer.warden.upper_yaw(), _yaw_toward(w.warden.x, w.warden.z, w.warden.aim_x, w.warden.aim_z))).is_equal_approx(0.0, 0.01)


func test_warden_turns_smoothly_not_instantly() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	layer.render(0.5, 0.016)
	var start: float = layer.warden.upper_yaw()
	w.warden.aim_x = w.warden.x - 4.0
	w.warden.aim_z = w.warden.z
	layer.render(0.5, 0.016)
	var after_one: float = layer.warden.upper_yaw()
	assert_float(absf(angle_difference(start, after_one))).is_greater(0.01)
	assert_float(absf(angle_difference(after_one, PI * 0.5))).is_greater(0.05)


func test_warden_recoils_on_its_own_shot_and_the_kick_decays() -> void:
	var pair: Array = _bound()
	var layer: ActorLayer = pair[1]
	Events.shot_fired.emit(DamageSource.Id.TURRET_0, 1)
	assert_float(layer.warden.recoil_amount()).is_equal(0.0)
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	assert_float(layer.warden.recoil_amount()).is_greater(0.5)
	layer.render(0.5, 0.016)
	var body: Node3D = layer.warden.get_node("Upper/Body") as Node3D
	assert_float(body.position.z).is_greater(0.03)  # kicked back along the aim
	layer.render(0.5, 0.6)
	assert_float(layer.warden.recoil_amount()).is_less(0.01)


func test_warden_swaps_the_weapon_on_weapon_changed() -> void:
	var pair: Array = _bound()
	var layer: ActorLayer = pair[1]
	assert_int(layer.warden.weapon_index()).is_equal(0)
	assert_bool(layer.warden.weapon_visible(0)).is_true()
	assert_bool(layer.warden.weapon_visible(1)).is_false()
	Events.weapon_changed.emit(&"smg")
	assert_int(layer.warden.weapon_index()).is_equal(1)
	assert_bool(layer.warden.weapon_visible(0)).is_false()
	assert_bool(layer.warden.weapon_visible(1)).is_true()
	Events.weapon_changed.emit(&"not_a_weapon")
	assert_int(layer.warden.weapon_index()).is_equal(1)


func test_warden_dips_the_weapon_while_reloading_and_recovers() -> void:
	var pair: Array = _bound()
	var layer: ActorLayer = pair[1]
	assert_float(layer.warden.reload_amount()).is_equal(0.0)
	Events.reload_started.emit(75)
	assert_bool(layer.warden.is_reloading()).is_true()
	layer.render(0.5, 0.5)
	assert_float(layer.warden.reload_amount()).is_greater(0.9)
	var hand: Node3D = layer.warden.get_node("Upper/Body/Hand") as Node3D
	assert_float(hand.rotation.x).is_less(-0.5)  # muzzle pitched down
	Events.reload_finished.emit()
	layer.render(0.5, 0.5)
	assert_bool(layer.warden.is_reloading()).is_false()
	assert_float(layer.warden.reload_amount()).is_less(0.01)


func test_warden_adopts_the_weapon_and_reload_state_of_the_sim_on_bind() -> void:
	var w: SimWorld = ActorsTestKit.world()
	w.warden.weapon_index = 1
	w.warden.reload_ticks_left = 40
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	assert_int(layer.warden.weapon_index()).is_equal(1)
	assert_bool(layer.warden.is_reloading()).is_true()


func test_warden_muzzle_is_in_front_of_the_body_along_the_aim() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	w.warden.aim_x = w.warden.x + 6.0
	w.warden.aim_z = w.warden.z
	layer.render(0.5, 1.0)
	var muzzle: Vector3 = layer.warden_muzzle_position()
	assert_bool(muzzle.is_finite()).is_true()
	assert_float(muzzle.x - w.warden.x).is_greater(0.4)
	assert_float(muzzle.y).is_between(0.9, 1.9)


func test_turret_is_hidden_until_deployed_then_rises_and_yaws() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	assert_bool(layer.turrets[0].visible).is_false()
	assert_bool(layer.turret_muzzle_position(0).is_finite()).is_false()
	w.turrets.active[0] = 1
	w.turrets.aim_x[0] = w.turrets.x[0] + 5.0
	w.turrets.aim_z[0] = w.turrets.z[0]
	Events.turret_deployed.emit(0)
	assert_bool(layer.turrets[0].is_deployed()).is_true()
	assert_bool(layer.turrets[1].is_deployed()).is_false()
	layer.render(0.5, 0.35)
	assert_float(layer.turrets[0].deploy_progress()).is_between(0.4, 0.6)
	var rise: Node3D = layer.turrets[0].get_node("Rise") as Node3D
	assert_float(rise.position.y).is_less(0.0)
	layer.render(0.5, 1.0)
	assert_float(layer.turrets[0].deploy_progress()).is_equal_approx(1.0, 0.0001)
	assert_float(rise.position.y).is_equal_approx(0.0, 0.001)
	assert_float(layer.turrets[0].upper_yaw()).is_equal_approx(-PI * 0.5, 0.01)
	assert_bool(layer.turret_muzzle_position(0).is_finite()).is_true()


func test_turret_kicks_only_on_its_own_shots() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	w.turrets.active[0] = 1
	w.turrets.active[1] = 1
	layer.render(0.5, 1.0)
	Events.shot_fired.emit(DamageSource.Id.TURRET_1, 1)
	assert_float(layer.turrets[1].recoil_amount()).is_equal(1.0)
	assert_float(layer.turrets[0].recoil_amount()).is_equal(0.0)
	layer.render(0.5, 0.5)
	assert_float(layer.turrets[1].recoil_amount()).is_less(0.01)


func test_turrets_already_deployed_at_bind_are_shown_at_once() -> void:
	var w: SimWorld = ActorsTestKit.world()
	w.turrets.active[1] = 1
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	assert_bool(layer.turrets[1].is_deployed()).is_true()
	assert_float(layer.turrets[1].deploy_progress()).is_equal_approx(1.0, 0.0001)
	assert_bool(layer.turrets[0].visible).is_false()
