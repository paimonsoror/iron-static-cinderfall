extends GdUnitTestSuite
## W2-E: the battle debug overlay (flow arrows, attack slots, stuck enemies, spawn regions). Every layer is created when
## switched on and freed when switched off; the layers read the sim and never write it.

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)


func _overlay(w: SimWorld) -> BattleDebugOverlay:
	var o: BattleDebugOverlay = BattleDebugOverlay.new()
	auto_free(o)
	add_child(o)
	o.setup(_content.arena)
	o.bind(w)
	return o


func test_spec_parsing_names_layers_and_ignores_garbage() -> void:
	assert_array(BattleDebugOverlay.parse_spec("all")).has_size(4)
	assert_array(BattleDebugOverlay.parse_spec("flow,slots")).contains_exactly([
		BattleDebugOverlay.Layer.FLOW, BattleDebugOverlay.Layer.SLOTS
	])
	assert_array(BattleDebugOverlay.parse_spec(" Stuck , spawns ,nope,stuck")).contains_exactly([
		BattleDebugOverlay.Layer.STUCK, BattleDebugOverlay.Layer.SPAWNS
	])
	assert_array(BattleDebugOverlay.parse_spec("")).is_empty()


func test_each_layer_creates_one_node_and_frees_it_again() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = _overlay(w)
	var before: int = ViewIntegrationKit.count_nodes(o)
	assert_int(o.get_child_count()).is_equal(0)
	for layer: int in BattleDebugOverlay.LAYER_KEYS.size():
		o.set_layer(layer, true)
		var node: Node3D = o.layer_node(layer)
		assert_object(node).is_not_null()
		assert_bool(o.is_layer_on(layer)).is_true()
		assert_bool(node.get_parent() == o).is_true()
		o.set_layer(layer, false)
		assert_bool(is_instance_valid(node)).is_false()  # freed, not just hidden
		assert_object(o.layer_node(layer)).is_null()
		assert_bool(o.is_layer_on(layer)).is_false()
		assert_int(ViewIntegrationKit.count_nodes(o)).is_equal(before)
	o.apply_spec("all")
	assert_int(o.active_layers().size()).is_equal(4)
	assert_int(o.get_child_count()).is_equal(4)
	o.toggle(BattleDebugOverlay.Layer.FLOW)
	assert_int(o.get_child_count()).is_equal(3)
	o.unbind()
	assert_int(o.get_child_count()).is_equal(0)
	assert_bool(o.is_layer_on(BattleDebugOverlay.Layer.SLOTS)).is_true()  # asked for, comes back on the next bind
	o.bind(w)
	assert_int(o.get_child_count()).is_equal(3)


func test_layers_asked_for_before_bind_appear_on_bind() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = BattleDebugOverlay.new()
	auto_free(o)
	add_child(o)
	o.setup(_content.arena)
	o.apply_spec("flow,spawns")
	assert_int(o.get_child_count()).is_equal(0)
	o.bind(w)
	assert_int(o.get_child_count()).is_equal(2)


func test_flow_layer_draws_one_arrow_per_walkable_cell() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = _overlay(w)
	o.set_layer(BattleDebugOverlay.Layer.FLOW, true)
	var mmi: MultiMeshInstance3D = o.layer_node(BattleDebugOverlay.Layer.FLOW) as MultiMeshInstance3D
	var flow: FlowField = w.nav.flow
	var open: int = 0
	for c: int in flow.grid.cols * flow.grid.rows:
		if flow.grid.blocked[c] == 0 and not is_inf(flow.cost[c]):
			open += 1
	assert_int(mmi.multimesh.visible_instance_count).is_equal(open)
	assert_int(open).is_greater(200)
	# an arrow points where the field points: its +X axis is the cell's direction (the headless renderer keeps no
	# instance buffer, so the orientation is checked on the function that builds it)
	for c: int in [0, 5, 40, 100, 200]:
		if flow.grid.blocked[c] == 1 or is_inf(flow.cost[c]):
			continue
		var axis: Vector3 = BattleDebugOverlay.arrow_basis(flow.dir_x[c], flow.dir_z[c]).x
		assert_float(axis.x).is_equal_approx(flow.dir_x[c], 0.001)
		assert_float(axis.z).is_equal_approx(flow.dir_z[c], 0.001)
	assert_float(BattleDebugOverlay.arrow_basis(0.0, 1.0).x.z).is_equal_approx(1.0, 0.0001)  # screen down = +Z
	assert_float(BattleDebugOverlay.arrow_basis(-1.0, 0.0).x.x).is_equal_approx(-1.0, 0.0001)  # toward the core = left


func test_slot_layer_follows_the_occupancy_of_the_slots() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = _overlay(w)
	o.set_layer(BattleDebugOverlay.Layer.SLOTS, true)
	o.update(0.016)
	assert_int(o.taken_slot_count()).is_equal(0)
	var total: int = w.nav.slots.slot_count()
	var root: Node3D = o.layer_node(BattleDebugOverlay.Layer.SLOTS)
	var free_mm: MultiMesh = (root.get_node("SlotsFree") as MultiMeshInstance3D).multimesh
	assert_int(free_mm.visible_instance_count).is_equal(total)
	for n: int in 5:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, -5.0, 3.0 + float(n))
		var slot: int = w.nav.slots.claim(w, i)
		assert_int(slot).is_greater_equal(0)
	o.update(0.016)
	assert_int(o.taken_slot_count()).is_equal(5)
	assert_int(free_mm.visible_instance_count).is_equal(total - 5)


func test_stuck_layer_marks_an_enemy_by_event_and_by_state_then_lets_go() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = _overlay(w)
	o.set_layer(BattleDebugOverlay.Layer.STUCK, true)
	var a: int = w.spawn_enemy(Ids.EN_SKITTER, 4.0, 0.0)
	var b: int = w.spawn_enemy(Ids.EN_RUSHER, 5.0, 1.0)
	o.update(0.016)
	assert_int(o.stuck_count()).is_equal(0)
	# by state: the sim flagged it (grace period of a stuck recovery)
	w.nav.track_id[a] = w.enemies.id[a]
	w.nav.grace[a] = 1
	o.update(0.016)
	assert_int(o.stuck_count()).is_equal(1)
	w.nav.grace[a] = 0
	# by event: the marker stays for a while after enemy_stuck
	Events.enemy_stuck.emit(w.enemies.id[b])
	o.update(0.016)
	assert_int(o.stuck_count()).is_equal(1)
	o.update(BattleDebugOverlay.STUCK_HOLD_S + 0.1)
	assert_int(o.stuck_count()).is_equal(0)


func test_spawn_layer_covers_every_region_and_the_overlay_never_writes_the_sim() -> void:
	var w: SimWorld = ActorsTestKit.world()
	ActorsTestKit.spawn_mixed(w, 20)
	var before: String = w.state_hash()
	var o: BattleDebugOverlay = _overlay(w)
	o.apply_spec("all")
	o.update(0.016)
	var spawns: MeshInstance3D = o.layer_node(BattleDebugOverlay.Layer.SPAWNS) as MeshInstance3D
	var box: AABB = spawns.mesh.get_aabb()
	for r: SpawnRegionDef in _content.arena.spawn_regions:
		assert_bool(box.has_point(Vector3((r.x0 + r.x1) * 0.5, 0.09, (r.z0 + r.z1) * 0.5))).is_true()
	assert_str(w.state_hash()).is_equal(before)


func test_overlay_layers_are_unshaded_and_cast_no_shadows() -> void:
	var w: SimWorld = ActorsTestKit.world()
	var o: BattleDebugOverlay = _overlay(w)
	o.apply_spec("all")
	for n: Node in ViewIntegrationKit.nodes_of(o, "GeometryInstance3D"):
		var g: GeometryInstance3D = n as GeometryInstance3D
		assert_int(g.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var m: StandardMaterial3D = g.material_override as StandardMaterial3D
		assert_object(m).is_not_null()
		assert_bool(m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED).is_true()
