extends GdUnitTestSuite
## V4-N, GDD 6.3 row `shieldbearer` and the ward maths of CONTENT 4.2 with exact numbers: ward radius 2.4 m, pool 120,
## every other enemy inside takes x0.4 and the blocked damage drains the pool, the pool refills fully after 4 s
## without absorbing, a stun (the EMP) empties it and holds the refill, a hit that ignores armor drains it x3.

const EPS: float = 0.000001


var _w: SimWorld
var _bearer: int
var _other: int


## A bearer 8 m from the core and a tough skitter `gap` m beside it, after one status tick (the pool is full).
## Fills _w, _bearer and _other.
func _pair(gap: float = 1.0) -> SimWorld:
	_w = SimEnemiesKit.world()
	_bearer = SimEnemiesKit.place_core(_w, Ids.EN_SHIELDBEARER, 8.0, 0.0)
	_other = SimEnemiesKit.place_core(_w, Ids.EN_SKITTER, 8.0 + gap, 0.0)
	SimEnemiesKit.tough(_w, _other)
	_status(_w, 1)
	return _w


func _status(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		SimEnemiesKit.begin_tick(w)
		AbilitySystem.step(w)
		StatusSystem.step(w)


func test_a_new_bearer_carries_a_full_pool_of_120() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	assert_int(w.ext.ward_milli[bearer]).is_equal(120000)
	assert_int(StatusSystem.ward_max_milli(w, bearer)).is_equal(120000)
	assert_int(w.nav.cover[_other]).is_equal(bearer)
	assert_int(w.nav.cover[bearer]).is_equal(-1)


func test_a_covered_enemy_takes_40_percent_and_the_blocked_damage_drains_the_pool() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	var other: int = _other
	assert_float(SimEnemiesKit.hit(w, other, 50.0)).is_equal_approx(20.0, EPS)  # 30 blocked
	assert_int(w.ext.ward_milli[bearer]).is_equal(90000)
	assert_float(SimEnemiesKit.hit(w, other, 100.0)).is_equal_approx(40.0, EPS)  # 60 blocked
	assert_int(w.ext.ward_milli[bearer]).is_equal(30000)
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_BROKEN).size()).is_equal(0)
	# the pool holds 30: a hit of 200 would have 120 blocked, only 30 are, and the ward breaks
	assert_float(SimEnemiesKit.hit(w, other, 200.0)).is_equal_approx(170.0, EPS)
	assert_int(w.ext.ward_milli[bearer]).is_equal(0)
	var broken: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_BROKEN)
	assert_int(broken.size()).is_equal(1)
	assert_int(broken[0].a).is_equal(w.enemies.id[bearer])
	# pool at 0 = no protection
	assert_float(SimEnemiesKit.hit(w, other, 100.0)).is_equal_approx(100.0, EPS)
	var changed: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_CHANGED)
	assert_float(changed[-1].f).is_equal(0.0)
	assert_float(changed[-1].g).is_equal(120.0)


func test_the_bearer_is_not_protected_by_its_own_ward() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	SimEnemiesKit.tough(w, bearer)
	assert_float(SimEnemiesKit.hit(w, bearer, 100.0, DamageResolver.F_IGNORE_ARMOR)).is_equal_approx(100.0, EPS)
	assert_int(w.ext.ward_milli[bearer]).is_equal(120000)


func test_an_enemy_outside_2_4_m_is_not_covered() -> void:
	var wi: SimWorld = _pair(2.39)
	assert_float(SimEnemiesKit.hit(wi, _other, 100.0)).is_equal_approx(40.0, EPS)
	var wo: SimWorld = _pair(2.41)
	assert_float(SimEnemiesKit.hit(wo, _other, 100.0)).is_equal_approx(100.0, EPS)
	assert_int(wo.ext.ward_milli[_bearer]).is_equal(120000)


func test_the_pool_refills_fully_after_4_s_without_absorbing() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	var other: int = _other
	SimEnemiesKit.hit(w, other, 100.0)
	assert_int(w.ext.ward_milli[bearer]).is_equal(60000)
	_status(w, 100)
	SimEnemiesKit.hit(w, other, 50.0)  # absorbing again restarts the 4 s
	assert_int(w.ext.ward_milli[bearer]).is_equal(30000)
	_status(w, 239)
	assert_int(w.ext.ward_milli[bearer]).is_equal(30000)
	_status(w, 1)
	assert_int(w.ext.ward_milli[bearer]).is_equal(120000)
	assert_float(SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_CHANGED)[-1].f).is_equal(120.0)


func test_a_stun_empties_the_pool_and_holds_the_refill_for_the_stun_plus_4_s() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	var other: int = _other
	assert_bool(StatusSystem.apply_stun(w, bearer, 180)).is_true()  # what the EMP does to it
	_status(w, 1)
	assert_int(w.ext.ward_milli[bearer]).is_equal(0)
	assert_int(SimEnemiesKit.events_of(w, SimEventKind.Id.WARD_BROKEN).size()).is_equal(1)
	assert_float(SimEnemiesKit.hit(w, other, 100.0)).is_equal_approx(100.0, EPS)
	_status(w, 180 + 240 - 3)
	assert_int(w.ext.ward_milli[bearer]).is_equal(0)
	_status(w, 3)
	assert_int(w.ext.ward_milli[bearer]).is_equal(120000)
	assert_float(SimEnemiesKit.hit(w, other, 100.0)).is_equal_approx(40.0, EPS)


func test_a_hit_that_ignores_armor_drains_the_pool_three_times_as_fast() -> void:
	var w: SimWorld = _pair()
	var bearer: int = _bearer
	var other: int = _other
	assert_float(SimEnemiesKit.hit(w, other, 50.0, DamageResolver.F_IGNORE_ARMOR)).is_equal_approx(20.0, EPS)
	assert_int(w.ext.ward_milli[bearer]).is_equal(30000)  # 30 blocked cost 90
	# 30 left pay for 10 blocked damage: 50 - 10 gets through and the ward breaks
	assert_float(SimEnemiesKit.hit(w, other, 50.0, DamageResolver.F_IGNORE_ARMOR)).is_equal_approx(40.0, EPS)
	assert_int(w.ext.ward_milli[bearer]).is_equal(0)


func test_a_hit_with_f_no_ward_passes_the_ward() -> void:
	var w: SimWorld = _pair()
	assert_float(SimEnemiesKit.hit(w, _other, 100.0, DamageResolver.F_NO_WARD)).is_equal_approx(100.0, EPS)
	assert_int(w.ext.ward_milli[_bearer]).is_equal(120000)


func test_a_dead_bearer_protects_nobody() -> void:
	var w: SimWorld = _pair()
	SimEnemiesKit.kill(w, _bearer)
	assert_float(SimEnemiesKit.hit(w, _other, 100.0)).is_equal_approx(100.0, EPS)


func test_minis_and_other_bearers_are_covered_too_and_two_wards_do_not_stack() -> void:
	var w: SimWorld = SimEnemiesKit.world()
	var a: int = SimEnemiesKit.place_core(w, Ids.EN_SHIELDBEARER, 8.0, 0.0)
	var b: int = SimEnemiesKit.place_core(w, Ids.EN_SHIELDBEARER, 9.0, 0.0)
	var mote: int = SimEnemiesKit.place_core(w, Ids.EN_MOTE, 8.5, 0.5)
	SimEnemiesKit.tough(w, mote)
	SimEnemiesKit.tough(w, b)
	_status(w, 1)
	assert_int(w.nav.cover[mote]).is_equal(a)  # the first bearer in store order
	assert_int(w.nav.cover[b]).is_equal(a)
	assert_int(w.nav.cover[a]).is_equal(b)
	assert_float(SimEnemiesKit.hit(w, mote, 100.0)).is_equal_approx(40.0, EPS)  # x0.4 once, not x0.16
	assert_int(w.ext.ward_milli[a]).is_equal(60000)
	assert_int(w.ext.ward_milli[b]).is_equal(120000)
	# a covers b: 56 - 6 armor = 50, of which 30 are blocked by a's pool; b's own pool is not touched
	assert_float(SimEnemiesKit.hit(w, b, 56.0)).is_equal_approx(20.0, EPS)
	assert_int(w.ext.ward_milli[a]).is_equal(30000)
	assert_int(w.ext.ward_milli[b]).is_equal(120000)


func test_a_bearer_walks_to_a_slot_and_hits_for_26_every_2_s() -> void:
	var w: SimWorld = SimEnemiesKit.world()
	var s: int = SimEnemiesKit.place_core(w, Ids.EN_SHIELDBEARER, 7.0, 0.0)
	assert_int(SimEnemiesKit.run_until_attacking(w, s)).is_greater(0)
	SimEnemiesKit.run(w, 250)
	var hits: Array[SimEvent] = SimEnemiesKit.events_of(w, SimEventKind.Id.CORE_HIT)
	assert_int(hits.size()).is_equal(2)
	assert_float(hits[0].f).is_equal(26.0)
	assert_int(hits[1].tick - hits[0].tick).is_equal(120)
	assert_int(w.ext.ward_milli[s]).is_equal(120000)  # attacking does not cost the ward
