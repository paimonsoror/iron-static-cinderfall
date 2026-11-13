extends GdUnitTestSuite
## V4-V: FUEL DRUMS (CONTENT 6 "Hazard", VARIETY_SPEC 7.1): three per act on three of six fixed points; any blast, pool,
## strike or freight car lights one, as do 80 points of stray damage; 3 m blast, 150 damage to enemies, then a 5 s slag pool;
## drums chain with each other and with bursters; they hurt enemies only.

const DRUM_FUSE: int = 6


func _world() -> SimWorld:
	return VarietyVKit.world(1, 1)  # wave 1 is the start of act I: the drums are laid


## Two drums at known places (the arena's six points are 7 m or more apart): replaces the plan's drums.
func _drums_at(w: SimWorld, points: Array[Vector2]) -> void:
	var h: HazardState = w.hazards
	h.d_point = PackedInt32Array()
	h.d_alive = PackedInt32Array()
	h.d_damage_milli = PackedInt32Array()
	for p: Vector2 in points:
		w.content.arena.drum_points.append(p)
		h.d_point.append(w.content.arena.drum_points.size() - 1)
		h.d_alive.append(1)
		h.d_damage_milli.append(0)


func _blast_ticks(w: SimWorld, kind: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST):
		if e.a == kind:
			out.append(e.tick)
	return out


# --- placement ---


func test_three_drums_stand_on_the_planned_points_when_the_act_starts() -> void:
	var w: SimWorld = _world()
	assert_int(w.hazards.d_alive.size()).is_equal(3)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	for k: int in 3:
		assert_int(w.hazards.d_point[k]).is_equal(w.plan.drum_points[k])
		assert_int(w.hazards.d_damage_milli[k]).is_equal(0)
		assert_bool(w.content.arena.drum_points.size() > w.hazards.d_point[k]).is_true()


func test_the_next_act_replaces_the_drums_with_its_own_three() -> void:
	var w: SimWorld = _world()
	assert_int(w.plan.drum_points.size()).is_greater_equal(6)
	HazardDrums.ignite(w, 0)  # one is gone already
	w.plan.waves[3].act = 2
	VarietyVKit.begin_wave(w, 4)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	for k: int in 3:
		assert_int(w.hazards.d_point[k]).is_equal(w.plan.drum_points[3 + k])


func test_a_wave_that_is_not_an_act_start_leaves_the_drums_as_they_are() -> void:
	var w: SimWorld = _world()
	HazardDrums.ignite(w, 1)
	VarietyVKit.begin_wave(w, 2)
	assert_int(HazardDrums.alive_count(w)).is_equal(2)


func test_the_drum_points_come_from_the_seed() -> void:
	var seen: Dictionary[String, bool] = {}
	for s: int in range(1, 20):
		var w: SimWorld = VarietyVKit.world(s, 1)
		seen[",".join(Array(w.hazards.d_point).map(func(p: int) -> String: return str(p)))] = true
	assert_int(seen.size()).is_greater(3)


# --- ignition ---


func test_a_blast_that_touches_a_drum_lights_it_and_the_drum_blasts_six_ticks_later() -> void:
	var w: SimWorld = _world()
	var p: Vector2 = HazardDrums.position_of(w, 0)
	var near: int = VarietyVKit.place(w, Ids.EN_HOLLOW, p.x + 2.9, p.y)  # inside 3 m
	var edge: int = VarietyVKit.place(w, Ids.EN_HOLLOW, p.x, p.y + 3.2)  # outside
	VarietyVKit.tough(w, near)
	VarietyVKit.tough(w, edge)
	var _seq: int = HazardSystem.queue_blast(
		w, 1, HazardState.K_BLAST, p.x + 1.0, p.y, 0.7, 1.0, 1.0, DamageResolver.F_AREA, DamageSource.Id.HAZARD, 0.0, -1
	)  # 0.7 + the drum's own 0.4 reach it from 1.0 m
	VarietyVKit.tick(w)  # tick 1: the small blast lands
	assert_int(HazardDrums.alive_count(w)).is_equal(2)
	var launched: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)
	assert_int(launched.size()).is_equal(1)
	assert_int(launched[0].a).is_equal(HazardState.K_DRUM)
	assert_int(launched[0].b).is_equal(DRUM_FUSE)
	VarietyVKit.run(w, DRUM_FUSE - 1)  # tick 6
	assert_float(VarietyVKit.taken(w, near)).is_equal(1.0)
	VarietyVKit.tick(w)  # tick 7 = 1 + 6
	assert_array(_blast_ticks(w, HazardState.K_DRUM)).is_equal([1 + DRUM_FUSE])
	assert_float(VarietyVKit.taken(w, near)).is_equal(1.0 + 150.0)  # the full 150: no falloff, armor ignored
	assert_float(VarietyVKit.taken(w, edge)).is_equal(0.0)
	assert_int(VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST)[1].b).is_equal(300)
	assert_float(w.combat.damage_by_source[DamageSource.Id.HAZARD]).is_equal(1.0 + 150.0)


func test_the_blast_leaves_a_slag_pool_of_five_seconds() -> void:
	var w: SimWorld = _world()
	var p: Vector2 = HazardDrums.position_of(w, 0)
	var victim: int = VarietyVKit.place(w, Ids.EN_HOLLOW, p.x + 1.0, p.y)
	VarietyVKit.tough(w, victim)
	HazardDrums.ignite(w, 0)
	VarietyVKit.run(w, DRUM_FUSE)  # the blast lands
	assert_int(w.hazards.pool_count()).is_equal(1)
	var started: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.POOL_STARTED)
	assert_int(started[0].b).is_equal(220)
	assert_float(started[0].f).is_equal(p.x)
	var after_blast: float = VarietyVKit.taken(w, victim)
	VarietyVKit.run(w, 400)
	assert_int(w.hazards.pool_count()).is_equal(0)
	var ended: Array[int] = VarietyVKit.ticks_of(w, SimEventKind.Id.POOL_ENDED)
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0] - started[0].tick).is_between(298, 301)  # five seconds
	assert_float(VarietyVKit.taken(w, victim)).is_greater(after_blast + 100.0)  # 15 per second, ten pulses


func test_a_strike_a_pool_a_freight_car_and_a_vent_each_light_a_drum() -> void:
	var w: SimWorld = _world()
	var a: Vector2 = HazardDrums.position_of(w, 0)
	var b: Vector2 = HazardDrums.position_of(w, 1)
	var c: Vector2 = HazardDrums.position_of(w, 2)
	var _seq: int = HazardSystem.queue_hit(
		w, 1, HazardState.K_STRIKE, a.x + 3.0, a.y, 4.0, 450.0, 0.5, DamageResolver.F_AREA, DamageSource.Id.STRIKE
	)
	VarietyVKit.tick(w)
	assert_bool(w.hazards.d_alive[0] == 0 and w.hazards.d_alive[1] == 1).is_true()
	var _pool: int = HazardSystem.add_pool(w, b.x, b.y, 2.2, 600, 15.0, 0.25)
	VarietyVKit.run(w, 31)  # the first pulse of the pool
	assert_int(w.hazards.d_alive[1]).is_equal(0)
	HazardDrums.touch_lane(w, c.y, 1.3, c.x - 1.0, c.x + 1.0)  # the car passes the third
	assert_int(w.hazards.d_alive[2]).is_equal(0)


func test_a_lane_the_car_does_not_reach_leaves_the_drum_alone() -> void:
	var w: SimWorld = _world()
	var a: Vector2 = HazardDrums.position_of(w, 0)
	HazardDrums.touch_lane(w, a.y + 2.0, 1.3, a.x - 5.0, a.x + 5.0)  # 2 m off the lane
	HazardDrums.touch_lane(w, a.y, 1.3, a.x + 2.0, a.x + 6.0)  # not there yet
	HazardDrums.touch(w, a.x + 4.0, a.y, 3.0)  # 4 m from a blast of 3 m
	assert_int(HazardDrums.alive_count(w)).is_equal(3)


func test_eighty_points_of_stray_damage_light_a_drum_and_a_miss_far_away_does_not() -> void:
	var w: SimWorld = _world()
	var p: Vector2 = HazardDrums.position_of(w, 0)
	HazardDrums.stray(w, p.x + 5.0, p.y, 500.0)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	HazardDrums.stray(w, p.x + 0.2, p.y, 40.0)
	HazardDrums.stray(w, p.x, p.y - 0.2, 39.9)
	assert_int(w.hazards.d_damage_milli[0]).is_equal(79900)
	assert_int(HazardDrums.alive_count(w)).is_equal(3)
	HazardDrums.stray(w, p.x, p.y, 0.1)
	assert_int(HazardDrums.alive_count(w)).is_equal(2)
	HazardDrums.stray(w, p.x, p.y, 500.0)  # a drum that is gone cannot be lit twice
	assert_int(VarietyVKit.count(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(1)


# --- chains ---


func test_drums_chain_one_after_the_other_without_recursion() -> void:
	var w: SimWorld = _world()
	_drums_at(w, [Vector2(0.0, 0.0), Vector2(2.5, 0.0), Vector2(5.0, 0.0), Vector2(12.0, 0.0)])
	HazardDrums.ignite(w, 0)
	VarietyVKit.run(w, 40)
	assert_array(_blast_ticks(w, HazardState.K_DRUM)).is_equal([6, 12, 18])  # a ripple down the line
	assert_int(w.hazards.d_alive[3]).is_equal(1)  # 7 m from the last blast
	assert_int(HazardDrums.alive_count(w)).is_equal(1)


func test_drums_and_bursters_chain_both_ways() -> void:
	var w: SimWorld = _world()
	_drums_at(w, [Vector2(2.0, 2.0)])
	var first: int = VarietyVKit.place(w, Ids.EN_BURSTER, -0.8, 2.0)  # 2.8 m from the drum: its blast (2.6) reaches it
	var second: int = VarietyVKit.place(w, Ids.EN_BURSTER, 4.5, 2.0)  # 2.5 m on the other side, out of the first blast
	var third: int = VarietyVKit.place(w, Ids.EN_BURSTER, 6.5, 2.0)  # 2 m from the second, out of the drum's reach
	assert_int(first).is_greater_equal(0)
	var _killed: float = DamageResolver.hit_ex(w, first, 1000.0, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.WARDEN)
	VarietyVKit.run(w, 40)
	var blasts: Array[SimEvent] = VarietyVKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	var kinds: Array[int] = []
	var ticks: Array[int] = []
	for e: SimEvent in blasts:
		kinds.append(e.a)
		ticks.append(e.tick)
	# burster blast -> drum -> blast of the burster the drum killed -> blast of the one that blast killed
	assert_array(kinds).is_equal([HazardState.K_BLAST, HazardState.K_DRUM, HazardState.K_BLAST, HazardState.K_BLAST])
	assert_array(ticks).is_equal([6, 12, 18, 24])
	assert_int(w.enemies.alive[second]).is_equal(0)
	assert_int(w.enemies.alive[third]).is_equal(0)
	assert_int(VarietyVKit.alive(w)).is_equal(0)


func test_no_more_than_the_blast_limit_lands_on_one_tick() -> void:
	var w: SimWorld = _world()
	var points: Array[Vector2] = []
	for k: int in 12:
		points.append(Vector2(-9.0 + float(k) * 1.5, 0.0))
	_drums_at(w, points)
	for k: int in 12:
		HazardDrums.ignite(w, k)  # all twelve on the same tick
	var limit: int = w.content.run.max_blasts_per_tick
	VarietyVKit.run(w, DRUM_FUSE)
	assert_int(_blast_ticks(w, HazardState.K_DRUM).size()).is_equal(limit)
	VarietyVKit.tick(w)
	assert_int(_blast_ticks(w, HazardState.K_DRUM).size()).is_equal(12)  # the rest land on the next tick


# --- rule 1 ---


func test_a_drum_next_to_the_core_the_warden_and_a_turret_hurts_none_of_them() -> void:
	var w: SimWorld = _world()
	var arena: ArenaDef = w.content.arena
	_drums_at(w, [Vector2(arena.core_x + 2.5, arena.core_z), Vector2(arena.warden_x, arena.warden_z + 1.0)])
	w.turrets.active[0] = 1
	var core: float = w.core_hp
	var warden_x: float = w.warden.x
	HazardDrums.ignite(w, 0)
	HazardDrums.ignite(w, 1)
	VarietyVKit.run(w, 60)
	assert_float(w.core_hp).is_equal(core)
	assert_float(w.warden.x).is_equal(warden_x)
	assert_int(w.turrets.active[0]).is_equal(1)
	assert_int(VarietyVKit.count(w, SimEventKind.Id.CORE_HIT)).is_equal(0)
