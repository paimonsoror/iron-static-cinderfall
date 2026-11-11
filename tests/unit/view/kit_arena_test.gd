extends GdUnitTestSuite
## ArenaView under the headless renderer: node budget, required parts, props from arena.json, dressing outside the
## rectangle, triangle budget, core and pad states, quality tiers, ShaderWarmup (A04, A17).

const NODE_BUDGET: int = 60
const TRIANGLE_BUDGET: int = 25000

var _content: ContentSet


func before_test() -> void:
	_content = TestContent.baseline()
	MatLib.configure(_content.tokens)


func _view() -> ArenaView:
	var v: ArenaView = auto_free(ArenaView.new())
	v.setup(_content.arena, _content.tokens)
	return v


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	for c: Node in root.get_children():
		out.append_array(_meshes(c))
	return out


func _vertices(mi: MeshInstance3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	for s: int in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		out.append_array(verts)
	return out


func _triangles(mi: MeshInstance3D) -> int:
	var n: int = 0
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += floori(float(idx.size()) / 3.0)
	return n


func _lights_of_type(root: Node, type_name: String) -> int:
	var n: int = 1 if root.is_class(type_name) else 0
	for c: Node in root.get_children():
		n += _lights_of_type(c, type_name)
	return n


func test_setup_creates_at_most_60_nodes_and_does_not_error() -> void:
	var v: ArenaView = _view()
	assert_int(v.node_count()).is_between(15, NODE_BUDGET)


func test_all_required_parts_exist() -> void:
	var v: ArenaView = _view()
	for part: String in ["Ground", "Stencil", "Props", "Decor", "LampHeads", "Pad0", "Pad1", "WardenRing", "Core", "SpawnGlow"]:
		assert_object(v.get_node_or_null(part)).override_failure_message("missing " + part).is_not_null()
	assert_int(_lights_of_type(v, "DirectionalLight3D")).is_equal(1)
	assert_int(_lights_of_type(v, "WorldEnvironment")).is_equal(1)
	assert_object(v.environment_node.environment).is_not_null()
	assert_int(v.environment_node.environment.background_mode).is_equal(Environment.BG_COLOR)
	assert_bool(v.environment_node.environment.glow_enabled).is_false()
	assert_bool(v.environment_node.environment.ssao_enabled).is_false()
	assert_int(v.omnis.size()).is_equal(4)


func test_core_label_reads_relay_core_b4() -> void:
	var v: ArenaView = _view()
	var label: Label3D = v.core.label_node()
	assert_str(label.text).is_equal("RELAY CORE B-4")
	assert_str((v.get_node("Stencil") as Label3D).text).is_equal("B-4")
	# The plate sits on the core: the label is within the core's footprint on X and just in front of it on Z.
	var world: Vector3 = label.global_transform.origin if label.is_inside_tree() else v.core.position + label.position
	assert_float(absf(world.x - _content.arena.core_x)).is_less(0.5)
	assert_float(world.z).is_greater(_content.arena.core_z)


func test_core_pads_and_ring_sit_where_arena_json_says() -> void:
	var v: ArenaView = _view()
	var a: ArenaDef = _content.arena
	var core_node: Node3D = v.get_node("Core")
	var ring_node: Node3D = v.get_node("WardenRing")
	assert_vector(core_node.position).is_equal_approx(Vector3(a.core_x, 0.0, a.core_z), Vector3(0.001, 0.001, 0.001))
	assert_vector(ring_node.position).is_equal_approx(Vector3(a.warden_x, 0.0, a.warden_z), Vector3(0.001, 0.001, 0.001))
	for i: int in a.turret_pads.size():
		var pad: Node3D = v.get_node("Pad%d" % i)
		assert_vector(pad.position).is_equal_approx(Vector3(a.turret_pads[i].x, 0.0, a.turret_pads[i].y), Vector3(0.001, 0.001, 0.001))


func test_props_come_from_the_obstacles_of_arena_json() -> void:
	var v: ArenaView = _view()
	var props: MeshInstance3D = v.get_node("Props")
	var verts: PackedVector3Array = _vertices(props)
	for ob: ObstacleDef in _content.arena.obstacles:
		var near: int = 0
		for p: Vector3 in verts:
			if p.y > 0.2 and ob.contains(p.x, p.z, 0.3):
				near += 1
		assert_int(near).override_failure_message("no geometry for %s (%s)" % [ob.id, ob.visual]).is_greater(8)
	# No stray geometry: every vertex belongs to one of the obstacles (shadow blobs may lean a little).
	for p: Vector3 in verts:
		var owned: bool = false
		for ob: ObstacleDef in _content.arena.obstacles:
			if ob.contains(p.x, p.z, 0.9):
				owned = true
				break
		assert_bool(owned).override_failure_message("stray prop vertex %s" % p).is_true()


func test_dressing_stays_outside_the_playable_rectangle() -> void:
	var v: ArenaView = _view()
	var a: ArenaDef = _content.arena
	var decor: MeshInstance3D = v.get_node("Decor")
	var verts: PackedVector3Array = _vertices(decor)
	assert_int(verts.size()).is_greater(2000)
	for p: Vector3 in verts:
		var inside: bool = p.x > a.min_x and p.x < a.max_x and p.z > a.min_z and p.z < a.max_z
		if inside and p.y < 1.0:
			fail("decor footprint inside the playable rectangle at %s" % p)
			return
	# Also clear of both spawn segments.
	for r: SpawnRegionDef in a.spawn_regions:
		for p: Vector3 in verts:
			if p.y > 1.0:
				continue
			var d: float = Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(r.x0, r.z0), Vector2(r.x1, r.z1)).distance_to(Vector2(p.x, p.z))
			if d < 0.4:
				fail("decor blocks spawn region %s at %s" % [r.id, p])
				return


func test_arena_triangle_budget() -> void:
	var v: ArenaView = _view()
	var total: int = 0
	for mi: MeshInstance3D in _meshes(v):
		total += _triangles(mi)
	assert_int(total).is_between(2000, TRIANGLE_BUDGET)


func test_palette_only_no_foreign_colors_on_static_surfaces() -> void:
	var v: ArenaView = _view()
	# Every surface material of the merged meshes is a MatLib material (palette roles), never an ad hoc color.
	for node_name: String in ["Props", "Decor"]:
		var mi: MeshInstance3D = v.get_node(node_name)
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			var known: bool = false
			for id: StringName in MatLib.IDS:
				if MatLib.mat(id) == m:
					known = true
					break
			assert_bool(known).override_failure_message("%s surface %d is not a MatLib material" % [node_name, s]).is_true()


func test_core_dims_flickers_and_goes_dark_with_sparks() -> void:
	var v: ArenaView = _view()
	v.set_core_state(1.0, 0.0, false)
	v.advance(3.0)
	var full: float = v.core.glow()
	assert_float(full).is_equal_approx(1.0, 0.01)
	assert_bool(v.core.sparks_visible()).is_false()
	v.set_core_state(0.25, 0.0, false)
	v.advance(3.0)
	var low: float = v.core.glow()
	assert_float(low).is_less(full - 0.25)
	assert_float(low).is_greater(0.15)
	# Low integrity flickers: over a few simulated seconds the brightness dips at least once.
	var dipped: bool = false
	for i: int in 400:
		v.advance(0.016)
		if v.core.flicker_factor() < 0.9:
			dipped = true
	assert_bool(dipped).is_true()
	v.set_core_state(0.0, 0.0, true)
	v.advance(3.0)
	assert_bool(v.core.is_dead()).is_true()
	assert_float(v.core.glow()).is_equal(0.0)
	assert_float(v.core.light_level()).is_equal(0.0)
	var saw_sparks: bool = false
	for i: int in 60:
		v.advance(0.05)
		saw_sparks = saw_sparks or v.core.sparks_visible()
	assert_bool(saw_sparks).is_true()
	# Healthy at full integrity never flickers.
	v.set_core_state(1.0, 0.0, false)
	for i: int in 200:
		v.advance(0.016)
		assert_float(v.core.flicker_factor()).is_equal(1.0)


func test_shield_fraction_shows_a_cyan_ring_around_the_core() -> void:
	var v: ArenaView = _view()
	v.set_core_state(1.0, 0.0, false)
	assert_bool(v.core.shield_visible()).is_false()
	v.set_core_state(1.0, 0.8, false)
	assert_bool(v.core.shield_visible()).is_true()
	v.set_core_state(0.0, 0.8, true)
	assert_bool(v.core.shield_visible()).is_false()


func test_reduced_flash_keeps_the_flicker_shallow() -> void:
	var v: ArenaView = _view()
	v.set_reduced_flash(true)
	v.set_core_state(0.1, 0.0, false)
	var lowest: float = 1.0
	for i: int in 600:
		v.advance(0.016)
		lowest = minf(lowest, v.core.flicker_factor())
	assert_float(lowest).is_greater_equal(0.78)


func test_pad_state_switches_between_empty_and_occupied() -> void:
	var v: ArenaView = _view()
	assert_bool(v.pad_is_lit(0)).is_false()
	assert_bool((v.get_node("PadPool0") as Node3D).visible).is_false()
	v.set_pad_state(0, true)
	assert_bool(v.pad_is_lit(0)).is_true()
	assert_bool((v.get_node("PadPool0") as Node3D).visible).is_true()
	assert_bool(v.pad_is_lit(1)).is_false()
	var pad: MeshInstance3D = v.get_node("Pad0")
	assert_object(pad.get_surface_override_material(1)).is_same(MatLib.mat(&"emit_cyan"))
	v.set_pad_state(0, false)
	assert_object(pad.get_surface_override_material(1)).is_not_same(MatLib.mat(&"emit_cyan"))
	# Out-of-range pads are ignored.
	v.set_pad_state(7, true)
	v.set_pad_state(-1, true)
	assert_bool(v.pad_is_lit(7)).is_false()


func test_quality_tiers_follow_the_architecture_budget() -> void:
	var v: ArenaView = _view()
	v.set_quality(VisualQuality.Tier.LOW)
	assert_int(v.visible_omni_count()).is_equal(0)
	assert_bool(v.sun.shadow_enabled).is_false()
	assert_bool(v.rain_visible()).is_false()
	v.set_quality(VisualQuality.Tier.MID)
	assert_int(v.visible_omni_count()).is_equal(2)
	assert_bool(v.sun.shadow_enabled).is_false()
	assert_bool(v.rain_visible()).is_false()
	v.set_quality(VisualQuality.Tier.HIGH)
	assert_int(v.visible_omni_count()).is_equal(4)
	assert_bool(v.sun.shadow_enabled).is_true()
	assert_bool(v.rain_visible()).is_true()
	assert_int((v.get_node("Props") as MeshInstance3D).cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	v.set_quality(VisualQuality.Tier.LOW)
	assert_int((v.get_node("Props") as MeshInstance3D).cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# Out-of-range values clamp; unshadowed lights only.
	v.set_quality(99)
	assert_int(v.tier()).is_equal(VisualQuality.Tier.HIGH)
	for o: OmniLight3D in v.omnis:
		assert_bool(o.shadow_enabled).is_false()


func test_shader_warmup_covers_every_material_and_frees_itself() -> void:
	var v: ArenaView = _view()
	var w: ShaderWarmup = v.get_node("ShaderWarmup")
	assert_float(w.transparency).is_equal_approx(1.0 - ShaderWarmup.ALPHA, 0.0001)
	assert_int(w.mesh.get_surface_count()).is_equal(MatLib.IDS.size() + 1)
	assert_int(w.frames_left).is_equal(2)
	w._process(0.016)
	assert_bool(w.is_queued_for_deletion()).is_false()
	w._process(0.016)
	assert_bool(w.is_queued_for_deletion()).is_true()
