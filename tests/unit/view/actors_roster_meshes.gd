extends GdUnitTestSuite
## V4-R models: the eleven new enemies and the four new bosses (VARIETY_SPEC 5.1, 6, 12.2) and the seven new weapons (3.5). Budgets,
## surfaces, palette roles, ONE red optic per mesh and no other glow on a machine, one cyan accent and never red on a weapon, heights
## that follow the content, vertex colours in range and weathered, determinism, one geometry for every look and the one-time build cost.

const STYLED: int = LookDevStyle.Look.STYLISED
const CURRENT: int = LookDevStyle.Look.CURRENT
const ENEMY_ROLES: Array[StringName] = [&"gunmetal", &"ceramic", &"emit_red"]
const WEAPON_ROLES: Array[StringName] = [&"gunmetal", &"ceramic", &"emit_cyan"]
const BOSSES: Array[StringName] = [&"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig"]
const BODIES: Array[StringName] = [&"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"borer", &"ward_pylon"]
const WEAPONS: Array[StringName] = [
	&"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"rail_lance",
]


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookActorsStyle.rollout_override = -1


func after_test() -> void:
	LookActorsStyle.rollout_override = -1


func _tris(m: ArrayMesh) -> int:
	return ActorMeshes.triangle_count(m)


func test_every_new_model_fits_its_triangle_budget_and_is_not_trivial() -> void:
	for id: StringName in ActorMeshes.ROSTER:
		var n: int = _tris(ActorMeshes.enemy_look(id, STYLED))
		var budget: int = ActorMeshes.TRI_BUDGET[id]
		print("ACTOR_TRIS %s=%d (budget %d)" % [id, n, budget])
		assert_int(n).is_less_equal(budget)
		assert_int(n).is_greater_equal(int(float(budget) * 0.2))  # a real model, not a placeholder box
	for id: StringName in WEAPONS:
		var n2: int = _tris(ActorMeshes.new_weapon(id))
		print("ACTOR_TRIS %s=%d (budget %d)" % [id, n2, ActorMeshes.TRI_BUDGET[id]])
		assert_int(n2).is_between(150, ActorMeshes.TRI_BUDGET[id])
	assert_int(ActorMeshes.TRI_BUDGET[&"spitter"]).is_equal(400)  # SPEC 12.2: the budgets are the contract
	assert_int(ActorMeshes.TRI_BUDGET[&"borer"]).is_equal(400)
	assert_int(ActorMeshes.TRI_BUDGET[&"jammer"]).is_equal(400)
	assert_int(ActorMeshes.TRI_BUDGET[&"splitter"]).is_equal(500)
	assert_int(ActorMeshes.TRI_BUDGET[&"shieldbearer"]).is_equal(500)
	assert_int(ActorMeshes.TRI_BUDGET[&"reclaimer"]).is_equal(500)
	assert_int(ActorMeshes.TRI_BUDGET[&"shard"]).is_equal(40)
	assert_int(ActorMeshes.TRI_BUDGET[&"ward_pylon"]).is_equal(150)
	assert_int(ActorMeshes.TRI_BUDGET[&"scattergun"]).is_equal(350)
	for id: StringName in BOSSES:  # fixed with this task: the Hulk's budget, one pooled node each
		assert_int(ActorMeshes.TRI_BUDGET[id]).is_equal(ActorMeshes.TRI_BUDGET[&"siege_hulk"])
		assert_int(_tris(ActorMeshes.enemy_look(id, STYLED))).is_greater_equal(600)


func test_the_roster_lists_every_machine_of_this_task_and_every_id_has_a_model_of_its_own() -> void:
	assert_int(ActorMeshes.ROSTER.size()).is_equal(12)
	for id: StringName in ActorMeshes.ROSTER:
		assert_int(Ids.enemy_index(id)).is_greater_equal(0)
		assert_bool(ActorMeshes.TRI_BUDGET.has(id)).is_true()
	for id: StringName in [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk", &"mote", &"burster"]:
		assert_bool(ActorMeshes.ROSTER.has(id)).is_false()  # the older models keep their own builders
	for id: StringName in Ids.ENEMIES:  # no id falls back to the skitter
		if id == &"skitter":
			continue
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_not_same(ActorMeshes.enemy_look(&"skitter", STYLED))


func test_every_new_enemy_has_at_most_three_surfaces_and_only_palette_roles() -> void:
	for look: int in [STYLED, CURRENT]:
		for id: StringName in ActorMeshes.ROSTER:
			var m: ArrayMesh = ActorMeshes.enemy_look(id, look)
			assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
			for role: StringName in VarietyFKit.roles(m):
				assert_bool(ENEMY_ROLES.has(role)).override_failure_message("%s uses %s" % [id, role]).is_true()
	var shard: Array[StringName] = VarietyFKit.roles(ActorMeshes.enemy_look(&"shard", STYLED))  # the mini: ceramic and the optic only
	assert_int(shard.size()).is_equal(2)
	assert_bool(shard.has(&"ceramic") and shard.has(&"emit_red")).is_true()
	for id: StringName in WEAPONS:
		var w: ArrayMesh = ActorMeshes.new_weapon(id)
		assert_int(w.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
		for role: StringName in VarietyFKit.roles(w):
			assert_bool(WEAPON_ROLES.has(role)).override_failure_message("%s uses %s" % [id, role]).is_true()


func test_every_new_enemy_has_one_optic_surface_and_one_bright_red_cluster_never_a_pair() -> void:
	for id: StringName in ActorMeshes.ROSTER:
		var m: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
		assert_int(VarietyFKit.surfaces_with(m, &"emit_red")).is_equal(1)
		assert_bool(VarietyFKit.roles(m).has(&"emit_cyan")).is_false()  # nothing else on an enemy glows
		var clusters: Array[Dictionary] = LookActorsTestKit.red_clusters(m)
		var bright: int = 0
		for c: Dictionary in clusters:
			var tint: float = c["tint"]
			if tint >= 0.95:
				bright += 1
			var at: Vector3 = c["center"]
			for d: Dictionary in clusters:
				var other: Vector3 = d["center"]
				if absf(at.x) > 0.05:  # no second eye: no red piece has a mirror image across the body axis
					assert_float(at.distance_to(Vector3(-other.x, other.y, other.z))).is_greater(0.03)
		print("OPTICS %s clusters=%d bright=%d" % [id, clusters.size(), bright])
		assert_int(bright).is_equal(1)
		assert_int(clusters.size()).is_between(1, 2)  # the optic and its dim halo may be two welded pieces; never more


func test_every_weapon_is_cyan_and_never_red() -> void:
	for id: StringName in WEAPONS:
		var roles: Array[StringName] = VarietyFKit.roles(ActorMeshes.new_weapon(id))
		assert_bool(roles.has(&"emit_cyan")).override_failure_message("%s has no cyan accent" % id).is_true()
		assert_bool(roles.has(&"emit_red")).is_false()
		assert_bool(roles.has(&"steel_red")).is_false()
		assert_bool(roles.has(&"hazard")).is_false()


func test_new_enemy_heights_follow_the_content_and_the_size_classes_are_far_apart() -> void:
	var content: ContentSet = TestContent.variety()
	var heights: Dictionary[StringName, float] = {}
	for id: StringName in Ids.ENEMIES:
		var def: EnemyDef = content.enemies[Ids.enemy_index(id)]
		var bb: AABB = ActorMeshes.enemy_look(id, STYLED).get_aabb()
		heights[id] = bb.size.y
		if ActorMeshes.ROSTER.has(id) and not BOSSES.has(id):
			assert_float(bb.size.y).override_failure_message("%s is %.2f m, the content says %.2f" % [id, bb.size.y, def.visual_height_m]).is_between(
				def.visual_height_m * 0.85, def.visual_height_m * 1.25
			)
		if BOSSES.has(id):
			assert_float(bb.size.y).override_failure_message("%s is %.2f m, the content says %.2f" % [id, bb.size.y, def.visual_height_m]).is_between(
				def.visual_height_m * 0.9, def.visual_height_m * 1.1
			)
		assert_float(bb.position.y).is_between(-0.08, 0.15)  # stands on the ground
	# mini 0.4 m, skitter 0.9, bipeds 1.4 to 1.8, bosses 3 m and more (SPEC 5.6 rule 5)
	for id: StringName in [&"mote", &"shard"]:
		assert_float(heights[id]).is_less(0.5)
	assert_float(heights[&"skitter"]).is_between(0.8, 1.0)
	assert_float(heights[&"borer"]).is_between(0.7, 1.0)
	for id: StringName in [&"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"burster", &"hollow_warden"]:
		assert_float(heights[id]).is_between(1.25, 2.2)
	for id: StringName in BOSSES:
		assert_float(heights[id]).is_greater_equal(2.9)
	assert_float(heights[&"shard"] / heights[&"skitter"]).is_less(0.6)
	assert_float(heights[&"borer"]).is_less(heights[&"splitter"])
	assert_float(heights[&"ward_pylon"]).is_between(1.3, 1.7)


func test_bodied_enemies_keep_a_footprint_the_sim_can_hold() -> void:
	var content: ContentSet = TestContent.variety()
	for id: StringName in BODIES:
		var def: EnemyDef = content.enemies[Ids.enemy_index(id)]
		var radius: float = LookActorsKit.footprint_radius(ActorMeshes.enemy_look(id, STYLED))
		print("FOOTPRINT %s mesh %.2f sim radius %.2f" % [id, radius, def.radius])
		assert_float(radius).is_less_equal(def.radius * 2.0)  # a body reaches no farther than its slot allows
		assert_float(radius).is_greater_equal(def.radius * 0.7)
	for id: StringName in BOSSES:
		var def2: EnemyDef = content.enemies[Ids.enemy_index(id)]
		var radius2: float = LookActorsKit.footprint_radius(ActorMeshes.enemy_look(id, STYLED))
		print("FOOTPRINT %s mesh %.2f sim radius %.2f" % [id, radius2, def2.radius])
		assert_float(radius2).is_greater_equal(def2.radius * 0.9)  # a boss fills its slots


func test_vertex_colours_are_in_range_and_the_machines_are_weathered() -> void:
	var meshes: Array[ArrayMesh] = []
	for id: StringName in ActorMeshes.ROSTER:
		meshes.append(ActorMeshes.enemy_look(id, STYLED))
	for id: StringName in WEAPONS:
		meshes.append(ActorMeshes.new_weapon(id))
	for m: ArrayMesh in meshes:
		for s: int in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			assert_int(cols.size()).is_equal(verts.size())
			for c: Color in cols:
				assert_float(minf(c.r, minf(c.g, minf(c.b, c.a)))).is_greater_equal(0.0)
				assert_float(maxf(c.r, maxf(c.g, maxf(c.b, c.a)))).is_less_equal(1.0)
	for id: StringName in ActorMeshes.ROSTER:
		if id == &"shard":
			continue
		var m2: ArrayMesh = ActorMeshes.enemy_look(id, STYLED)
		var frame: int = LookActorsTestKit.surface_of(m2, &"gunmetal")
		var stats: Dictionary = LookActorsTestKit.luma_stats(m2, frame)
		var lo: float = stats["min"]
		var hi: float = stats["max"]
		assert_float(lo).override_failure_message("%s frame is one flat value" % id).is_less(hi * 0.8)  # creases and grime


func test_one_geometry_serves_every_look_and_a_switched_off_rollout() -> void:
	for id: StringName in ActorMeshes.ROSTER:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy(id))
		assert_object(ActorMeshes.enemy_look(id, CURRENT)).is_same(ActorMeshes.enemy(id))
		assert_object(ActorMeshes.enemy_look(id, LookDevStyle.Look.STYLISED_PLUS)).is_same(ActorMeshes.enemy(id))
	LookActorsStyle.rollout_override = 0
	for id: StringName in ActorMeshes.ROSTER:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy(id))
	for id: StringName in WEAPONS:
		assert_object(ActorMeshes.new_weapon(id)).is_same(ActorMeshes.warden_part(id, CURRENT))
		assert_object(ActorMeshes.new_weapon(id)).is_same(ActorMeshes.warden_part(id, STYLED))
	assert_object(ActorMeshes.new_weapon(&"smg")).is_null()


func test_the_mini_swarm_gets_the_shard_for_the_shard_and_the_mote_otherwise() -> void:
	assert_object(ActorMeshes.mini_look(&"shard", STYLED)).is_same(ActorMeshes.enemy_look(&"shard", STYLED))
	assert_object(ActorMeshes.mini_look(&"mote", STYLED)).is_same(ActorMeshes.enemy_look(&"mote", STYLED))
	assert_object(ActorMeshes.mini_look(&"anything_else", STYLED)).is_same(ActorMeshes.enemy_look(&"mote", STYLED))
	assert_object(ActorMeshes.mini_look(&"shard", STYLED)).is_not_same(ActorMeshes.mini_look(&"mote", STYLED))


func test_the_new_meshes_are_deterministic() -> void:
	var builds: Array[Callable] = [
		LookActorsSpitter.build, LookActorsSplitter.build, LookActorsShard.build, LookActorsShieldbearer.build, LookActorsReclaimer.build,
		LookActorsJammer.build, LookActorsBorer.build, LookActorsPylon.build, LookActorsBrood.build, LookActorsLance.build,
		LookActorsAegis.build, LookActorsTremor.build, WeaponMeshes2.scattergun, WeaponMeshes2.assault_rifle, WeaponMeshes2.hornet_rack,
		WeaponMeshes2.lmg, WeaponMeshes3.slag_mortar, WeaponMeshes3.cutting_torch, WeaponMeshes3.rail_lance,
	]
	for b: Callable in builds:
		var one: ArrayMesh = b.call()
		var two: ArrayMesh = b.call()
		assert_int(LookDevTestKit.mesh_hash(one)).is_equal(LookDevTestKit.mesh_hash(two))
		assert_int(LookDevTestKit.vertex_count(one)).is_equal(LookDevTestKit.vertex_count(two))


func test_the_one_time_build_cost_is_reported_and_bounded() -> void:
	var total_ms: float = 0.0
	for id: StringName in ActorMeshes.ROSTER:
		var started: int = Time.get_ticks_usec()
		var b: Callable = ActorMeshes.roster_builder(id)
		var _m: ArrayMesh = b.call()
		var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		total_ms += ms
		print("ACTOR_BUILD_MS %s=%.1f" % [id, ms])
	for id: StringName in WEAPONS:
		var started2: int = Time.get_ticks_usec()
		var _w: ArrayMesh = ActorMeshes.new_weapon(id)
		total_ms += float(Time.get_ticks_usec() - started2) / 1000.0
	print("ACTOR_BUILD_MS roster total=%.1f" % total_ms)
	assert_float(total_ms).is_less(3000.0)  # one time, at boot behind the warm-up; GDScript on a desktop CPU
