extends GdUnitTestSuite
## V2-F models (VARIETY_SPEC 5.1, 3.5, 12.2): the burster, the mote, the arc projector and the crate. Triangle budgets, at most 3 surfaces,
## palette roles only, ONE red optic material surface per enemy mesh (and one optic cluster: never a pair), the burster's striped tank
## wider than its body, the mote small enough to be a grain, the arc projector cyan and never red, the Warden loadout budget, determinism.

const STYLED: int = LookDevStyle.Look.STYLISED
const CURRENT: int = LookDevStyle.Look.CURRENT
const NEW_ENEMIES: Array[StringName] = [&"burster", &"mote"]


func before_test() -> void:
	MatLib.configure(TestContent.variety().tokens)
	LookActorsStyle.rollout_override = -1


func after_test() -> void:
	LookActorsStyle.rollout_override = -1


func _tris(m: ArrayMesh) -> int:
	return ActorMeshes.triangle_count(m)


func test_the_new_models_fit_their_triangle_budgets() -> void:
	for id: StringName in NEW_ENEMIES:
		var styled: int = _tris(ActorMeshes.enemy_look(id, STYLED))
		var flat: int = _tris(ActorMeshes.enemy_look(id, CURRENT))
		print("ACTOR_TRIS %s=%d (budget %d, CURRENT %d)" % [id, styled, ActorMeshes.TRI_BUDGET[id], flat])
		assert_int(styled).is_between(30, ActorMeshes.TRI_BUDGET[id])
		assert_int(flat).is_between(10, ActorMeshes.TRI_BUDGET[id])
	var arc: int = _tris(ActorMeshes.new_weapon(&"arc_projector"))
	var crate: int = _tris(ActorMeshes.crate())
	print("ACTOR_TRIS arc_projector=%d (budget %d) crate=%d (budget %d)" % [arc, ActorMeshes.TRI_BUDGET[&"arc_projector"], crate, ActorMeshes.TRI_BUDGET[&"crate"]])
	assert_int(arc).is_between(200, ActorMeshes.TRI_BUDGET[&"arc_projector"])
	assert_int(crate).is_between(100, ActorMeshes.TRI_BUDGET[&"crate"])
	assert_int(ActorMeshes.TRI_BUDGET[&"burster"]).is_equal(400)  # SPEC 12.2: the budgets are the contract
	assert_int(ActorMeshes.TRI_BUDGET[&"mote"]).is_equal(40)


func test_every_new_mesh_has_at_most_three_surfaces_and_only_palette_roles() -> void:
	var enemy_roles: Array[StringName] = [&"gunmetal", &"ceramic", &"emit_red"]
	for look: int in [STYLED, CURRENT]:
		for id: StringName in NEW_ENEMIES:
			var m: ArrayMesh = ActorMeshes.enemy_look(id, look)
			assert_int(m.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
			for role: StringName in VarietyFKit.roles(m):
				var ok: bool = enemy_roles.has(role) or (look == CURRENT and role == &"hazard")
				assert_bool(ok).override_failure_message("%s %d uses %s" % [id, look, role]).is_true()
	var weapon: ArrayMesh = ActorMeshes.new_weapon(&"arc_projector")
	assert_int(weapon.get_surface_count()).is_between(1, ActorMeshes.MAX_SURFACES)
	for role: StringName in VarietyFKit.roles(weapon):
		assert_bool([&"gunmetal", &"ceramic", &"emit_cyan"].has(role)).is_true()
	for role: StringName in VarietyFKit.roles(ActorMeshes.crate()):
		assert_bool([&"gunmetal", &"ceramic", &"emit_cyan"].has(role)).is_true()


func test_every_enemy_mesh_has_one_optic_surface_and_one_red_cluster_never_a_pair() -> void:
	for look: int in [STYLED, CURRENT]:
		for id: StringName in NEW_ENEMIES:
			var m: ArrayMesh = ActorMeshes.enemy_look(id, look)
			assert_int(VarietyFKit.surfaces_with(m, &"emit_red")).is_equal(1)
			assert_bool(VarietyFKit.roles(m).has(&"emit_cyan")).is_false()
	for id: StringName in NEW_ENEMIES:
		var clusters: Array[Dictionary] = LookActorsTestKit.red_clusters(ActorMeshes.enemy_look(id, STYLED))
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
		assert_int(clusters.size()).is_between(1, 2)  # the optic and its halo band may be two welded pieces; never more


func test_the_burster_carries_a_striped_tank_wider_than_its_body() -> void:
	var m: ArrayMesh = ActorMeshes.enemy_look(&"burster", STYLED)
	var ceramic: int = LookActorsTestKit.surface_of(m, &"ceramic")
	var cols: PackedColorArray = m.surface_get_arrays(ceramic)[Mesh.ARRAY_COLOR]
	var amber: int = 0
	var dark: int = 0
	for c: Color in cols:
		if c.r > 0.55 and c.b < 0.4 * c.r:
			amber += 1
		elif c.r < 0.12 and c.g < 0.12 and c.b < 0.12:
			dark += 1
	print("BURSTER stripes amber=%d dark=%d of %d" % [amber, dark, cols.size()])
	assert_int(amber).is_greater(30)  # the hazard stripes: warm amber and near black wedges in the vertex colours
	assert_int(dark).is_greater(30)
	var bb: AABB = m.get_aabb()
	assert_float(bb.size.y).is_between(1.35, 1.65)
	var tank_width: float = LookActorsBurster.TANK_R * 2.0
	assert_float(tank_width).is_greater(0.6)
	assert_float(bb.size.x).is_between(tank_width, 1.1)  # the widest part is the tank (a little more with the shoulder domes)
	var body: AABB = ActorMeshes.enemy_look(&"hollow_warden", STYLED).get_aabb()
	assert_float(bb.size.y).is_less(body.size.y)  # a hunched machine, lower than the Hollow Warden
	assert_float(bb.position.y).is_greater_equal(-0.05)
	var radius: float = LookActorsKit.footprint_radius(m)
	assert_float(radius).is_less_equal(TestContent.variety().enemies[Ids.EN_BURSTER].radius * 1.6)


func test_the_mote_is_a_grain_about_a_third_of_a_skitter() -> void:
	var mote: AABB = ActorMeshes.enemy_look(&"mote", STYLED).get_aabb()
	var skitter: AABB = ActorMeshes.enemy_look(&"skitter", STYLED).get_aabb()
	assert_float(mote.size.y).is_between(0.3, 0.45)
	assert_float(mote.size.y / skitter.size.y).is_between(0.3, 0.6)
	assert_float(mote.position.y).is_between(-0.02, 0.05)  # it stands on the ground
	assert_float(mote.size.x).is_less(0.5)
	var burster: AABB = ActorMeshes.enemy_look(&"burster", STYLED).get_aabb()
	assert_float(burster.size.y / mote.size.y).is_greater(3.0)  # size classes are far apart (SPEC 5.6 rule 5)


func test_the_arc_projector_is_cyan_never_red_and_has_a_muzzle_in_front() -> void:
	var m: ArrayMesh = ActorMeshes.new_weapon(&"arc_projector")
	var roles: Array[StringName] = VarietyFKit.roles(m)
	assert_bool(roles.has(&"emit_cyan")).is_true()
	assert_bool(roles.has(&"emit_red")).is_false()
	assert_bool(roles.has(&"steel_red")).is_false()
	var bb: AABB = m.get_aabb()
	assert_float(bb.size.z).is_between(0.6, 0.95)  # longer than the pistol, a little longer than the SMG
	assert_float(bb.position.z).is_less(WeaponMeshes.ARC_MUZZLE.z + 0.06)  # the prongs reach the muzzle point the shots leave from
	assert_float(WeaponMeshes.ARC_MUZZLE.z).is_less(HeroMeshes.SMG_MUZZLE.z)  # a longer arm than the SMG
	var smg: AABB = ActorMeshes.smg().get_aabb()
	assert_float(bb.size.z).is_greater(smg.size.z * 0.9)


func test_the_warden_loadout_with_the_arc_projector_fits_the_loadout_budget() -> void:
	for look: int in [STYLED, LookDevStyle.Look.STYLISED_PLUS]:
		var body: int = ActorMeshes.warden_triangles(look, 0) - _tris(ActorMeshes.warden_part(&"pistol", look))
		var total: int = body + _tris(ActorMeshes.new_weapon(&"arc_projector"))
		print("WARDEN_TRIS look=%s body=%d with_arc=%d (loadout budget %d)" % [LookDevStyle.name_of(look), body, total, ActorMeshes.WARDEN_LOADOUT_BUDGET])
		assert_int(total).is_less_equal(ActorMeshes.WARDEN_LOADOUT_BUDGET)  # body about 2,300 plus a weapon of at most 350
		assert_int(body + ActorMeshes.TRI_BUDGET[&"arc_projector"]).is_less_equal(ActorMeshes.WARDEN_LOADOUT_BUDGET + 20)
	assert_int(ActorMeshes.TRI_BUDGET[&"warden"]).is_equal(2500)  # the pistol and SMG loadouts keep the old budget


func test_the_new_meshes_are_deterministic_cached_and_apart_from_current() -> void:
	var builds: Array[Callable] = [LookActorsBurster.build, LookActorsMote.build, WeaponMeshes.arc_projector, CrateView.mesh]
	for b: Callable in builds:
		var one: ArrayMesh = b.call()
		var two: ArrayMesh = b.call()
		assert_int(LookDevTestKit.mesh_hash(one)).is_equal(LookDevTestKit.mesh_hash(two))
	for id: StringName in NEW_ENEMIES:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy_look(id, STYLED))
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_not_same(ActorMeshes.enemy(id))
		assert_object(ActorMeshes.enemy_look(id, CURRENT)).is_same(ActorMeshes.enemy(id))
	assert_object(ActorMeshes.new_weapon(&"arc_projector")).is_same(ActorMeshes.warden_part(&"arc_projector", CURRENT))
	assert_object(ActorMeshes.new_weapon(&"pistol")).is_null()
	assert_object(ActorMeshes.warden_part(&"arc_projector", STYLED)).is_not_null()


func test_a_switched_off_rollout_keeps_the_new_enemies_in_current() -> void:
	LookActorsStyle.rollout_override = 0
	for id: StringName in NEW_ENEMIES:
		assert_object(ActorMeshes.enemy_look(id, STYLED)).is_same(ActorMeshes.enemy(id))
	assert_object(ActorMeshes.mini_look(&"mote", STYLED)).is_same(ActorMeshes.enemy(&"mote"))


func test_vertex_colours_are_in_range_and_the_styled_burster_is_weathered() -> void:
	for m: ArrayMesh in [ActorMeshes.enemy_look(&"burster", STYLED), ActorMeshes.enemy_look(&"mote", STYLED), ActorMeshes.new_weapon(&"arc_projector"), ActorMeshes.crate()]:
		for s: int in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			assert_int(cols.size()).is_equal(verts.size())
			for c: Color in cols:
				assert_float(minf(c.r, minf(c.g, minf(c.b, c.a)))).is_greater_equal(0.0)
				assert_float(maxf(c.r, maxf(c.g, maxf(c.b, c.a)))).is_less_equal(1.0)
	var burster: ArrayMesh = ActorMeshes.enemy_look(&"burster", STYLED)
	var stats: Dictionary = LookActorsTestKit.luma_stats(burster, LookActorsTestKit.surface_of(burster, &"gunmetal"))
	var lo: float = stats["min"]
	var hi: float = stats["max"]
	assert_float(lo).is_less(hi * 0.8)  # creases and grime: the frame is not one flat value


func test_the_one_time_build_cost_is_reported_and_bounded() -> void:
	var names: Array[String] = ["burster", "mote", "arc_projector", "crate"]
	var builds: Array[Callable] = [LookActorsBurster.build, LookActorsMote.build, WeaponMeshes.arc_projector, CrateView.mesh]
	var total_ms: float = 0.0
	for i: int in builds.size():
		var started: int = Time.get_ticks_usec()
		var _m: ArrayMesh = builds[i].call()
		var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		total_ms += ms
		print("ACTOR_BUILD_MS %s=%.1f" % [names[i], ms])
	print("ACTOR_BUILD_MS variety total=%.1f" % total_ms)
	assert_float(total_ms).is_less(1500.0)  # one time, at boot behind the warm-up
