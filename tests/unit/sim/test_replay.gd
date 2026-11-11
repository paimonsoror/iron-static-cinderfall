extends GdUnitTestSuite
## Replay.run (ARCH 6.7): the same config plus the command log reproduces the run, hash for hash.


func _config(run_seed: int = 3) -> SimConfig:
	var cfg: SimConfig = SimConfig.create(TestContent.baseline(), run_seed)
	cfg.debug_start_scrap = 2000
	return cfg


## A scripted run: purchases and abilities at known ticks, 900 ticks long. Returns the world.
func _play(cfg: SimConfig) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	for t: int in 900:
		if t == 10:
			w.submit(SimCommand.purchase(1, Ids.UP_FIRE_RATE))
			w.submit(SimCommand.purchase(2, Ids.UP_DAMAGE))
		if t == 40:
			w.submit(SimCommand.purchase(3, Ids.UP_AUTO_TURRET))
		if t == 400:
			w.submit(SimCommand.ability(4, Ids.AB_OVERDRIVE))
			w.submit(SimCommand.ability(5, Ids.AB_SHIELD))
		if t == 401:
			w.submit(SimCommand.purchase(3, Ids.UP_AUTO_TURRET))  # a repeated id: answered with DUPLICATE_COMMAND
		w.step()
		w.events.drain()
	return w


func test_replay_reproduces_the_final_hashes() -> void:
	var original: SimWorld = _play(_config())
	assert_int(original.command_log.entries.size()).is_equal(6)
	var again: SimWorld = Replay.run(_config(), original.command_log, original.tick)
	assert_int(again.tick).is_equal(original.tick)
	assert_str(again.state_hash()).is_equal(original.state_hash())
	assert_int(again.events.event_hash).is_equal(original.events.event_hash)
	assert_int(again.events.total).is_equal(original.events.total)
	assert_int(again.scrap).is_equal(original.scrap)


func test_replay_keeps_the_ticks_of_the_original_commands() -> void:
	var original: SimWorld = _play(_config())
	var again: SimWorld = Replay.run(_config(), original.command_log, original.tick)
	var a: Array[Dictionary] = original.command_log.to_dicts()
	var b: Array[Dictionary] = again.command_log.to_dicts()
	assert_int(b.size()).is_equal(a.size())
	for k: int in a.size():
		assert_dict(b[k]).is_equal(a[k])


func test_replay_does_not_change_the_log_it_is_given() -> void:
	var original: SimWorld = _play(_config())
	var before: Array[Dictionary] = original.command_log.to_dicts()
	Replay.run(_config(), original.command_log, original.tick)
	var after: Array[Dictionary] = original.command_log.to_dicts()
	assert_array(after).is_equal(before)


func test_replay_through_dictionaries_gives_the_same_run() -> void:
	var original: SimWorld = _play(_config())
	var log: CommandLog = CommandLog.from_dicts(original.command_log.to_dicts())
	var again: SimWorld = Replay.run(_config(), log, original.tick)
	assert_str(again.state_hash()).is_equal(original.state_hash())


func test_an_empty_log_is_a_plain_run() -> void:
	var plain: SimWorld = SimWorld.new(_config())
	for t: int in 500:
		plain.step()
		plain.events.drain()
	var again: SimWorld = Replay.run(_config(), CommandLog.new(), 500)
	assert_str(again.state_hash()).is_equal(plain.state_hash())
	assert_int(again.events.event_hash).is_equal(plain.events.event_hash)


func test_max_ticks_limits_the_replay() -> void:
	var original: SimWorld = _play(_config())
	var short: SimWorld = Replay.run(_config(), original.command_log, 300)
	assert_int(short.tick).is_equal(300)
	assert_int(short.command_log.entries.size()).is_equal(3)  # the commands logged at ticks 11, 11 and 41
	assert_int(short.upgrade_levels[Ids.UP_AUTO_TURRET]).is_equal(1)
	assert_int(short.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(0)


func test_replay_stops_when_the_run_is_over() -> void:
	# No purchases on the frozen baseline: the core falls in wave 3 (about tick 8,100), well before 20,000.
	var cfg: SimConfig = SimConfig.create(TestContent.baseline(), 1)
	var w: SimWorld = Replay.run(cfg, CommandLog.new(), 20000)
	assert_bool(w.is_over()).is_true()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.tick).is_less(20000)
