extends GdUnitTestSuite
## V2-C: area damage, the delayed-effect queue and death blasts (VARIETY_SPEC 5.1, 9.5; CONTENT 4.2).
## Burster: 70 hp, death blast 90 damage within 2.6 m, 6 ticks after the death. Skitter 45 hp, Hollow Warden 150 hp
## and armor 8, mote 12 hp.


func _scrap_of(w: SimWorld, type_index: int) -> int:
	return w.content.enemies[type_index].scrap


func _kill(w: SimWorld, index: int) -> void:
	DamageResolver.hit_ex(w, index, VarietyCKit.TOUGH_HP, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.WARDEN)


func test_a_blast_falls_off_to_the_edge_and_reports_itself() -> void:
	var w: SimWorld = VarietyCKit.world()
	var centre: int = VarietyCKit.place(w, Ids.EN_SKITTER, 5.0, 0.0)
	var half: int = VarietyCKit.place(w, Ids.EN_SKITTER, 7.0, 0.0)
	var edge: int = VarietyCKit.place(w, Ids.EN_SKITTER, 9.0, 0.0)
	var outside: int = VarietyCKit.place(w, Ids.EN_SKITTER, 9.5, 0.0)
	for i: int in [centre, half, edge, outside]:
		VarietyCKit.tough(w, i)
	var hit: int = AreaDamage.blast(w, 5.0, 0.0, 4.0, 100.0, 0.5, 0, DamageSource.Id.HAZARD)
	assert_int(hit).is_equal(3)
	assert_float(VarietyCKit.taken(w, centre)).is_equal(100.0)
	assert_float(VarietyCKit.taken(w, half)).is_equal(75.0)
	assert_float(VarietyCKit.taken(w, edge)).is_equal(50.0)
	assert_float(VarietyCKit.taken(w, outside)).is_equal(0.0)
	var blasts: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST)
	assert_int(blasts.size()).is_equal(1)
	assert_int(blasts[0].a).is_equal(HazardState.K_BLAST)
	assert_int(blasts[0].b).is_equal(400)
	assert_float(blasts[0].f).is_equal(5.0)


func test_a_blast_meets_armor_unless_told_otherwise_and_hits_in_id_order() -> void:
	var w: SimWorld = VarietyCKit.world()
	var late: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 1.0, 0.0)  # id 1
	var early: int = VarietyCKit.place(w, Ids.EN_HOLLOW, -1.0, 0.0)  # id 2
	w.kill_enemy(late, DamageSource.Id.WARDEN)
	late = VarietyCKit.place(w, Ids.EN_HOLLOW, 1.0, 0.0)  # the freed row 0 again, now with id 3
	assert_int(late).is_less(early)
	AreaDamage.blast(w, 0.0, 0.0, 3.0, 50.0, 1.0, 0, DamageSource.Id.HAZARD)
	assert_float(w.enemies.hp[early]).is_equal(150.0 - 42.0)
	var damaged: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_DAMAGED)
	assert_int(damaged[0].a).is_equal(2)  # id order, not row order
	assert_int(damaged[1].a).is_equal(3)
	AreaDamage.blast(w, 0.0, 0.0, 3.0, 50.0, 1.0, DamageResolver.F_IGNORE_ARMOR, DamageSource.Id.HAZARD)
	assert_float(w.enemies.hp[early]).is_equal(150.0 - 42.0 - 50.0)


func test_a_line_of_six_bursters_goes_off_in_six_tick_steps_and_kills_the_expected_set() -> void:
	var w: SimWorld = VarietyCKit.world()
	var line: Array[int] = []
	for k: int in 6:
		line.append(VarietyCKit.place(w, Ids.EN_BURSTER, -6.0 + 2.0 * float(k), 0.0))  # 2 m apart, radius 2.6
	var near_third: int = VarietyCKit.place(w, Ids.EN_SKITTER, -2.0, 2.0)  # 2 m from burster 3 only
	var armored: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 2.0, 2.5)  # 2.5 m from burster 5 only
	var far: int = VarietyCKit.place(w, Ids.EN_SKITTER, 6.5, 2.2)  # 3.3 m from burster 6
	var mote: int = VarietyCKit.place(w, Ids.EN_MOTE, 5.5, 1.0)  # 1.8 m from burster 6, 3.6 m from burster 5
	VarietyCKit.begin_tick(w)
	_kill(w, line[0])  # tick 1
	VarietyCKit.run_hazards(w, 40)
	var killed: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_KILLED)
	var ids: Array[int] = []
	var ticks: Array[int] = []
	for e: SimEvent in killed:
		ids.append(e.a)
		ticks.append(e.tick)
	# bursters 1 .. 6 have ids 1 .. 6, the skitter 7, the mote 10
	assert_array(ids).is_equal([1, 2, 3, 4, 7, 5, 6, 10])
	assert_array(ticks).is_equal([1, 7, 13, 19, 19, 25, 31, 37])
	assert_array(VarietyCKit.ticks_of(w, SimEventKind.Id.AREA_BLAST)).is_equal([7, 13, 19, 25, 31, 37])
	assert_int(w.enemies.alive[near_third]).is_equal(0)
	assert_int(w.enemies.alive[mote]).is_equal(0)
	assert_int(w.enemies.alive[far]).is_equal(1)
	assert_float(w.enemies.hp[far]).is_equal(45.0)
	assert_int(w.enemies.alive[armored]).is_equal(1)
	assert_float(w.enemies.hp[armored]).is_equal(150.0 - 82.0)  # one blast, 90 - 8 armor
	assert_int(w.alive_count()).is_equal(2)
	assert_int(w.hazards.queued()).is_equal(0)
	# Scrap exactly once per kill
	assert_int(w.scrap).is_equal(6 * _scrap_of(w, Ids.EN_BURSTER) + _scrap_of(w, Ids.EN_SKITTER) + _scrap_of(w, Ids.EN_MOTE))
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SCRAP_CHANGED)).is_equal(8)
	assert_int(w.combat.kills_by_source[DamageSource.Id.WARDEN]).is_equal(1)
	assert_int(w.combat.kills_by_source[DamageSource.Id.HAZARD]).is_equal(7)
	assert_int(w.stats.kills_by_type[Ids.EN_BURSTER]).is_equal(6)


func test_a_blast_never_sets_off_another_blast_in_the_same_call() -> void:
	var w: SimWorld = VarietyCKit.world()
	var a: int = VarietyCKit.place(w, Ids.EN_BURSTER, 0.0, 0.0)
	var b: int = VarietyCKit.place(w, Ids.EN_BURSTER, 1.0, 0.0)
	var bystander: int = VarietyCKit.place(w, Ids.EN_SKITTER, 2.0, 0.0)
	VarietyCKit.begin_tick(w)
	AreaDamage.blast(w, 0.5, 0.0, 1.0, 500.0, 1.0, 0, DamageSource.Id.HAZARD)  # kills both bursters, not the skitter
	assert_int(w.enemies.alive[a]).is_equal(0)
	assert_int(w.enemies.alive[b]).is_equal(0)
	assert_float(w.enemies.hp[bystander]).is_equal(45.0)  # their own blasts have not landed
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(1)
	assert_int(w.hazards.queued()).is_equal(2)
	assert_array(Array(w.hazards.q_due)).is_equal([7, 7])
	assert_int(VarietyCKit.count(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(0)  # a death blast is not launched
	HazardSystem.step(w)  # still tick 1: nothing is due
	assert_int(w.hazards.queued()).is_equal(2)
	VarietyCKit.run_hazards(w, 5)
	assert_float(w.enemies.hp[bystander]).is_equal(45.0)
	VarietyCKit.hazard_tick(w)  # tick 7
	assert_int(w.enemies.alive[bystander]).is_equal(0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(3)


func test_a_hit_queued_while_another_lands_waits_for_a_later_tick() -> void:
	var w: SimWorld = VarietyCKit.world()
	VarietyCKit.begin_tick(w)
	var seq: int = HazardSystem.queue_hit(
		w, w.tick, HazardState.K_BLAST, 0.0, 0.0, 2.0, 10.0, 1.0, 0, DamageSource.Id.HAZARD
	)
	assert_int(seq).is_equal(1)
	assert_int(w.hazards.q_due[0]).is_equal(w.tick + 1)  # never the tick it was queued on
	HazardSystem.step(w)
	assert_int(w.hazards.queued()).is_equal(1)
	VarietyCKit.hazard_tick(w)
	assert_int(w.hazards.queued()).is_equal(0)
	assert_int(HazardSystem.queue_hit(w, 9, HazardState.K_BLAST, 0.0, 0.0, 0.0, 10.0, 1.0, 0, 0)).is_equal(-1)
	assert_int(HazardSystem.queue_hit(w, 9, HazardState.K_BLAST, 0.0, 0.0, 2.0, 0.0, 1.0, 0, 0)).is_equal(-1)


func test_at_most_eight_blasts_land_per_tick_and_the_rest_ripple() -> void:
	var w: SimWorld = VarietyCKit.world()
	VarietyCKit.begin_tick(w)
	for k: int in 20:
		HazardSystem.queue_hit(w, 5, HazardState.K_SHELL, float(k), 0.0, 1.0, 10.0, 1.0, 0, DamageSource.Id.WARDEN)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(20)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.DELAYED_HIT_LAUNCHED)[0].b).is_equal(4)  # ticks until it lands
	assert_int(HazardSystem.due_count(w, 5)).is_equal(20)
	VarietyCKit.run_hazards(w, 3)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(0)
	VarietyCKit.hazard_tick(w)  # tick 5
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(8)
	assert_int(w.hazards.queued()).is_equal(12)
	VarietyCKit.hazard_tick(w)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(16)
	VarietyCKit.hazard_tick(w)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(20)
	assert_int(w.hazards.queued()).is_equal(0)
	var xs: Array[float] = []
	for e: SimEvent in VarietyCKit.events_of(w, SimEventKind.Id.AREA_BLAST):
		xs.append(e.f)
		assert_int(e.a).is_equal(HazardState.K_SHELL)
	for k: int in 20:
		assert_float(xs[k]).is_equal(float(k))  # the order they were queued in


func test_the_queue_is_ordered_by_due_tick_then_sequence() -> void:
	var w: SimWorld = VarietyCKit.world()
	for due: int in [10, 5, 10, 5, 7]:
		HazardSystem.queue_hit(w, due, HazardState.K_BLAST, 0.0, 0.0, 1.0, 1.0, 1.0, 0, DamageSource.Id.HAZARD)
	assert_array(Array(w.hazards.q_due)).is_equal([5, 5, 7, 10, 10])
	assert_array(Array(w.hazards.q_seq)).is_equal([2, 4, 5, 1, 3])
	assert_int(w.hazards.next_seq).is_equal(6)
	HazardSystem.clear(w)
	assert_int(w.hazards.queued()).is_equal(0)
	assert_int(w.hazards.q_core.size()).is_equal(0)


func test_two_lethal_blasts_on_one_enemy_pay_scrap_once() -> void:
	var w: SimWorld = VarietyCKit.world()
	VarietyCKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	for _k: int in 2:
		HazardSystem.queue_hit(w, 3, HazardState.K_BLAST, 0.0, 0.0, 2.0, 500.0, 1.0, 0, DamageSource.Id.HAZARD)
	VarietyCKit.run_hazards(w, 3)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(2)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)
	assert_int(w.scrap).is_equal(_scrap_of(w, Ids.EN_SKITTER))
	assert_int(w.combat.kills_by_source[DamageSource.Id.HAZARD]).is_equal(1)


func test_volatile_skitters_blast_their_neighbours() -> void:
	var w: SimWorld = VarietyCKit.world()
	var first: int = VarietyCKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	var near: int = VarietyCKit.place(w, Ids.EN_SKITTER, 1.0, 0.0)
	var far: int = VarietyCKit.place(w, Ids.EN_SKITTER, 1.5, 0.0)
	VarietyCKit.begin_tick(w)
	_kill(w, first)
	assert_int(w.hazards.queued()).is_equal(0)  # no modifier, no blast
	w.mods.set_flag(&"volatile_skitters", true)  # mod_volatile
	w.mods.volatile_radius = 1.2
	w.mods.volatile_damage = 20.0
	first = VarietyCKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	_kill(w, first)
	assert_int(w.hazards.queued()).is_equal(1)
	VarietyCKit.run_hazards(w, 6)
	assert_float(w.enemies.hp[near]).is_equal(25.0)
	assert_float(w.enemies.hp[far]).is_equal(45.0)
	var hollow: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 5.0, 5.0)
	_kill(w, hollow)
	assert_int(w.hazards.queued()).is_equal(0)  # skitters only


func test_a_pool_burns_what_stands_in_it_and_ends() -> void:
	var w: SimWorld = VarietyCKit.world()
	var inside: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 1.0, 0.0)
	var outside: int = VarietyCKit.place(w, Ids.EN_HOLLOW, 3.0, 0.0)
	VarietyCKit.tough(w, inside)
	VarietyCKit.tough(w, outside)
	var pool_id: int = HazardSystem.add_pool(w, 0.0, 0.0, 2.2, 240, 15.0, 0.25)
	assert_int(pool_id).is_equal(1)
	assert_int(w.hazards.pool_count()).is_equal(1)
	VarietyCKit.run_hazards(w, 239)
	assert_int(w.hazards.pool_count()).is_equal(1)
	VarietyCKit.hazard_tick(w)
	assert_int(w.hazards.pool_count()).is_equal(0)
	assert_float(VarietyCKit.taken(w, inside)).is_equal(60.0)  # 15 per second for 4 s, armor does not help
	assert_float(VarietyCKit.taken(w, outside)).is_equal(0.0)
	var started: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.POOL_STARTED)
	assert_int(started[0].a).is_equal(1)
	assert_int(started[0].b).is_equal(220)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.POOL_ENDED)[0].a).is_equal(1)
	assert_int(HazardSystem.add_pool(w, 0.0, 0.0, 0.0, 240, 15.0, 0.0)).is_equal(-1)
	HazardSystem.add_pool(w, 0.0, 0.0, 1.0, 100, 1.0, 0.0)
	HazardSystem.clear(w)
	assert_int(w.hazards.pool_count()).is_equal(0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.POOL_ENDED)).is_equal(2)


func test_incendiary_tips_burn_for_exactly_24_and_do_not_stack() -> void:
	var w: SimWorld = VarietyCKit.world()
	w.mods.burn_dps = 8.0  # incendiary_tips
	var i: int = VarietyCKit.place_rel(w, Ids.EN_HULK, 10.0, 0.0)
	VarietyCKit.tough(w, i)
	VarietyCKit.run_weapon(w, 30)  # the first pistol round
	assert_int(w.ext.burn_ticks[i]).is_equal(180)
	assert_int(w.ext.burn_milli[i]).is_equal(8000)
	w.kill_enemy(i, DamageSource.Id.WARDEN)  # stop the shooting, keep the test on one burn
	i = VarietyCKit.place(w, Ids.EN_HOLLOW, 9.0, -9.0)
	VarietyCKit.tough(w, i)
	StatusSystem.apply_burn(w, i, 180, 8000)
	StatusSystem.apply_burn(w, i, 180, 8000)  # a second hit refreshes, it does not stack
	for _n: int in 180:
		VarietyCKit.begin_tick(w)
		StatusSystem.step(w)
	assert_int(w.ext.burn_ticks[i]).is_equal(0)
	assert_float(VarietyCKit.taken(w, i)).is_equal(24.0)  # 6 pulses of 4, armor ignored
	assert_float(w.combat.damage_by_source[DamageSource.Id.HAZARD]).is_equal(24.0)
	for _n: int in 60:
		VarietyCKit.begin_tick(w)
		StatusSystem.step(w)
	assert_float(VarietyCKit.taken(w, i)).is_equal(24.0)


func test_a_burn_that_is_refreshed_by_every_hit_still_burns_and_its_kill_pays_once() -> void:
	var w: SimWorld = VarietyCKit.world()
	var i: int = VarietyCKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.enemies.hp[i] = 10.0
	for _n: int in 120:
		VarietyCKit.begin_tick(w)
		StatusSystem.apply_burn(w, i, 180, 8000)  # refreshed on every tick
		StatusSystem.step(w)
	assert_int(w.enemies.alive[i]).is_equal(0)  # 3 pulses of 4 in 90 ticks
	assert_int(w.scrap).is_equal(_scrap_of(w, Ids.EN_SKITTER))
	assert_int(VarietyCKit.count(w, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)
	assert_int(w.ext.burn_ticks[i]).is_greater(0)  # a dead row is left alone; spawn_enemy resets it
	var again: int = VarietyCKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	assert_int(again).is_equal(i)
	assert_int(w.ext.burn_ticks[again]).is_equal(0)
