extends GdUnitTestSuite
## Stores, events, RNG and the hasher (ARCH 6.3, 6.4).


func test_enemy_store_alloc_gives_lowest_free_index() -> void:
	var st: EnemyStore = EnemyStore.new(4)
	assert_int(st.alloc()).is_equal(0)
	assert_int(st.alloc()).is_equal(1)
	assert_int(st.alloc()).is_equal(2)
	st.free_index(1)
	assert_int(st.alloc()).is_equal(1)
	assert_int(st.high_water).is_equal(3)


func test_enemy_store_alloc_at_capacity_returns_minus_one() -> void:
	var st: EnemyStore = EnemyStore.new(2)
	assert_int(st.alloc()).is_equal(0)
	assert_int(st.alloc()).is_equal(1)
	assert_int(st.alloc()).is_equal(-1)
	assert_int(st.alive_count()).is_equal(2)


func test_enemy_store_free_resets_the_slot() -> void:
	var st: EnemyStore = EnemyStore.new(3)
	var i: int = st.alloc()
	st.id[i] = 7
	st.hp[i] = 10.0
	st.slot[i] = 5
	st.free_index(i)
	assert_int(st.alive[i]).is_equal(0)
	assert_int(st.id[i]).is_equal(0)
	assert_float(st.hp[i]).is_equal(0.0)
	assert_int(st.slot[i]).is_equal(-1)
	assert_int(st.alive_count()).is_equal(0)


func test_enemy_store_index_of() -> void:
	var st: EnemyStore = EnemyStore.new(4)
	var a: int = st.alloc()
	var b: int = st.alloc()
	st.id[a] = 11
	st.id[b] = 12
	assert_int(st.index_of(12)).is_equal(b)
	assert_int(st.index_of(11)).is_equal(a)
	assert_int(st.index_of(99)).is_equal(-1)
	assert_int(st.index_of(0)).is_equal(-1)
	st.free_index(a)
	assert_int(st.index_of(11)).is_equal(-1)


func test_hash_changes_with_enemy_state() -> void:
	var st: EnemyStore = EnemyStore.new(4)
	var h0: StateHasher = StateHasher.new()
	st.hash_into(h0)
	var i: int = st.alloc()
	st.id[i] = 1
	var h1: StateHasher = StateHasher.new()
	st.hash_into(h1)
	st.x[i] = 3.5
	var h2: StateHasher = StateHasher.new()
	st.hash_into(h2)
	var a: String = h0.finish()
	var b: String = h1.finish()
	var c: String = h2.finish()
	assert_bool(a != b).is_true()
	assert_bool(b != c).is_true()
	assert_int(a.length()).is_equal(64)


func test_hasher_is_deterministic_and_order_sensitive() -> void:
	var h1: StateHasher = StateHasher.new()
	h1.put_int(1)
	h1.put_int(2)
	var h2: StateHasher = StateHasher.new()
	h2.put_int(1)
	h2.put_int(2)
	var h3: StateHasher = StateHasher.new()
	h3.put_int(2)
	h3.put_int(1)
	assert_str(h1.finish()).is_equal(h2.finish())
	assert_bool(h1.finish() != h3.finish()).is_true()


func test_turret_store_has_two_pads() -> void:
	var t: TurretStore = TurretStore.new()
	assert_int(t.active.size()).is_equal(2)
	assert_int(t.active_count()).is_equal(0)
	t.active[1] = 1
	assert_int(t.active_count()).is_equal(1)


func test_ability_state_ready_and_active() -> void:
	var a: AbilityState = AbilityState.new()
	assert_bool(a.is_ready(Ids.AB_EMP)).is_true()
	assert_bool(a.is_active(Ids.AB_EMP)).is_false()
	a.cooldown_left[Ids.AB_EMP] = 5
	assert_bool(a.is_ready(Ids.AB_EMP)).is_false()
	a.cooldown_left[Ids.AB_EMP] = 0
	a.active_left[Ids.AB_EMP] = 5
	assert_bool(a.is_ready(Ids.AB_EMP)).is_false()
	assert_bool(a.is_active(Ids.AB_EMP)).is_true()


func test_events_push_drain_and_hash() -> void:
	var ev: SimEvents = SimEvents.new()
	ev.current_tick = 9
	ev.push(SimEventKind.Id.SCRAP_CHANGED, 20, 20)
	ev.push(SimEventKind.Id.CORE_CHANGED, 0, 0, 900.0, 1000.0)
	assert_int(ev.total).is_equal(2)
	assert_int(ev.peek().size()).is_equal(2)
	var h: int = ev.event_hash
	assert_bool(h != 0).is_true()
	var out: Array[SimEvent] = ev.drain()
	assert_int(out.size()).is_equal(2)
	assert_int(out[0].tick).is_equal(9)
	assert_int(out[0].kind).is_equal(SimEventKind.Id.SCRAP_CHANGED)
	assert_float(out[1].f).is_equal(900.0)
	assert_int(ev.peek().size()).is_equal(0)
	assert_int(ev.event_hash).is_equal(h)


func test_event_hash_differs_for_different_events() -> void:
	var a: SimEvents = SimEvents.new()
	var b: SimEvents = SimEvents.new()
	a.push(SimEventKind.Id.WAVE_STARTED, 1, 16)
	b.push(SimEventKind.Id.WAVE_STARTED, 2, 36)
	assert_bool(a.event_hash != b.event_hash).is_true()


func test_rng_streams_are_deterministic_and_independent() -> void:
	var r1: SimRng = SimRng.new(42)
	var r2: SimRng = SimRng.new(42)
	var a1: float = r1.stream(&"spawn").randf()
	var a2: float = r2.stream(&"spawn").randf()
	assert_float(a1).is_equal(a2)
	# drawing from another stream does not disturb "spawn"
	r2.stream(&"steer").randf()
	assert_float(r1.stream(&"spawn").randf()).is_equal(r2.stream(&"spawn").randf())
	var r3: SimRng = SimRng.new(43)
	assert_bool(r3.stream(&"spawn").randf() != a1).is_true()


func test_command_log_round_trip() -> void:
	var log_a: CommandLog = CommandLog.new()
	var c: SimCommand = SimCommand.purchase(5, Ids.UP_FIRE_RATE)
	c.tick = 123
	log_a.entries.append(c)
	var rows: Array[Dictionary] = log_a.to_dicts()
	var back: CommandLog = CommandLog.from_dicts(rows)
	assert_int(back.entries.size()).is_equal(1)
	assert_int(back.entries[0].tick).is_equal(123)
	assert_int(back.entries[0].command_id).is_equal(5)
	assert_int(back.entries[0].kind).is_equal(SimCommand.Kind.PURCHASE)
	assert_int(back.entries[0].arg).is_equal(Ids.UP_FIRE_RATE)
