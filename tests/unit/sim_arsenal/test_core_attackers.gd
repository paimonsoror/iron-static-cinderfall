extends GdUnitTestSuite
## V2-C: the one-time attackers of the core (VARIETY_SPEC 5.1, 5.4; CONTENT 4.2) and the Scrap rules of a death.
## Core at (-7.5, 3.0), cage radius 2.0, 1000 hp. Burster: fuse 1.2 s = 72 ticks, 70 to the core; shot dead within 3 m
## of the cage its blast also costs the core 35. Mote: burns out within 0.6 m of the cage for 6.

const CORE_X: float = -7.5
const CORE_Z: float = 3.0


func _scrap_of(w: SimWorld, type_index: int) -> int:
	return w.content.enemies[type_index].scrap


## A burster standing in an attack slot 1.5 m from the cage.
func _burster_at_slot(w: SimWorld) -> int:
	return VarietyCKit.place(w, Ids.EN_BURSTER, CORE_X + 3.5, CORE_Z, EnemyStore.ST_ATTACKING)


func _tick(w: SimWorld) -> void:
	VarietyCKit.begin_tick(w)
	HazardSystem.step(w)
	CoreAttackSystem.step(w)


func test_a_burster_arms_at_its_slot_and_hits_the_core_for_70_after_72_ticks() -> void:
	var w: SimWorld = VarietyCKit.world()
	var b: int = _burster_at_slot(w)
	VarietyCKit.core_tick(w)  # tick 1: it arms
	assert_bool(w.ext.has_flag(b, EnemyExtState.F_ARMED)).is_true()
	assert_int(w.ext.fuse_ticks[b]).is_equal(72)
	VarietyCKit.run_core(w, 71)  # tick 72
	assert_int(w.ext.fuse_ticks[b]).is_equal(1)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.CORE_HIT)).is_equal(0)
	VarietyCKit.core_tick(w)  # tick 73 = 1 + 72
	assert_float(w.core_hp).is_equal(930.0)
	assert_int(w.enemies.alive[b]).is_equal(0)
	var hits: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0].a).is_equal(1)
	assert_int(hits[0].b).is_equal(Ids.EN_BURSTER)
	assert_float(hits[0].f).is_equal(70.0)
	assert_float(hits[0].g).is_equal(0.0)
	var killed: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_KILLED)
	assert_int(killed[0].b).is_equal(DeathHooks.SOURCE_SELF)
	assert_int(w.scrap).is_equal(0)  # nobody killed it
	assert_int(w.stats.kills_by_type[Ids.EN_BURSTER]).is_equal(1)
	assert_float(w.stats.core_damage_by_type[Ids.EN_BURSTER]).is_equal(70.0)
	assert_int(w.hazards.queued()).is_equal(1)  # the same blast on the enemies around it
	assert_int(w.hazards.q_due[0]).is_equal(79)
	assert_float(w.hazards.q_core[0]).is_equal(0.0)  # the 70 was the core's share


func test_the_shield_takes_the_detonation_first() -> void:
	var w: SimWorld = VarietyCKit.world()
	_burster_at_slot(w)
	w.shield_hp = 50.0
	VarietyCKit.run_core(w, 73)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_float(w.core_hp).is_equal(980.0)
	var hits: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_float(hits[0].f).is_equal(20.0)
	assert_float(hits[0].g).is_equal(50.0)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.SHIELD_CHANGED)).is_equal(1)
	assert_float(w.stats.damage_absorbed).is_equal(50.0)


func test_a_stun_freezes_the_fuse() -> void:
	var w: SimWorld = VarietyCKit.world()
	var b: int = _burster_at_slot(w)
	VarietyCKit.run_core(w, 11)
	assert_int(w.ext.fuse_ticks[b]).is_equal(62)
	w.enemies.stun_ticks[b] = 5
	VarietyCKit.run_core(w, 30)
	assert_int(w.ext.fuse_ticks[b]).is_equal(62)
	w.enemies.stun_ticks[b] = 0
	VarietyCKit.run_core(w, 61)
	assert_float(w.core_hp).is_equal(1000.0)
	VarietyCKit.core_tick(w)
	assert_float(w.core_hp).is_equal(930.0)


func test_the_detonation_also_blasts_the_enemies_around_it() -> void:
	var w: SimWorld = VarietyCKit.world()
	_burster_at_slot(w)
	var near: int = VarietyCKit.place(w, Ids.EN_SKITTER, CORE_X + 3.5, CORE_Z + 2.0)
	for _n: int in 78:
		_tick(w)
	assert_int(w.enemies.alive[near]).is_equal(1)
	_tick(w)  # tick 79: six ticks after the detonation
	assert_int(w.enemies.alive[near]).is_equal(0)
	assert_int(w.scrap).is_equal(_scrap_of(w, Ids.EN_SKITTER))
	assert_float(w.core_hp).is_equal(930.0)  # the blast itself costs the core nothing more


func test_a_burster_shot_dead_next_to_the_cage_costs_the_core_35() -> void:
	var w: SimWorld = VarietyCKit.world()
	var b: int = _burster_at_slot(w)
	VarietyCKit.run_core(w, 10)  # armed, the fuse runs
	DamageResolver.hit_ex(w, b, 500.0, 0, DamageSource.Id.WARDEN)
	assert_int(w.scrap).is_equal(_scrap_of(w, Ids.EN_BURSTER))
	assert_float(w.hazards.q_core[0]).is_equal(35.0)
	w.shield_hp = 10.0
	for _n: int in 5:
		_tick(w)
	assert_float(w.core_hp).is_equal(1000.0)
	_tick(w)  # tick 16
	assert_float(w.core_hp).is_equal(975.0)  # 35, the shield took 10
	var hits: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(1)
	assert_int(hits[0].a).is_equal(0)  # no living attacker
	assert_int(hits[0].b).is_equal(Ids.EN_BURSTER)
	assert_float(hits[0].g).is_equal(10.0)


func test_a_burster_killed_in_the_field_costs_the_core_nothing() -> void:
	var w: SimWorld = VarietyCKit.world()
	var far: int = VarietyCKit.place(w, Ids.EN_BURSTER, CORE_X + 5.1, CORE_Z)  # 3.1 m from the cage
	DamageResolver.hit_ex(w, far, 500.0, 0, DamageSource.Id.WARDEN)
	assert_float(w.hazards.q_core[0]).is_equal(0.0)
	var near: int = VarietyCKit.place(w, Ids.EN_BURSTER, CORE_X + 4.9, CORE_Z)  # 2.9 m from the cage
	DamageResolver.hit_ex(w, near, 500.0, 0, DamageSource.Id.WARDEN)
	assert_float(w.hazards.q_core[1]).is_equal(35.0)
	w.phase = GameState.Id.INTERMISSION  # the wave is over before the blast lands: no core damage outside a wave
	for _n: int in 6:
		VarietyCKit.hazard_tick(w)
	assert_int(VarietyCKit.count(w, SimEventKind.Id.AREA_BLAST)).is_equal(2)
	assert_float(w.core_hp).is_equal(1000.0)


func test_a_mote_burns_out_on_the_cage_for_6_and_pays_no_scrap() -> void:
	var w: SimWorld = VarietyCKit.world()
	var outside: int = VarietyCKit.place(w, Ids.EN_MOTE, CORE_X + 2.7, CORE_Z)
	var inside: int = VarietyCKit.place(w, Ids.EN_MOTE, CORE_X + 2.5, CORE_Z)
	VarietyCKit.core_tick(w)
	assert_int(w.enemies.alive[outside]).is_equal(1)
	assert_int(w.enemies.alive[inside]).is_equal(0)
	assert_float(w.core_hp).is_equal(994.0)
	assert_int(w.scrap).is_equal(0)
	assert_int(w.stats.kills_by_type[Ids.EN_MOTE]).is_equal(1)
	var hits: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits[0].b).is_equal(Ids.EN_MOTE)
	assert_float(hits[0].f).is_equal(6.0)
	assert_int(VarietyCKit.events_of(w, SimEventKind.Id.ENEMY_KILLED)[0].b).is_equal(DeathHooks.SOURCE_SELF)
	assert_int(w.hazards.queued()).is_equal(0)
	w.enemies.state[outside] = EnemyStore.ST_ATTACKING  # a mote that was given a slot burns out there
	VarietyCKit.core_tick(w)
	assert_int(w.enemies.alive[outside]).is_equal(0)
	assert_float(w.core_hp).is_equal(988.0)
	assert_int(w.scrap).is_equal(0)


func test_a_mote_that_is_shot_pays_its_scrap() -> void:
	var w: SimWorld = VarietyCKit.world()
	var mote: int = VarietyCKit.place(w, Ids.EN_MOTE, 5.0, 0.0)
	DamageResolver.hit_ex(w, mote, 30.0, 0, DamageSource.Id.WARDEN)
	assert_int(w.enemies.alive[mote]).is_equal(0)
	assert_int(w.scrap).is_equal(_scrap_of(w, Ids.EN_MOTE))


func test_a_shield_turns_a_mote_stream_into_nothing() -> void:
	var w: SimWorld = VarietyCKit.world()
	w.shield_hp = 100.0
	for k: int in 10:
		VarietyCKit.place(w, Ids.EN_MOTE, CORE_X + 2.2, CORE_Z + 0.1 * float(k))
	VarietyCKit.core_tick(w)
	assert_int(w.alive_count()).is_equal(0)
	assert_float(w.core_hp).is_equal(1000.0)
	assert_float(w.shield_hp).is_equal(40.0)
	assert_int(w.combat.core_hits).is_equal(10)
	assert_int(w.scrap).is_equal(0)


func test_a_stunned_mote_does_not_burn_out() -> void:
	var w: SimWorld = VarietyCKit.world()
	var mote: int = VarietyCKit.place(w, Ids.EN_MOTE, CORE_X + 2.5, CORE_Z)
	w.enemies.stun_ticks[mote] = 10
	VarietyCKit.run_core(w, 5)
	assert_int(w.enemies.alive[mote]).is_equal(1)
	assert_float(w.core_hp).is_equal(1000.0)


func test_hits_of_one_tick_land_in_id_order_whatever_their_kind() -> void:
	var w: SimWorld = VarietyCKit.world()
	var skitter: int = VarietyCKit.place(w, Ids.EN_SKITTER, CORE_X + 3.0, CORE_Z, EnemyStore.ST_ATTACKING)
	VarietyCKit.place(w, Ids.EN_MOTE, CORE_X + 2.5, CORE_Z)
	var second: int = VarietyCKit.place(w, Ids.EN_SKITTER, CORE_X + 3.0, CORE_Z + 1.0, EnemyStore.ST_ATTACKING)
	w.enemies.attack_cd[skitter] = 1
	w.enemies.attack_cd[second] = 1
	w.shield_hp = 15.0
	VarietyCKit.core_tick(w)
	var hits: Array[SimEvent] = VarietyCKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(3)
	assert_array([hits[0].a, hits[1].a, hits[2].a]).is_equal([1, 2, 3])
	assert_array([hits[0].g, hits[1].g, hits[2].g]).is_equal([12.0, 3.0, 0.0])  # the shield is spent in that order
	assert_float(w.core_hp).is_equal(1000.0 - 3.0 - 12.0)
	assert_int(w.enemies.attack_cd[skitter]).is_equal(w.content.enemies[Ids.EN_SKITTER].attack_period_ticks)


func test_the_act_tier_and_the_period_modifier_apply_to_core_hits() -> void:
	var w: SimWorld = VarietyCKit.world()
	var skitter: int = VarietyCKit.place(w, Ids.EN_SKITTER, CORE_X + 3.0, CORE_Z, EnemyStore.ST_ATTACKING)
	w.enemies.attack_cd[skitter] = 1
	w.phase_state.act = 2  # core_dmg_mult 1.15
	w.mods.enemy_attack_period_mul = 1.5
	assert_float(CoreAttackSystem.core_mult(w)).is_equal_approx(1.15, 1e-6)
	VarietyCKit.core_tick(w)
	assert_float(w.core_hp).is_equal_approx(1000.0 - 13.8, 1e-5)
	assert_int(w.enemies.attack_cd[skitter]).is_equal(135)  # 90 x 1.5
	var legacy: SimWorld = TestContent.world()
	legacy.phase_state.act = 2
	assert_float(CoreAttackSystem.core_mult(legacy)).is_equal(1.0)


func test_scrap_for_a_kill() -> void:
	var w: SimWorld = VarietyCKit.world()
	var plain: int = VarietyCKit.place(w, Ids.EN_BURSTER, 0.0, 0.0)
	var elite: int = w.spawn_enemy(Ids.EN_BURSTER, 1.0, 0.0, 1)
	assert_int(DeathHooks.scrap_for(w, plain, DamageSource.Id.WARDEN)).is_equal(10)
	assert_int(DeathHooks.scrap_for(w, plain, DamageSource.Id.HAZARD)).is_equal(10)
	assert_int(DeathHooks.scrap_for(w, plain, DeathHooks.SOURCE_SELF)).is_equal(0)
	assert_int(DeathHooks.scrap_for(w, elite, DamageSource.Id.WARDEN)).is_equal(40)  # elite x4
	w.mods.scrap_mul = 1.5  # mod_bounty
	assert_int(DeathHooks.scrap_for(w, plain, DamageSource.Id.WARDEN)).is_equal(15)
	w.events_state.scrap_mult_milli = 2000  # relay window, while it runs
	assert_int(DeathHooks.scrap_for(w, plain, DamageSource.Id.WARDEN)).is_equal(15)
	w.events_state.scrap_mult_ticks = 60
	assert_int(DeathHooks.scrap_for(w, plain, DamageSource.Id.WARDEN)).is_equal(30)
	var legacy: SimWorld = TestContent.world()
	var skitter: int = legacy.spawn_enemy(Ids.EN_SKITTER, 0.0, 0.0)
	assert_int(DeathHooks.scrap_for(legacy, skitter, DeathHooks.SOURCE_SELF)).is_equal(20)  # legacy: the plain value
