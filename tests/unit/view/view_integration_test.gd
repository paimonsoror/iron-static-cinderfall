extends GdUnitTestSuite
## W2-E: the whole BattleView with 50 enemies bound under the headless renderer. Node budget, pools at budget, quality
## tiers, shadows off on actors, teleports, pad-mounted turrets, ShaderWarmup (ARCH 8, 13).

const NODE_BUDGET: int = 400

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)


func test_fifty_enemies_bound_keep_the_node_count_under_budget() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold50")
	view.bind(p.world)
	view.render(1.0, SimPuppet.TICK_DT)
	assert_int(p.world.alive_count()).is_equal(50)
	assert_int(view.actor_layer.visible_enemy_count()).is_equal(50)
	var nodes: int = ViewIntegrationKit.count_nodes(view)
	print("VIEW_NODES hold50 bound: %d nodes under BattleView (budget %d)" % [nodes, NODE_BUDGET])
	assert_int(nodes).is_less(NODE_BUDGET)
	# a running battle (spawns, kills, shots, abilities) allocates nothing after setup
	ViewIntegrationKit.run(view, p, 360)
	assert_int(ViewIntegrationKit.count_nodes(view)).is_equal(nodes)


func test_pools_stay_at_their_architecture_budget() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold50")
	view.bind(p.world)
	ViewIntegrationKit.run(view, p, 240)
	var pool: EnemyPool = view.actor_layer.enemy_pool()
	for kind: int in EnemyPool.SIZES.size():
		assert_int(pool.capacity(kind)).is_equal(EnemyPool.SIZES[kind])
	assert_int(view.vfx_layer.tracer_capacity()).is_equal(VfxLayer.TRACER_CAP)
	assert_int(view.vfx_layer.tracer_count()).is_less_equal(VfxLayer.TRACER_CAP)
	assert_int(view.vfx_layer.text_count()).is_less_equal(FloatingTexts.CAPACITY)
	assert_int(view.vfx_layer.spark_count()).is_less_equal(VfxLayer.SPARK_CAP)
	assert_int(view.actor_layer.decals().shadow_count()).is_less_equal(ActorDecals.SHADOW_CAPACITY)


func test_set_quality_low_removes_omni_lights_and_rain() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	view.set_quality(VisualQuality.Tier.HIGH)
	assert_int(view.arena_view.visible_omni_count()).is_equal(4)
	assert_bool(view.arena_view.rain_visible()).is_true()
	view.set_quality(VisualQuality.Tier.LOW)
	assert_int(view.arena_view.visible_omni_count()).is_equal(0)
	assert_bool(view.arena_view.rain_visible()).is_false()
	var lit: int = 0
	for light: Node in ViewIntegrationKit.nodes_of(view, "OmniLight3D"):
		if (light as OmniLight3D).visible:
			lit += 1
	assert_int(lit).is_equal(0)
	assert_bool(view.arena_view.sun.shadow_enabled).is_false()
	assert_int(view.actor_layer.quality()).is_equal(VisualQuality.Tier.LOW)
	assert_int(view.vfx_layer.quality()).is_equal(VisualQuality.Tier.LOW)
	view.set_quality(VisualQuality.Tier.MID)
	assert_int(view.arena_view.visible_omni_count()).is_equal(2)


func test_the_shadow_atlas_is_smaller_than_the_engine_default_on_every_tier() -> void:
	for tier: int in [VisualQuality.Tier.LOW, VisualQuality.Tier.MID, VisualQuality.Tier.HIGH]:
		assert_int(VisualQuality.shadow_atlas_size(tier)).is_less(4096)
	assert_int(VisualQuality.shadow_atlas_size(VisualQuality.Tier.HIGH)).is_greater_equal(
		VisualQuality.shadow_atlas_size(VisualQuality.Tier.LOW)
	)


func test_render_scale_is_lower_only_on_low_and_applies_to_a_viewport() -> void:
	assert_float(VisualQuality.render_scale(VisualQuality.Tier.LOW)).is_less(1.0)
	assert_float(VisualQuality.render_scale(VisualQuality.Tier.MID)).is_equal(1.0)
	assert_float(VisualQuality.render_scale(VisualQuality.Tier.HIGH)).is_equal(1.0)
	var vp: SubViewport = SubViewport.new()
	auto_free(vp)
	VisualQuality.apply_render_scale(vp, VisualQuality.Tier.LOW)
	assert_float(vp.scaling_3d_scale).is_equal_approx(VisualQuality.render_scale(VisualQuality.Tier.LOW), 0.0001)
	VisualQuality.apply_render_scale(vp, VisualQuality.Tier.HIGH)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)


func test_the_arena_applies_the_tier_render_scale_to_its_own_viewport() -> void:
	var vp: SubViewport = SubViewport.new()
	auto_free(vp)
	add_child(vp)
	var arena: ArenaView = ArenaView.new()
	auto_free(arena)
	vp.add_child(arena)
	arena.setup(_content.arena, _content.tokens)
	arena.set_quality(VisualQuality.Tier.LOW)
	assert_float(vp.scaling_3d_scale).is_equal_approx(VisualQuality.render_scale(VisualQuality.Tier.LOW), 0.0001)
	arena.set_quality(VisualQuality.Tier.HIGH)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)
	arena.set_quality(VisualQuality.Tier.LOW)
	vp.remove_child(arena)  # leaving the tree hands the viewport back at full scale
	assert_float(vp.scaling_3d_scale).is_equal(1.0)


func test_actor_and_turret_meshes_cast_no_shadows_even_on_high() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	view.set_quality(VisualQuality.Tier.HIGH)
	var checked: int = 0
	for n: Node in ViewIntegrationKit.nodes_of(view.actor_layer, "GeometryInstance3D"):
		var g: GeometryInstance3D = n as GeometryInstance3D
		assert_int(g.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		checked += 1
	# 108 enemies, Warden (legs, torso, two weapons), two turrets (base, head), three decal multimeshes, boss marker
	assert_int(checked).is_greater(108 + 4 + 4)
	# the static props are the only casters, and only on HIGH
	assert_int((view.arena_view.get_node("Props") as MeshInstance3D).cast_shadow).is_equal(
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)


func test_forced_move_is_drawn_at_the_new_place_not_slid_over_one_tick() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var layer: ActorLayer = ActorsTestKit.actor_layer(self, w)
	auto_free(layer)
	var walker: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0, 0.0)
	var teleported: int = w.spawn_enemy(Ids.EN_SKITTER, 2.0, 4.0)
	layer.bind(w)
	# the walker covers 5 cm in the tick; the other one was forced 6 m by a stuck recovery (prev is last tick's spot)
	w.enemies.prev_x[walker] = 1.95
	w.enemies.x[teleported] = 8.0
	w.enemies.prev_x[teleported] = 2.0
	layer.render(0.5, 0.016)
	var walker_x: float = layer.enemy_world_position(w.enemies.id[walker]).x
	var forced_x: float = layer.enemy_world_position(w.enemies.id[teleported]).x
	assert_float(walker_x).is_equal_approx(1.975, 0.001)  # interpolated halfway
	assert_float(forced_x).is_equal_approx(8.0, 0.001)  # no slide: already at the new position
	# the next tick the sim sets prev = x again and ordinary interpolation resumes
	w.enemies.prev_x[teleported] = 8.0
	w.enemies.x[teleported] = 8.05
	layer.render(0.5, 0.016)
	assert_float(layer.enemy_world_position(w.enemies.id[teleported]).x).is_equal_approx(8.025, 0.001)


func test_turrets_stand_on_their_pads_at_pad_height() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var p: SimPuppet = ViewIntegrationKit.puppet(self, _content, "hold10")
	view.bind(p.world)
	ViewIntegrationKit.run(view, p, 150)  # both turrets are bought by 1.0 s
	assert_int(p.world.turrets.active_count()).is_equal(2)
	var arena: ArenaDef = _content.arena
	for pad: int in arena.turret_pads.size():
		var t: TurretView = view.actor_layer.turrets[pad]
		assert_bool(t.is_deployed()).is_true()
		assert_float(t.position.x).is_equal_approx(arena.turret_pads[pad].x, 0.0001)
		assert_float(t.position.z).is_equal_approx(arena.turret_pads[pad].y, 0.0001)
		assert_float(t.position.y).is_equal_approx(TurretView.PAD_TOP_Y, 0.0001)
		var pad_node: Node3D = view.arena_view.get_node("Pad%d" % pad) as Node3D
		assert_float(pad_node.position.x).is_equal_approx(t.position.x, 0.0001)
		assert_float(pad_node.position.z).is_equal_approx(t.position.z, 0.0001)
		assert_bool(view.arena_view.pad_is_lit(pad)).is_true()
	# the pad is a 0.12 m slab with 1 cm marks on top: its highest point is what the turret stands on
	var pad_box: AABB = (view.arena_view.get_node("Pad0") as MeshInstance3D).mesh.get_aabb()
	assert_float(pad_box.end.y).is_between(TurretView.PAD_TOP_Y, TurretView.PAD_TOP_Y + 0.05)


func test_shader_warmup_also_draws_a_label_and_the_screen_flash_once() -> void:
	var host: Node3D = Node3D.new()
	auto_free(host)
	add_child(host)
	var extra: Array[Material] = []
	var w: ShaderWarmup = ShaderWarmup.attach(host, Vector3(0.0, -0.4, 0.0), extra)
	assert_object(w.label).is_not_null()
	assert_bool(w.label.get_parent() == w).is_true()
	assert_bool(w.label.text.contains("+")).is_true()
	assert_float(w.label.modulate.a).is_equal_approx(ShaderWarmup.ALPHA, 0.0001)
	assert_bool(w.label.no_depth_test).is_true()  # the same pipeline as the real floating texts
	assert_object(w.flash).is_not_null()
	assert_bool(w.flash is CanvasLayer).is_true()
	assert_bool(w.flash.is_flash_visible()).is_true()
	assert_float(w.flash.rect.color.a).is_equal_approx(ShaderWarmup.ALPHA, 0.0001)
	# two frames, then the node and both children go away
	w._process(0.016)
	assert_bool(w.is_queued_for_deletion()).is_false()
	w._process(0.016)
	assert_bool(w.is_queued_for_deletion()).is_true()


func test_arena_warmup_sits_just_under_the_ground() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, _content)
	var w: ShaderWarmup = view.arena_view.get_node("ShaderWarmup") as ShaderWarmup
	assert_float(w.position.y).is_less(0.0)  # the Mobile renderer ignores GeometryInstance3D.transparency
	assert_int(w.mesh.get_surface_count()).is_equal(MatLib.IDS.size() + 1)
