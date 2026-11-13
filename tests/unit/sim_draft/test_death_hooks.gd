extends GdUnitTestSuite
## V4-C: the directives that hook a death (DeathHooks, CONTENT 3): aftershock, unstable_munitions (and its reload jam),
## chorus_handshake's crate, and the Tally's gain. Kills are made with SimWorld.kill_enemy and a DamageSource, the blast
## queue is stepped by HazardSystem.step.

const TOUGH: float = 1.0e9

var w: SimWorld


func before_test() -> void:
	w = DirectiveKit.world()


func _taken(i: int) -> float:
	return w.enemies.max_hp[i] - w.enemies.hp[i]


func _dummy(x: float, z: float) -> int:
	var i: int = DirectiveKit.place(w, Ids.EN_SKITTER, x, z)
	DirectiveKit.set_hp(w, i, TOUGH)
	return i


## Steps the hazard queue until `ticks` ticks have passed.
func _run_hazards(ticks: int) -> void:
	for _n: int in ticks:
		DirectiveKit.begin_tick(w)
		HazardSystem.step(w)


## The first seed from 1 on whose first `proc` draw satisfies `below` (true: under `limit`, false: at or over it).
func _seed_with_proc(limit: float, below: bool) -> int:
	for s: int in range(1, 400):
		var draw: float = SimRng.new(s).stream(&"proc").randf()
		if (draw < limit) == below:
			return s
	return -1


func test_aftershock_queues_a_1_5_metre_blast_of_30_when_a_stunned_enemy_dies() -> void:
	DirectiveKit.give(w, &"aftershock")
	var victim: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.enemies.stun_ticks[victim] = 120
	var inside: int = _dummy(1.0, 0.0)
	var outside: int = _dummy(2.0, 0.0)
	w.tick = 100
	w.kill_enemy(victim, DamageSource.Id.WARDEN)
	assert_int(w.hazards.queued()).is_equal(1)
	assert_int(w.hazards.q_due[0]).is_equal(106)  # the chain delay of 6 ticks
	assert_float(w.hazards.q_radius[0]).is_equal(1.5)
	assert_float(w.hazards.q_damage[0]).is_equal(30.0)
	assert_int(w.hazards.q_source[0]).is_equal(DamageSource.Id.HAZARD)
	_run_hazards(6)
	assert_float(_taken(inside)).is_equal(30.0)
	assert_float(_taken(outside)).is_equal(0.0)


func test_aftershock_needs_a_stun_a_real_kill_and_grows_with_overpressure() -> void:
	DirectiveKit.give(w, &"aftershock")
	var walker: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.kill_enemy(walker, DamageSource.Id.WARDEN)
	assert_int(w.hazards.queued()).is_equal(0)  # not stunned
	var burnt: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.enemies.stun_ticks[burnt] = 120
	w.kill_enemy(burnt, DeathHooks.SOURCE_SELF)
	assert_int(w.hazards.queued()).is_equal(0)  # a burnout is not a kill
	DirectiveKit.give(w, &"overpressure")
	var stunned: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	w.enemies.stun_ticks[stunned] = 120
	w.kill_enemy(stunned, DamageSource.Id.TURRET_0)
	assert_int(w.hazards.queued()).is_equal(1)
	assert_float(w.hazards.q_radius[0]).is_equal_approx(2.025, 0.00001)  # 1.5 x 1.35


func test_a_stunned_death_chain_ripples_through_the_stunned_crowd() -> void:
	DirectiveKit.give(w, &"aftershock")
	var first: int = DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0)
	var second: int = DirectiveKit.place(w, Ids.EN_SKITTER, 1.0, 0.0)
	var third: int = DirectiveKit.place(w, Ids.EN_SKITTER, 2.0, 0.0)  # 2 m from the first: out of its blast
	DirectiveKit.set_hp(w, second, 20.0)
	DirectiveKit.set_hp(w, third, 20.0)
	for i: int in [first, second, third]:
		w.enemies.stun_ticks[i] = 600
	w.kill_enemy(first, DamageSource.Id.WARDEN)
	_run_hazards(6)
	assert_int(w.enemies.alive[second]).is_equal(0)  # 30 >= 20
	assert_int(w.enemies.alive[third]).is_equal(1)
	_run_hazards(6)  # the second one was stunned too: its own blast reaches the third
	assert_int(w.enemies.alive[third]).is_equal(0)
	assert_int(w.combat.kills_by_source[DamageSource.Id.HAZARD]).is_equal(2)


func test_unstable_munitions_blasts_one_warden_kill_in_five() -> void:
	var lucky: int = _seed_with_proc(DeathHooks.MUNITIONS_CHANCE, true)
	var unlucky: int = _seed_with_proc(DeathHooks.MUNITIONS_CHANCE, false)
	assert_int(lucky).is_greater(0)
	assert_int(unlucky).is_greater(0)
	var hit: SimWorld = DirectiveKit.world(lucky)
	DirectiveKit.give(hit, &"unstable_munitions")
	hit.kill_enemy(DirectiveKit.place(hit, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(hit.hazards.queued()).is_equal(1)
	assert_float(hit.hazards.q_radius[0]).is_equal(2.0)
	assert_float(hit.hazards.q_damage[0]).is_equal(50.0)
	var miss: SimWorld = DirectiveKit.world(unlucky)
	DirectiveKit.give(miss, &"unstable_munitions")
	miss.kill_enemy(DirectiveKit.place(miss, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN_OFFHAND)
	assert_int(miss.hazards.queued()).is_equal(0)
	var reference: SimRng = SimRng.new(unlucky)
	var _draw: float = reference.stream(&"proc").randf()  # exactly one draw per Warden kill
	assert_str(DirectiveKit.hash_of(miss.rng)).is_equal(DirectiveKit.hash_of(reference))


func test_unstable_munitions_ignores_turret_kills_burnouts_and_a_world_without_it() -> void:
	var lucky: int = _seed_with_proc(DeathHooks.MUNITIONS_CHANCE, true)
	var armed: SimWorld = DirectiveKit.world(lucky)
	DirectiveKit.give(armed, &"unstable_munitions")
	armed.kill_enemy(DirectiveKit.place(armed, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.TURRET_0)
	armed.kill_enemy(DirectiveKit.place(armed, Ids.EN_SKITTER, 0.0, 0.0), DeathHooks.SOURCE_SELF)
	assert_int(armed.hazards.queued()).is_equal(0)
	assert_str(DirectiveKit.hash_of(armed.rng)).is_equal(DirectiveKit.hash_of(SimRng.new(lucky)))  # no draw
	var plain: SimWorld = DirectiveKit.world(lucky)
	plain.kill_enemy(DirectiveKit.place(plain, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(plain.hazards.queued()).is_equal(0)
	assert_str(DirectiveKit.hash_of(plain.rng)).is_equal(DirectiveKit.hash_of(SimRng.new(lucky)))


func test_unstable_munitions_jams_5_percent_of_reloads_for_1_5_seconds() -> void:
	var jam: int = _seed_with_proc(ModRules.JAM_CHANCE, true)
	var clean: int = _seed_with_proc(ModRules.JAM_CHANCE, false)
	var a: SimWorld = DirectiveKit.world(jam)
	DirectiveKit.give(a, &"unstable_munitions")
	assert_int(ModRules.reload_jam_ticks(a)).is_equal(90)
	var b: SimWorld = DirectiveKit.world(clean)
	DirectiveKit.give(b, &"unstable_munitions")
	assert_int(ModRules.reload_jam_ticks(b)).is_equal(0)
	var c: SimWorld = DirectiveKit.world(jam)
	assert_int(ModRules.reload_jam_ticks(c)).is_equal(0)  # without the directive
	assert_str(DirectiveKit.hash_of(c.rng)).is_equal(DirectiveKit.hash_of(SimRng.new(jam)))


func test_every_third_elite_killed_drops_a_crate_with_chorus_handshake() -> void:
	DirectiveKit.give(w, &"chorus_handshake")
	for n: int in 3:
		var elite: int = w.spawn_enemy(Ids.EN_SKITTER, 0.0, float(n), 1)
		assert_bool(w.ext.is_elite(elite)).is_true()
		w.kill_enemy(elite, DamageSource.Id.WARDEN)
		assert_int(w.salvage.banked.size()).is_equal(1 if n == 2 else 0)
	assert_int(w.salvage.elite_kills).is_equal(3)
	assert_int(w.salvage.crates_secured).is_equal(1)
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 9.0), DamageSource.Id.WARDEN)  # a plain kill counts for nothing
	assert_int(w.salvage.elite_kills).is_equal(3)
	assert_int(w.salvage.banked.size()).is_equal(1)


func test_no_crate_without_the_directive_or_for_a_burnout() -> void:
	for n: int in 3:
		w.kill_enemy(w.spawn_enemy(Ids.EN_SKITTER, 0.0, float(n), 1), DamageSource.Id.WARDEN)
	assert_int(w.salvage.banked.size()).is_equal(0)
	DirectiveKit.give(w, &"chorus_handshake")
	w.kill_enemy(w.spawn_enemy(Ids.EN_SKITTER, 0.0, 5.0, 1), DeathHooks.SOURCE_SELF)  # not counted
	assert_int(w.salvage.elite_kills).is_equal(3)
	w.kill_enemy(w.spawn_enemy(Ids.EN_SKITTER, 0.0, 6.0, 1), DamageSource.Id.WARDEN)  # the 4th
	assert_int(w.salvage.banked.size()).is_equal(0)


func test_the_tally_gains_one_percent_per_ten_warden_kills() -> void:
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 239
	DirectiveKit.give(w, &"the_tally")
	assert_int(HookMemory.tally_pct(w)).is_equal(23)
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 240  # hit_ex counts the kill before it calls kill_enemy
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(HookMemory.tally_pct(w)).is_equal(24)
	w.combat.kills_by_source[DamageSource.Id.WARDEN_OFFHAND] = 6  # the off-hand gun counts too: 246 in all
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN_OFFHAND)
	assert_int(HookMemory.tally_pct(w)).is_equal(24)
	w.combat.kills_by_source[DamageSource.Id.WARDEN_OFFHAND] = 10  # 250
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN_OFFHAND)
	assert_int(HookMemory.tally_pct(w)).is_equal(25)
	w.combat.kills_by_source[DamageSource.Id.TURRET_0] = 260  # a turret kill never counts
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.TURRET_0)
	assert_int(HookMemory.tally_pct(w)).is_equal(25)


func test_the_tally_stops_at_one_hundred_percent() -> void:
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 990
	DirectiveKit.give(w, &"the_tally")
	assert_int(HookMemory.tally_pct(w)).is_equal(99)
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 1000
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(HookMemory.tally_pct(w)).is_equal(100)
	w.combat.kills_by_source[DamageSource.Id.WARDEN] = 1010
	w.kill_enemy(DirectiveKit.place(w, Ids.EN_SKITTER, 0.0, 0.0), DamageSource.Id.WARDEN)
	assert_int(HookMemory.tally_pct(w)).is_equal(100)
	assert_float(ModRules.damage_mul(w)).is_equal_approx(2.0, 0.00001)  # +100%
