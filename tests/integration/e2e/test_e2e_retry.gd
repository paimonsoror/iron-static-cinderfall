extends GdUnitTestSuite
## Retry 100 times in one process (WORK_PLAN W3-A): the node count, the Events connections, the orphan nodes and the
## object count stay exactly where they were, memory stays within 5%, every retry has its own run id and no old sim
## stays alive. Each retry is a real one: HUD pause button, then RESTART on the pause overlay, 60 frames of combat.

const RETRIES: int = 100
const WARM_UP: int = 5  ## retries before the baseline (pools and caches fill once)

var _h: GameHarness


func after_test() -> void:
	if _h != null:
		_h.dispose()
		_h = null


func _retry() -> void:
	_h.hud().pause_requested.emit()
	(_h.find_in("OverlayRoot", &"PauseOverlay") as PauseOverlay).restart_pressed.emit()
	_h.frames(60)  # combat starts after 10 ticks: enemies spawn, the Warden shoots, effects play


func test_retrying_100_times_leaks_no_nodes_connections_objects_or_memory() -> void:
	_h = GameHarness.create(self, PackedStringArray(["--scenario=hold20", "--seed=5"]), IntegrationKit.short_prepare)
	_h.boot()
	_h.events_log.detach()  # the harness's own recorder would grow with every event and hide what Game does
	_h.events_log.rows.clear()
	_h.frames(100)
	for i: int in WARM_UP:
		_retry()
	await _h.settle(get_tree(), 4)
	var baseline: Dictionary = IntegrationKit.leak_counters()
	var run_ids: PackedStringArray = PackedStringArray()
	var old_sims: PackedInt64Array = PackedInt64Array()  # instance ids, so that watching does not allocate objects
	var node_counts: PackedInt32Array = PackedInt32Array()
	var connection_counts: PackedInt32Array = PackedInt32Array()
	for i: int in RETRIES:
		if not run_ids.has(_h.rc().run_id):
			run_ids.append(_h.rc().run_id)
		old_sims.append(_h.rc().sim.get_instance_id())
		_retry()
		if i % 10 == 9:
			await _h.settle(get_tree(), 2)
			var now: Dictionary = IntegrationKit.leak_counters()
			var node_count: int = now["nodes"]
			var connection_count: int = now["connections"]
			node_counts.append(node_count)
			connection_counts.append(connection_count)
	await _h.settle(get_tree(), 4)
	var after: Dictionary = IntegrationKit.leak_counters()
	Log.info("e2e", "retry x%d  nodes %d -> %d  connections %d -> %d  orphans %d -> %d  objects %d -> %d  memory %d -> %d bytes" % [
		RETRIES, baseline["nodes"], after["nodes"], baseline["connections"], after["connections"],
		baseline["orphans"], after["orphans"], baseline["objects"], after["objects"], baseline["memory"], after["memory"],
	])
	for n: int in node_counts:  # every tenth retry
		assert_int(n).is_equal(baseline["nodes"])
	for c: int in connection_counts:
		assert_int(c).is_equal(baseline["connections"])
	assert_int(run_ids.size()).is_equal(RETRIES)  # every retry had its own run id
	assert_int(after["nodes"]).is_equal(baseline["nodes"])
	assert_int(after["connections"]).is_equal(baseline["connections"])
	assert_int(after["orphans"]).is_equal(baseline["orphans"])
	var base_objects: int = baseline["objects"]
	var base_memory: int = baseline["memory"]
	assert_int(after["objects"]).is_less_equal(int(float(base_objects) * 1.05))
	assert_int(after["memory"]).is_less_equal(int(float(base_memory) * 1.05))
	var alive_sims: int = 0
	for sim_id: int in old_sims:
		if is_instance_valid(instance_from_id(sim_id)):
			alive_sims += 1
	assert_int(alive_sims).is_equal(0)  # no old sim is kept alive by a signal, a timer or a view
	assert_bool(GameState.is_combat(_h.state())).is_true()  # the last retry is in combat
	assert_int(_h.rc().sim.config.run_seed).is_equal(5)  # --seed stays fixed for every retry
