extends GdUnitTestSuite
## V4-N: the movement cost of minis (VARIETY_SPEC 5.4: "about a quarter of a bodied enemy's movement cost, to be
## measured") and of the full 50 + 40 crowd, measured on MovementSystem.step and StatusSystem.step. The numbers are
## printed as "[BENCH] ..." lines; the assertions are loose so that a loaded machine does not turn the suite red.

const BLOCKS: int = 5
const BLOCK_TICKS: int = 60


func _world() -> SimWorld:
	var w: SimWorld = TestContent.variety_world()
	w.phase = GameState.Id.SPAWNING
	return w


## Spawns `n` enemies of a type spread over both spawn edges.
func _fill(w: SimWorld, type_index: int, n: int) -> void:
	for k: int in n:
		if k % 2 == 0:
			w.spawn_enemy(type_index, 10.5, -7.5 + 16.0 * float(k) / float(maxi(1, n)))
		else:
			w.spawn_enemy(type_index, -0.5 + 10.0 * float(k) / float(maxi(1, n)), -16.5)


## Microseconds per MovementSystem.step: the best block average of BLOCKS blocks, each from a fresh crowd in the field.
func _movement_usec(type_index: int, n: int) -> float:
	var best: float = INF
	for _b: int in BLOCKS:
		var w: SimWorld = _world()
		_fill(w, type_index, n)
		for _warm: int in 12:
			w.tick += 1
			MovementSystem.step(w)
		var t0: int = Time.get_ticks_usec()
		for _n: int in BLOCK_TICKS:
			w.tick += 1
			MovementSystem.step(w)
		best = minf(best, float(Time.get_ticks_usec() - t0) / float(BLOCK_TICKS))
	return best


func test_a_mini_costs_less_to_move_than_a_bodied_enemy() -> void:
	var minis: float = _movement_usec(Ids.EN_MOTE, 40)
	var bodies: float = _movement_usec(Ids.EN_SKITTER, 40)
	print("[BENCH] movement 40 minis: %.1f usec/tick (%.2f usec per mini)" % [minis, minis / 40.0])
	print("[BENCH] movement 40 skitters: %.1f usec/tick (%.2f usec per body)" % [bodies, bodies / 40.0])
	print("[BENCH] mini / bodied movement cost: %.2f" % (minis / maxf(0.001, bodies)))
	assert_float(minis).is_less(bodies)
	assert_float(minis).is_less(1000.0)  # 40 minis stay far under a millisecond per tick


func test_the_full_crowd_of_50_bodies_and_40_minis_moves_within_the_tick_budget() -> void:
	var best_move: float = INF
	var best_status: float = INF
	for _b: int in BLOCKS:
		var w: SimWorld = _world()
		_fill(w, Ids.EN_SKITTER, 30)
		_fill(w, Ids.EN_HOLLOW, 12)
		_fill(w, Ids.EN_SPITTER, 8)
		_fill(w, Ids.EN_MOTE, 40)
		assert_int(w.alive_count()).is_equal(90)
		for _warm: int in 12:
			w.tick += 1
			StatusSystem.step(w)
			MovementSystem.step(w)
		var move_usec: int = 0
		var status_usec: int = 0
		for _n: int in BLOCK_TICKS:
			w.tick += 1
			var t0: int = Time.get_ticks_usec()
			StatusSystem.step(w)
			var t1: int = Time.get_ticks_usec()
			MovementSystem.step(w)
			status_usec += t1 - t0
			move_usec += Time.get_ticks_usec() - t1
		best_move = minf(best_move, float(move_usec) / float(BLOCK_TICKS))
		best_status = minf(best_status, float(status_usec) / float(BLOCK_TICKS))
	print("[BENCH] 90 bodies (50 + 40 minis): movement %.1f usec/tick, status %.1f usec/tick" % [best_move, best_status])
	assert_float(best_move).is_less(4000.0)
	assert_float(best_status).is_less(best_move)  # the status pass is the small part
