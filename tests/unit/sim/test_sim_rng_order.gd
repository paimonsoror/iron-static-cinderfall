extends GdUnitTestSuite
## V3-I: the state hash of the random streams depends on their names and states only, never on when or in which
## process the names were made. SimRng used to sort its StringName keys, which orders them by interned pointer: two
## worlds with the same streams could hash differently (a generated run makes names such as "draft:3" and "crate:2" at
## run time), so a run file's `state_hash` did not survive the process that wrote it.


func _hash(rng: SimRng) -> String:
	var h: StateHasher = StateHasher.new()
	rng.hash_into(h)
	return h.finish()


## A SimRng whose streams are created in `order`, each drawn from `draws` times.
func _made(order: Array[String], draws: int) -> SimRng:
	var rng: SimRng = SimRng.new(77)
	for stream_name: String in order:
		for _n: int in draws:
			rng.stream(StringName(stream_name)).randf()
	return rng


func test_the_names_come_out_sorted_by_text() -> void:
	var rng: SimRng = _made(["spawn", "draft:10", "crate:2", "draft:2", "crate:1", "steer"], 1)
	assert_array(Array(rng.names_sorted())).is_equal(["crate:1", "crate:2", "draft:10", "draft:2", "spawn", "steer"])


func test_the_hash_does_not_depend_on_the_order_the_streams_were_made_in() -> void:
	var forward: Array[String] = ["spawn", "draft:0", "crate:1", "draft:1", "crate:2", "draft:2", "draft:3"]
	var backward: Array[String] = forward.duplicate()
	backward.reverse()
	assert_str(_hash(_made(backward, 3))).is_equal(_hash(_made(forward, 3)))


func test_the_hash_survives_the_names_being_freed_and_made_again() -> void:
	# The names of the first generator die with it; the second one makes them again, between other new names, so they
	# are interned at other addresses and in another order.
	var names: Array[String] = []
	for n: int in 12:
		names.append("draft:%d" % (900 + n))
		names.append("crate:%d" % (900 + n))
	var first: String = _hash(_made(names, 2))
	var noise: Array[StringName] = []
	for n: int in 200:
		noise.append(StringName("noise_%d_%d" % [n, 900 + n]))
	var shuffled: Array[String] = names.duplicate()
	shuffled.reverse()
	for round_index: int in 5:
		assert_str(_hash(_made(shuffled, 2))).override_failure_message("round %d" % round_index).is_equal(first)
		shuffled.append(shuffled.pop_front())
	assert_int(noise.size()).is_equal(200)


func test_the_hash_still_tells_states_and_names_apart() -> void:
	var a: SimRng = _made(["spawn", "draft:0"], 1)
	var more_draws: SimRng = _made(["spawn", "draft:0"], 2)
	var other_name: SimRng = _made(["spawn", "draft:1"], 1)
	assert_str(_hash(more_draws)).is_not_equal(_hash(a))
	assert_str(_hash(other_name)).is_not_equal(_hash(a))
	assert_str(_hash(_made(["spawn", "draft:0"], 1))).is_equal(_hash(a))


func test_two_worlds_of_one_seed_and_one_log_hash_alike_after_the_first_is_gone() -> void:
	# The whole-world form of the same thing: a balanced bot run of the slice, played twice, the first world freed
	# before the second is made.
	var first: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 12), PolicyBot.Policy.BALANCED, 0)
	var first_hash: String = first.state_hash
	var first_ticks: int = first.ticks
	first.world = null
	first = null
	var second: HarnessReport = SimHarness.run(SimConfig.create(TestContent.variety(), 12), PolicyBot.Policy.BALANCED, 0)
	assert_int(second.ticks).is_equal(first_ticks)
	assert_str(second.state_hash).is_equal(first_hash)


func test_a_snapshot_lists_the_streams_by_text() -> void:
	var w: SimWorld = TestContent.variety_world(3)
	for stream_name: String in ["draft:1", "crate:1", "draft:0", "spawn"]:
		w.rng.stream(StringName(stream_name)).randf()
	var doc: Dictionary = WorldSnapshot.capture(w)
	var rows: Array = doc["rng"]
	var listed: Array[String] = []
	for row: Array in rows:
		listed.append(str(row[0]))
	assert_array(listed).is_equal(["crate:1", "draft:0", "draft:1", "spawn"])
