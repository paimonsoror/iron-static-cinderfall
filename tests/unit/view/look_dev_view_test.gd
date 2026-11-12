extends GdUnitTestSuite
## W3-C Warden view in the three looks: one MeshInstance3D per body part, tier gating of the materials, the muzzle light
## and the bloom, switching looks without leaking nodes, palette roles, secondary motion.

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookDevMat.overrides.clear()


func after_test() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.CURRENT)
	LookDevMat.overrides.clear()


func _bound() -> Array:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	layer.bind(w)
	return [w, layer]


func _surface_materials(mi: MeshInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	for s: int in mi.mesh.get_surface_count():
		out.append(mi.get_surface_override_material(s))
	return out


func test_each_body_part_is_exactly_one_mesh_instance_in_every_look() -> void:
	var layer: ActorLayer = _bound()[1]
	var warden: WardenView = layer.warden
	var expected: Array[String] = ["Legs", "Torso", "Pistol", "Smg", "ArmRU", "ArmRF", "ArmLU", "ArmLF", "Pack", "Antenna", "Cable"]
	for look: int in 3:
		layer.set_look(look)
		var seen: Dictionary[String, int] = {}
		for n: Node in ViewIntegrationKit.nodes_of(warden, "MeshInstance3D"):
			var key: String = String(n.name)
			var cnt: int = seen.get(key, 0)
			seen[key] = cnt + 1
		assert_int(seen.size()).is_equal(expected.size())
		for part_name: String in expected:
			var found: int = seen.get(part_name, 0)
			assert_int(found).is_equal(1)
		for mi: MeshInstance3D in warden.parts().visible_parts():
			assert_int(mi.mesh.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
	layer.set_look(LookDevStyle.Look.CURRENT)
	assert_int(warden.parts().visible_parts().size()).is_equal(4)
	for mi: MeshInstance3D in warden.parts().extras:
		assert_bool(mi.visible).is_false()


func test_current_look_keeps_the_old_meshes_and_no_override_materials() -> void:
	var layer: ActorLayer = _bound()[1]
	var parts: WardenParts = layer.warden.parts()
	assert_int(layer.warden.look()).is_equal(LookDevStyle.Look.CURRENT)
	assert_object(parts.legs.mesh).is_same(ActorMeshes.warden_legs())
	assert_object(parts.torso.mesh).is_same(ActorMeshes.warden_torso())
	for mi: MeshInstance3D in parts.visible_parts():
		for m: Material in _surface_materials(mi):
			assert_object(m).is_null()
	assert_object(parts.accent_material()).is_null()
	assert_object(layer.warden.muzzle_light()).is_not_null()
	assert_bool(layer.warden.muzzle_light().visible).is_false()


func test_low_tier_has_vertex_colours_only_no_shader_no_rim_no_light() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	layer.set_quality(VisualQuality.Tier.LOW)
	layer.set_look(LookDevStyle.Look.STYLISED_PLUS)
	for mi: MeshInstance3D in layer.warden.parts().visible_parts():
		for m: Material in _surface_materials(mi):
			assert_bool(m is ShaderMaterial).is_false()
			var std: StandardMaterial3D = m as StandardMaterial3D
			assert_object(std).is_not_null()
			assert_bool(std.rim_enabled).is_false()
	var torso: MeshInstance3D = layer.warden.parts().torso
	var ceramic: StandardMaterial3D = _surface_materials(torso)[0] as StandardMaterial3D
	assert_bool(ceramic.vertex_color_use_as_albedo or (_surface_materials(torso)[1] as StandardMaterial3D).vertex_color_use_as_albedo).is_true()
	var low_accent: StandardMaterial3D = layer.warden.parts().accent_material()
	assert_bool(low_accent.emission_enabled).is_false()
	assert_float(low_accent.albedo_color.g).is_between(0.5, 1.0)
	w.warden.aim_x = w.warden.x + 5.0
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	layer.render(0.5, 0.016)
	assert_bool(layer.warden.muzzle_light().visible).is_false()


func test_mid_and_high_use_the_shader_and_only_high_plus_flashes_the_muzzle_light() -> void:
	var layer: ActorLayer = _bound()[1]
	layer.set_look(LookDevStyle.Look.STYLISED_PLUS)
	layer.set_quality(VisualQuality.Tier.MID)
	var torso: MeshInstance3D = layer.warden.parts().torso
	var has_shader: bool = false
	for m: Material in _surface_materials(torso):
		if m is ShaderMaterial:
			has_shader = true
	assert_bool(has_shader).is_true()
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	layer.render(0.5, 0.016)
	assert_bool(layer.warden.muzzle_light().visible).is_false()  # HIGH only
	layer.set_quality(VisualQuality.Tier.HIGH)
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	layer.render(0.5, 0.016)
	assert_bool(layer.warden.muzzle_light().visible).is_true()
	assert_float(layer.warden.muzzle_light().light_energy).is_greater(0.3)
	layer.render(0.5, 0.5)  # a short flash: gone half a second later
	assert_bool(layer.warden.muzzle_light().visible).is_false()
	layer.set_look(LookDevStyle.Look.STYLISED)  # plain STYLISED never has the light
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	layer.render(0.5, 0.016)
	assert_bool(layer.warden.muzzle_light().visible).is_false()


func test_bloom_is_a_plus_touch_on_mid_and_high_and_the_styled_yards_on_high() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		view.set_quality(tier)
		for look: int in 3:
			view.arena_view.set_look(look)
			# W3-E: the styled yard adds its own bloom gate (EnvStyle.GLOW, HIGH) to the STYLISED_PLUS touch (MID and HIGH)
			var want: bool = look == LookDevStyle.Look.STYLISED_PLUS and tier >= VisualQuality.Tier.MID
			want = want or EnvStyle.on(EnvStyle.GLOW, look, tier)
			assert_bool(view.arena_view.glow_active()).is_equal(want)
	view.arena_view.set_look(LookDevStyle.Look.CURRENT)
	view.set_quality(VisualQuality.Tier.HIGH)
	assert_bool(view.arena_view.glow_active()).is_false()


func test_switching_look_fifty_times_neither_adds_nodes_nor_materials() -> void:
	var layer: ActorLayer = _bound()[1]
	for look: int in 3:  # build every mesh and material once
		layer.set_look(look)
	layer.set_look(LookDevStyle.Look.CURRENT)
	var nodes: int = ActorsTestKit.count_nodes(layer)
	var cached: int = LookDevMat.cached_count()
	var legs_mesh: Mesh = ActorMeshes.warden_part(&"legs", LookDevStyle.Look.STYLISED)
	for i: int in 50:
		layer.set_look(i % 3)
		layer.set_quality(i % 3)
		layer.render(0.5, 0.016)
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_int(LookDevMat.cached_count()).is_less_equal(cached + 6)
	assert_object(ActorMeshes.warden_part(&"legs", LookDevStyle.Look.STYLISED)).is_same(legs_mesh)
	layer.set_look(LookDevStyle.Look.CURRENT)
	layer.set_quality(VisualQuality.Tier.HIGH)
	assert_int(ActorsTestKit.count_nodes(layer)).is_equal(nodes)
	assert_object(layer.warden.parts().legs.mesh).is_same(ActorMeshes.warden_legs())


func test_look_can_be_set_before_the_view_exists_and_follows_the_process_wide_choice() -> void:
	LookDevStyle.set_current(LookDevStyle.Look.STYLISED)
	var layer: ActorLayer = _bound()[1]
	assert_int(layer.warden.look()).is_equal(LookDevStyle.Look.STYLISED)
	assert_bool(layer.warden.parts().extras[WardenParts.index_of(&"pack")].visible).is_true()
	layer.set_look(LookDevStyle.Look.CURRENT)
	assert_int(LookDevStyle.current()).is_equal(LookDevStyle.Look.CURRENT)


func test_the_accent_material_is_the_palette_cyan_and_nothing_on_the_warden_is_red() -> void:
	var layer: ActorLayer = _bound()[1]
	var cyan: Color = _content.tokens.color(&"warden_cyan")
	var red: Color = _content.tokens.color(&"chorus_red")
	for look: int in [LookDevStyle.Look.STYLISED, LookDevStyle.Look.STYLISED_PLUS]:
		layer.set_look(look)
		var accent: StandardMaterial3D = layer.warden.parts().accent_material()
		assert_bool(accent.emission_enabled).is_false()
		assert_float(accent.albedo_color.g).is_greater(cyan.g * 0.9)  # the palette cyan, lifted toward white and scaled by the energy
		assert_float(accent.albedo_color.g).is_greater(accent.albedo_color.r)
		for mi: MeshInstance3D in layer.warden.parts().visible_parts():
			for m: Material in _surface_materials(mi):
				var std: StandardMaterial3D = m as StandardMaterial3D
				if std != null:
					assert_that(std.albedo_color).is_not_equal(red)
				var sm: ShaderMaterial = m as ShaderMaterial
				if sm != null:
					assert_that(sm.get_shader_parameter(&"albedo_tint")).is_not_equal(red)
					assert_that(sm.get_shader_parameter(&"rim_color")).is_equal(cyan)


func test_styled_recoil_kicks_the_springs_and_settles_while_current_keeps_the_old_pose() -> void:
	var pair: Array = _bound()
	var layer: ActorLayer = pair[1]
	layer.set_look(LookDevStyle.Look.STYLISED)
	layer.render(0.5, 0.016)
	var antenna: MeshInstance3D = layer.warden.parts().extras[WardenParts.index_of(&"antenna")]
	var pack: MeshInstance3D = layer.warden.parts().extras[WardenParts.index_of(&"pack")]
	var rest_pack: float = pack.rotation.x
	Events.shot_fired.emit(DamageSource.Id.WARDEN, 1)
	var peak: float = 0.0
	for i: int in 12:
		layer.render(0.5, 0.016)
		peak = maxf(peak, absf(antenna.rotation.x))
	assert_float(peak).is_greater(0.05)  # the antenna whips
	assert_float(absf(pack.rotation.x - rest_pack)).is_greater(0.0001)
	for i: int in 240:
		layer.render(0.5, 0.016)
	assert_float(absf(antenna.rotation.x)).is_less(0.01)  # and settles
	assert_float(absf(pack.rotation.x)).is_less(0.01)
	layer.set_look(LookDevStyle.Look.CURRENT)
	layer.render(0.5, 0.016)
	assert_float(antenna.rotation.x).is_equal(0.0)
	assert_float(layer.warden.parts().torso.scale.y).is_equal(1.0)


func test_styled_reload_pose_pulls_the_weapon_in_and_brings_the_support_hand() -> void:
	var layer: ActorLayer = _bound()[1]
	layer.set_look(LookDevStyle.Look.STYLISED)
	var hand: Node3D = layer.warden.get_node("Upper/Body/Hand") as Node3D
	var arm_l: MeshInstance3D = layer.warden.parts().extras[WardenParts.index_of(&"arm_lf")]
	layer.render(0.5, 0.016)
	var rest_pos: Vector3 = hand.position
	var rest_basis: Basis = arm_l.basis
	Events.reload_started.emit(75)
	layer.render(0.5, 0.5)
	assert_float(layer.warden.reload_amount()).is_greater(0.9)
	assert_float(hand.position.x).is_less(rest_pos.x - 0.05)  # pulled in toward the chest
	assert_float(hand.rotation.x).is_less(-0.35)  # muzzle tilted down
	assert_bool(arm_l.basis.is_equal_approx(rest_basis)).is_false()  # the support arm reaches for the magazine
	Events.reload_finished.emit()
	layer.render(0.5, 0.5)
	assert_float(hand.position.x).is_equal_approx(rest_pos.x, 0.01)


func test_styled_aiming_and_muzzle_still_follow_the_sim() -> void:
	var pair: Array = _bound()
	var w: SimWorld = pair[0]
	var layer: ActorLayer = pair[1]
	layer.set_look(LookDevStyle.Look.STYLISED_PLUS)
	w.warden.aim_x = w.warden.x + 6.0
	w.warden.aim_z = w.warden.z
	layer.render(0.5, 1.0)
	var muzzle: Vector3 = layer.warden_muzzle_position()
	assert_float(muzzle.x - w.warden.x).is_greater(0.4)
	assert_float(muzzle.y).is_between(0.9, 1.9)
	assert_float(layer.warden.upper_yaw()).is_equal_approx(-PI * 0.5, 0.01)
