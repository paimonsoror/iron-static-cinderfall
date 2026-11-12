extends GdUnitTestSuite
## W3-D hard-surface actors: triangle budgets, at most 3 surfaces, palette roles, the single red optic, baked ambient
## occlusion and weathering in range, determinism, the Skitter footprint, the Hulk and the turret frames, and CURRENT
## byte-identical (the hash table of look_dev_meshes_test.gd covers every actor; here the new accessors).

const STYLED: int = LookDevStyle.Look.STYLISED
const PLUS: int = LookDevStyle.Look.STYLISED_PLUS
const CURRENT: int = LookDevStyle.Look.CURRENT
const ENEMIES: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk"]
## The CURRENT meshes of look_dev_meshes_test.gd BASELINE: triangles and FNV hash.
const CURRENT_PINS: Dictionary[String, Array] = {
	"skitter": [240, 1912435234558808253],
	"hollow_warden": [264, 3461412639251264139],
	"rusher": [284, 2606849488968514826],
	"siege_hulk": [496, 2354974199534980569],
	"turret_base": [96, 3425167843006112341],
	"turret_head": [80, 8593690147155910097],
}


func before_test() -> void:
	MatLib.configure(TestContent.baseline().tokens)
	LookActorsStyle.rollout_override = -1


func after_test() -> void:
	LookActorsStyle.rollout_override = -1


func _tris(m: ArrayMesh) -> int:
	return ActorMeshes.triangle_count(m)


func _turret_meshes(look: int) -> Array[ArrayMesh]:
	return [ActorMeshes.turret_part(&"base", look), ActorMeshes.turret_part(&"head", look)]


func test_styled_meshes_fit_their_budgets_and_are_not_trivial() -> void:
	for id: StringName in ENEMIES:
		var n: int = _tris(ActorMeshes.enemy_look(id, STYLED))
		print("ACTOR_TRIS %s=%d (budget %d, CURRENT %d)" % [id, n, ActorMeshes.TRI_BUDGET[id], _tris(ActorMeshes.enemy(id))])
		assert_int(n).is_between(300, ActorMeshes.TRI_BUDGET[id])
	var turret: int = _tris(ActorMeshes.turret_part(&"base", STYLED)) + _tris(ActorMeshes.turret_part(&"head", STYLED))
	print("ACTOR_TRIS turret=%d (budget %d)" % [turret, ActorMeshes.TRI_BUDGET[&"turret"]])
	assert_int(turret).is_between(300, ActorMeshes.TRI_BUDGET[&"turret"])


func test_every_styled_actor_mesh_has_at_most_three_surfaces_and_only_palette_roles() -> void:
	for id: StringName in ENEMIES:
		var m: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
		assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
		for role: StringName in LookActorsTestKit.roles(m):
			assert_bool([&"gunmetal", &"ceramic", &"emit_red"].has(role)).is_true()
	for m: ArrayMesh in _turret_meshes(STYLED):
		assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
		for role: StringName in LookActorsTestKit.roles(m):
			assert_bool([&"gunmetal", &"ceramic", &"emit_cyan"].has(role)).is_true()


func test_every_enemy_has_one_bright_optic_never_a_pair_and_no_cyan() -> void:
	for id: StringName in ENEMIES:
		var m: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
		var roles: Array[StringName] = LookActorsTestKit.roles(m)
		assert_bool(roles.has(&"emit_red")).is_true()
		assert_bool(roles.has(&"emit_cyan")).is_false()
		var clusters: Array[Dictionary] = LookActorsTestKit.red_clusters(m)
		var bright: int = 0
		for c: Dictionary in clusters:
			var tint: float = c["tint"]
			if tint >= 0.95:
				bright += 1
			var at: Vector3 = c["center"]
			for d: Dictionary in clusters:
				var other: Vector3 = d["center"]
				if absf(at.x) > 0.05:  # no second eye: no red piece has a mirror image across the body's axis
					assert_float(at.distance_to(Vector3(-other.x, other.y, other.z))).is_greater(0.05)
		print("OPTICS %s clusters=%d bright=%d" % [id, clusters.size(), bright])
		assert_int(bright).is_equal(1)  # the head optic is the only full-bright red (the Rusher's spine and the Hulk's core are dimmer)
		assert_int(clusters.size()).is_between(1, 3)


func test_the_turret_is_cyan_and_never_red() -> void:
	var cyan: bool = false
	for m: ArrayMesh in _turret_meshes(STYLED):
		var roles: Array[StringName] = LookActorsTestKit.roles(m)
		assert_bool(roles.has(&"emit_red")).is_false()
		assert_bool(roles.has(&"steel_red")).is_false()
		cyan = cyan or roles.has(&"emit_cyan")
	assert_bool(cyan).is_true()


func test_baked_vertex_colours_are_in_range_darkened_and_weathered() -> void:
	var meshes: Array[ArrayMesh] = _turret_meshes(STYLED)
	for id: StringName in ENEMIES:
		meshes.append(ActorMeshes.enemy_look(id, STYLED))
	for m: ArrayMesh in meshes:
		for s: int in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			assert_int(cols.size()).is_equal(verts.size())
			for c: Color in cols:
				assert_float(minf(c.r, minf(c.g, minf(c.b, c.a)))).is_greater_equal(0.0)
				assert_float(maxf(c.r, maxf(c.g, maxf(c.b, c.a)))).is_less_equal(1.0)
			var role: StringName = StringName(m.surface_get_material(s).resource_name)
			if role == &"emit_red" or role == &"emit_cyan":
				continue
			var stats: Dictionary = LookActorsTestKit.luma_stats(m, s)
			var lo: float = stats["min"]
			var hi: float = stats["max"]
			var sigma: float = stats["sigma"]
			var mean: float = stats["mean"]
			assert_float(lo).is_less(hi * 0.8)  # ambient occlusion and grime: the creases are darker than the open plates
			assert_float(sigma / maxf(mean, 0.01)).is_greater(0.08)  # weathering: not one flat value (relative: the turret frame is very dark)
			var chipped: int = 0
			for c2: Color in cols:
				if c2.a > 0.2:
					chipped += 1
			var share: float = float(chipped) / float(maxi(cols.size(), 1))
			if share < 0.005 or share > 0.8:
				print("CHIPS out of range: %s surface %s share=%.3f" % [m.get_aabb().size, role, share])
			assert_float(share).is_between(0.005, 0.8)  # edge wear and chips exist and do not eat the plates


func test_styled_meshes_are_deterministic_and_cached_apart_from_current() -> void:
	var builds: Array[Callable] = [
		LookActorsSkitter.build, LookActorsHollow.build, LookActorsRusher.build, LookActorsHulk.build,
		LookActorsTurret.base, LookActorsTurret.head,
	]
	for b: Callable in builds:
		var one: ArrayMesh = b.call()
		var two: ArrayMesh = b.call()
		assert_int(LookDevTestKit.mesh_hash(one)).is_equal(LookDevTestKit.mesh_hash(two))
		assert_int(LookDevTestKit.vertex_count(one)).is_equal(LookDevTestKit.vertex_count(two))
	for id: StringName in ENEMIES:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy_look(id, PLUS))
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy_look(id, STYLED))
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_not_same(ActorMeshes.enemy(id))


func test_current_is_byte_identical_through_the_new_accessors_even_after_styled_meshes_exist() -> void:
	for id: StringName in ENEMIES:
		var _styled: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
	for part: StringName in [&"base", &"head"]:
		var _t: ArrayMesh = ActorMeshes.turret_part(part, STYLED)
	for id: StringName in ENEMIES:
		var m: ArrayMesh = ActorMeshes.enemy_look(id, CURRENT)
		assert_object(m).is_same(ActorMeshes.enemy(id))
		_expect_pin(String(id), m)
	_expect_pin("turret_base", ActorMeshes.turret_part(&"base", CURRENT))
	_expect_pin("turret_head", ActorMeshes.turret_part(&"head", CURRENT))


func test_a_switched_off_rollout_keeps_every_actor_in_current() -> void:
	LookActorsStyle.rollout_override = 0
	for id: StringName in ENEMIES:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy(id))
	assert_object(ActorMeshes.turret_part(&"head", STYLED)).is_same(ActorMeshes.turret_head())


func test_the_skitter_stays_inside_its_slot_footprint() -> void:
	var old: ArrayMesh = ActorMeshes.enemy(&"skitter")
	var styled: ArrayMesh = ActorMeshes.enemy_look(&"skitter", STYLED)
	var radius: float = LookActorsKit.footprint_radius(styled)
	var width: float = styled.get_aabb().size.x
	print("SKITTER footprint radius=%.3f width=%.3f (CURRENT radius %.3f width %.3f)" % [radius, width, LookActorsKit.footprint_radius(old), old.get_aabb().size.x])
	var slot: float = TestContent.baseline().enemies[Ids.EN_SKITTER].radius  # the sim keeps skitters 2 radii apart
	assert_float(width).is_less_equal(slot * 2.0 + 0.1)
	assert_float(radius).is_less_equal(slot * 1.6)
	assert_float(radius).is_less(LookActorsKit.footprint_radius(old) * 0.65)


func test_enemy_heights_and_footprints_follow_the_content() -> void:
	var content: ContentSet = TestContent.baseline()
	for def: EnemyDef in content.enemies:
		var bb: AABB = ActorMeshes.enemy_look(def.visual_id, STYLED).get_aabb()
		assert_float(bb.size.y).is_between(def.visual_height_m * 0.8, def.visual_height_m * 1.2)
		assert_float(bb.position.y).is_greater_equal(-0.1)
		var radius: float = LookActorsKit.footprint_radius(ActorMeshes.enemy_look(def.visual_id, STYLED))
		# the sim footprint does not change: the styled mesh reaches no farther from its centre than the old one did
		assert_float(radius).is_less_equal(LookActorsKit.footprint_radius(ActorMeshes.enemy(def.visual_id)) * 1.02)


func test_the_silhouettes_stay_different_and_the_hulk_is_the_heaviest() -> void:
	var skitter: AABB = ActorMeshes.enemy_look(&"skitter", STYLED).get_aabb()
	var hollow: AABB = ActorMeshes.enemy_look(&"hollow_warden", STYLED).get_aabb()
	var rusher: AABB = ActorMeshes.enemy_look(&"rusher", STYLED).get_aabb()
	var hulk: AABB = ActorMeshes.enemy_look(&"siege_hulk", STYLED).get_aabb()
	assert_float(hollow.size.y / skitter.size.y).is_greater_equal(1.6)
	assert_float(hulk.size.x * hulk.size.z / (hollow.size.x * hollow.size.z)).is_greater_equal(4.0)
	assert_int(_tris(ActorMeshes.enemy_look(&"siege_hulk", STYLED))).is_greater(_tris(ActorMeshes.enemy_look(&"hollow_warden", STYLED)) * 2)
	assert_float(rusher.size.y).is_less(hollow.size.y)
	var shapes: Array[Vector3] = [skitter.size, hollow.size, rusher.size, hulk.size]
	for i: int in shapes.size():
		for j: int in range(i + 1, shapes.size()):
			assert_float(shapes[i].distance_to(shapes[j])).is_greater(0.2)


func test_the_styled_turret_keeps_its_frames_so_the_shots_leave_from_the_same_place() -> void:
	var base: AABB = ActorMeshes.turret_part(&"base", STYLED).get_aabb()
	var head: AABB = ActorMeshes.turret_part(&"head", STYLED).get_aabb()
	assert_float(base.position.y).is_between(-0.02, 0.06)
	assert_float(maxf(absf(base.position.x), base.end.x)).is_less_equal(0.62)
	assert_float(head.position.z).is_between(HeroMeshes.TURRET_MUZZLE.z - 0.08, HeroMeshes.TURRET_MUZZLE.z + 0.08)
	assert_float(base.end.y + HeroMeshes.TURRET_HEAD_Y * 0.0).is_between(0.45, 0.8)


func _expect_pin(key: String, m: ArrayMesh) -> void:
	var want: Array = CURRENT_PINS[key]
	assert_int(_tris(m)).is_equal(want[0])
	assert_int(LookDevTestKit.mesh_hash(m)).is_equal(want[1])
	for s: int in m.get_surface_count():
		var arrays: Array = m.surface_get_arrays(s)
		assert_bool(arrays[Mesh.ARRAY_COLOR] == null).is_true()
