extends GdUnitTestSuite
## V4-W: the scattergun (firing kind C, VARIETY_SPEC 3.3). 10 damage a pellet, 8 pellets (12 at level 3), 1.2 shots a
## second (a shot every 50 ticks), 6 shells, a 144-tick reload, range 9 m, a 30 degree cone, knockback 0.8 m on enemies of
## mass below 3. Skitter: 45 hp, armor 0, mass 0.5, radius 0.35; Hollow Warden: armor 8, mass 3.0; Rusher: mass 1.0.
## Positions are relative to the Warden; the aim line is the +x axis (the target stands at z = 0).


func _gun(level: int = 1) -> SimWorld:
	return ArsenalWKit.world(Ids.WP_SCATTERGUN, level)


func _shoot(w: SimWorld) -> void:
	VarietyCKit.run_weapon(w, 50)
	assert_int(w.warden.shots_fired).is_equal(1)


func test_the_pellets_go_to_the_enemies_in_the_cone_nearest_first() -> void:
	var w: SimWorld = _gun()
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 8.0, 0.0, true)
	var b: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 0.8)  # 9.1 degrees: inside
	var c: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 3.0, -0.7)  # 13.1 degrees: inside, the nearest
	var wide: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 3.0)  # 26.6 degrees: outside
	var far: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 9.5, 0.0)  # beyond 9 m
	var behind: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, -2.0, 0.0)
	_shoot(w)
	assert_float(VarietyCKit.taken(w, c)).is_equal(30.0)  # 3 pellets
	assert_float(VarietyCKit.taken(w, b)).is_equal(30.0)  # 3 pellets
	assert_float(VarietyCKit.taken(w, t)).is_equal(20.0)  # the last 2
	for i: int in [wide, far, behind]:
		assert_float(VarietyCKit.taken(w, i)).is_equal(0.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHOT_FIRED)).is_equal(1)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.ENEMY_DAMAGED)).is_equal(8)


func test_an_enemy_whose_body_touches_the_cone_is_inside_it() -> void:
	var w: SimWorld = _gun()
	var def: WeaponDef = w.content.weapons[Ids.WP_SCATTERGUN]
	var inside: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 1.9)  # centre at 17.6 degrees, body reaches 14.4
	var outside: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 2.3)  # centre at 21.0, body reaches 17.9
	var members: PackedInt32Array = FireCone.members_in_cone(w, w.warden.x, w.warden.z, w.warden.x + 8.0, w.warden.z, def)
	assert_bool(members.has(inside)).is_true()
	assert_bool(members.has(outside)).is_false()


func test_equal_distances_go_to_the_lower_id_first_and_the_cap_is_three() -> void:
	var w: SimWorld = _gun()
	var near: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 4.0, 0.0, true)  # id 1
	var upper: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 1.0)  # id 2, 5.099 m
	var lower: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, -1.0)  # id 3, the same distance
	var last: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.0)  # id 4
	_shoot(w)
	assert_float(VarietyCKit.taken(w, near)).is_equal(30.0)
	assert_float(VarietyCKit.taken(w, upper)).is_equal(30.0)
	assert_float(VarietyCKit.taken(w, lower)).is_equal(20.0)  # only 2 pellets are left for the later id
	assert_float(VarietyCKit.taken(w, last)).is_equal(0.0)


func test_the_deal_gives_three_each_while_targets_remain_and_the_rest_to_the_nearest() -> void:
	assert_array(Array(FireCone.deal(1, 8))).is_equal([8])
	assert_array(Array(FireCone.deal(2, 8))).is_equal([5, 3])
	assert_array(Array(FireCone.deal(3, 8))).is_equal([3, 3, 2])
	assert_array(Array(FireCone.deal(4, 8))).is_equal([3, 3, 2, 0])
	assert_array(Array(FireCone.deal(3, 12))).is_equal([6, 3, 3])
	assert_array(Array(FireCone.deal(4, 12))).is_equal([3, 3, 3, 3])
	assert_array(Array(FireCone.deal(0, 8))).is_empty()


func test_a_lone_enemy_takes_every_pellet() -> void:
	var w: SimWorld = _gun()
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 6.0, 0.0, true)
	_shoot(w)
	assert_float(VarietyCKit.taken(w, t)).is_equal(80.0)


func test_level_two_scales_the_pellets_and_level_three_adds_four_more() -> void:
	var two: SimWorld = _gun(2)
	var a: int = ArsenalWKit.foe(two, Ids.EN_SKITTER, 6.0, 0.0, true)
	_shoot(two)
	assert_float(VarietyCKit.taken(two, a)).is_equal_approx(8.0 * 12.5, 1e-5)
	var three: SimWorld = _gun(3)
	var t: int = ArsenalWKit.foe(three, Ids.EN_SKITTER, 8.0, 0.0, true)
	var b: int = ArsenalWKit.foe(three, Ids.EN_SKITTER, 5.0, 0.8)
	var c: int = ArsenalWKit.foe(three, Ids.EN_SKITTER, 3.0, -0.7)
	_shoot(three)
	assert_float(VarietyCKit.taken(three, c)).is_equal_approx(6.0 * 15.5, 1e-4)  # 12 pellets: 6, 3, 3
	assert_float(VarietyCKit.taken(three, b)).is_equal_approx(3.0 * 15.5, 1e-4)
	assert_float(VarietyCKit.taken(three, t)).is_equal_approx(3.0 * 15.5, 1e-4)
	assert_int(VarietyCKit.count(three, SimEventKind.Id.ENEMY_DAMAGED)).is_equal(12)


func test_each_pellet_meets_the_armor_on_its_own() -> void:
	var w: SimWorld = _gun()
	var hollow: int = ArsenalWKit.foe(w, Ids.EN_HOLLOW, 6.0, 0.0, true)
	_shoot(w)
	assert_float(VarietyCKit.taken(w, hollow)).is_equal(8.0 * 2.0)  # 10 - 8 a pellet


func test_cadence_magazine_and_reload() -> void:
	var w: SimWorld = _gun()
	ArsenalWKit.foe(w, Ids.EN_HULK, 6.0, 0.0, true)
	var ticks: Array[int] = VarietyCKit.shot_ticks(w, 450)
	assert_array(ticks).is_equal([50, 100, 150, 200, 250, 300, 444])
	assert_int(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_STARTED)[0]).is_equal(300)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.RELOAD_STARTED)[0].a).is_equal(144)
	assert_int(VarietyCKit.ticks_of(w, SimEventKind.Id.RELOAD_FINISHED)[0]).is_equal(444)


func test_it_is_silent_beyond_nine_metres() -> void:
	var w: SimWorld = _gun()
	var t: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 10.0, 0.0, true)
	VarietyCKit.run_weapon(w, 200)
	assert_int(w.warden.shots_fired).is_equal(0)
	assert_int(w.warden.target_id).is_equal(0)
	w.enemies.x[t] = w.warden.x + 8.9
	VarietyCKit.run_weapon(w, 1)
	assert_int(w.warden.shots_fired).is_equal(1)  # the banked shot leaves at once


func test_light_enemies_are_shoved_along_the_line_from_the_warden() -> void:
	var w: SimWorld = _gun()
	var light: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 0.0, true)
	var rusher: int = ArsenalWKit.foe(w, Ids.EN_RUSHER, 4.0, 1.0)  # mass 1.0, 4.12 m away
	var hollow: int = ArsenalWKit.foe(w, Ids.EN_HOLLOW, 6.0, 0.5)  # mass 3.0: too heavy
	var rusher_x: float = w.enemies.x[rusher]
	var rusher_z: float = w.enemies.z[rusher]
	var hollow_x: float = w.enemies.x[hollow]
	var hollow_z: float = w.enemies.z[hollow]
	_shoot(w)
	assert_float(w.enemies.x[light]).is_equal_approx(w.warden.x + 5.8, 1e-5)
	assert_float(w.enemies.z[light]).is_equal_approx(w.warden.z, 1e-5)
	var away: Vector2 = Vector2(4.0, 1.0).normalized() * 0.8
	assert_float(w.enemies.x[rusher]).is_equal_approx(rusher_x + away.x, 1e-5)
	assert_float(w.enemies.z[rusher]).is_equal_approx(rusher_z + away.y, 1e-5)
	assert_float(w.enemies.x[hollow]).is_equal(hollow_x)
	assert_float(w.enemies.z[hollow]).is_equal(hollow_z)


func test_an_enemy_the_shot_killed_is_not_shoved_and_no_one_else_moves() -> void:
	var w: SimWorld = _gun()
	var weak: int = VarietyCKit.place_rel(w, Ids.EN_SKITTER, 5.0, 0.0)
	w.enemies.path_dist[weak] = 1.0
	var bystander: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 3.0, -9.0)  # far outside the cone
	var before: float = w.enemies.x[bystander]
	_shoot(w)
	assert_int(w.enemies.alive[weak]).is_equal(0)
	assert_float(w.enemies.x[bystander]).is_equal(before)


func test_a_shove_stops_at_the_edge_of_the_yard() -> void:
	var w: SimWorld = _gun()
	# 4 m toward +z and 2 m toward +x: the radial direction is (0.447, 0.894); the yard ends at z = 12, less the radius 0.35
	var edge: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 2.0, 4.0, true)
	var z0: float = w.enemies.z[edge]
	_shoot(w)
	var moved: float = (w.enemies.z[edge] - z0) / 0.894427191
	assert_float(moved).is_equal_approx(0.7, 1e-5)
	assert_float(w.enemies.z[edge]).is_less_equal(w.content.arena.max_z - 0.35)


func test_a_shove_stops_before_the_core_cage() -> void:
	var w: SimWorld = _gun()
	# toward the core (-7.5, 3.0, radius 2.0): a skitter 0.2 m outside the cage is shoved no further than the cage allows
	var near_core: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, -1.8, -1.5, true)
	var core: ArenaDef = w.content.arena
	var x0: float = w.enemies.x[near_core]
	var z0: float = w.enemies.z[near_core]
	_shoot(w)
	var moved: float = Vector2(w.enemies.x[near_core] - x0, w.enemies.z[near_core] - z0).length()
	var gap: float = Vector2(w.enemies.x[near_core] - core.core_x, w.enemies.z[near_core] - core.core_z).length()
	assert_float(moved).is_greater(0.0)
	assert_float(moved).is_less(0.8)
	assert_float(gap).is_greater_equal(core.core_radius + 0.35 - 1e-9)


func test_a_shove_stops_at_a_prop() -> void:
	var w: SimWorld = _gun()
	# the crate stack (4.5, 0.5, radius 1.3) is 11 m from the Warden; put a copy of it 6 m ahead for the test
	var prop: ObstacleDef = ObstacleDef.new()
	prop.shape = ObstacleDef.Shape.CIRCLE
	prop.x = w.warden.x + 6.9
	prop.z = w.warden.z
	prop.radius = 0.5
	w.content.arena.obstacles.append(prop)
	var light: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.5, 0.0, true)  # 0.9 m from the prop's face, body 0.35
	_shoot(w)
	# the body may travel until its edge touches the prop: 6.9 - 0.5 - 0.35 = 6.05 m from the Warden
	assert_float(w.enemies.x[light]).is_less_equal(w.warden.x + 6.05 + 1e-9)
	assert_float(w.enemies.x[light]).is_greater(w.warden.x + 5.9)  # it did move, 0.5 m


func test_attackers_heavy_and_anchored_enemies_stay_put() -> void:
	var w: SimWorld = _gun()
	var content: ContentSet = w.content
	var anchored_def: AffixDef = AffixDef.new()
	anchored_def.id = &"anchored"
	anchored_def.index = content.affixes.size()
	content.affixes.append(anchored_def)
	var attacker: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 0.0)
	w.enemies.state[attacker] = EnemyStore.ST_ATTACKING
	var anchored: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, 1.0)
	w.ext.affix_mask[anchored] = 1 << anchored_def.index
	var hulk: int = ArsenalWKit.foe(w, Ids.EN_HULK, 7.0, 0.0)
	var free: int = ArsenalWKit.foe(w, Ids.EN_SKITTER, 5.0, -1.0)
	var starts: Array[float] = [w.enemies.x[attacker], w.enemies.x[anchored], w.enemies.x[hulk], w.enemies.x[free]]
	for i: int in [attacker, anchored, hulk, free]:
		FireCone.shove(w, i, w.warden.x, w.warden.z, 0.8)
	assert_float(w.enemies.x[attacker]).is_equal(starts[0])
	assert_float(w.enemies.x[anchored]).is_equal(starts[1])
	assert_float(w.enemies.x[hulk]).is_equal(starts[2])
	assert_float(w.enemies.x[free]).is_greater(starts[3])
