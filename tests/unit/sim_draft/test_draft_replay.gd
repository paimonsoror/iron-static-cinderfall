extends GdUnitTestSuite
## V2-B: drafts are part of the deterministic run. PhaseSystem does not open drafts until V2-A lands, so these tests
## open them by hand at fixed ticks and replay the logged commands with the loop of Replay.run (a logged command is
## submitted before the step that applied it).

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()


## The script of a run: the draft opens at tick 0 and again at tick 6; each command is (tick it is submitted before, command).
func _script() -> Array[SimCommand]:
	var cmds: Array[SimCommand] = [
		SimCommand.reroll(11), SimCommand.patch_core(12), SimCommand.buy_out(13, 1), SimCommand.pick_directive(14, 0),
		SimCommand.reroll(15), SimCommand.reroll(16), SimCommand.pick_directive(17, 2),
	]
	return cmds


## A world with Scrap and a wounded core, a draft opened at tick 0.
func _start(run_seed: int) -> SimWorld:
	var w: SimWorld = VarietyBKit.intermission_world(c, 3, run_seed)
	w.add_scrap(1500)
	w.set_core_hp(600.0)
	w.draft.free_rerolls = 1
	VarietyBKit.open_draft(w)
	return w


## Plays the script: one command per tick, the second draft opened by hand after the 4th command.
func _play(w: SimWorld) -> void:
	var cmds: Array[SimCommand] = _script()
	for n: int in cmds.size():
		w.submit(cmds[n])
		w.step()
		if n == 3:
			VarietyBKit.open_draft(w)
		w.events.drain()


## Replays `log` on a fresh world the way Replay.run does, opening the second draft where the player's run did.
func _replay(run_seed: int, log: CommandLog) -> SimWorld:
	var w: SimWorld = _start(run_seed)
	var next_entry: int = 0
	while next_entry < log.entries.size():
		var due: int = w.tick + 1
		while next_entry < log.entries.size() and log.entries[next_entry].tick <= due:
			var src: SimCommand = log.entries[next_entry]
			var copy: SimCommand = SimCommand.new()
			copy.command_id = src.command_id
			copy.kind = src.kind
			copy.arg = src.arg
			w.submit(copy)
			next_entry += 1
		w.step()
		if w.tick == 4:
			VarietyBKit.open_draft(w)
		w.events.drain()
	return w


func test_a_run_with_drafts_replays_to_the_same_hash_and_events() -> void:
	var a: SimWorld = _start(9)
	_play(a)
	assert_int(a.command_log.entries.size()).is_equal(7)
	assert_int(a.draft.offer_ordinal).is_equal(2)
	var b: SimWorld = _replay(9, a.command_log)
	assert_str(b.state_hash()).is_equal(a.state_hash())
	assert_int(b.events.event_hash).is_equal(a.events.event_hash)
	assert_int(b.tick).is_equal(a.tick)


func test_the_script_really_exercises_every_draft_command() -> void:
	var a: SimWorld = _start(9)
	_play(a)
	assert_int(a.draft.rerolls_paid).is_greater(0)  # the second reroll was paid
	assert_int(a.draft.patches).is_equal(1)
	assert_int(a.draft.buyouts).is_equal(1)
	var held: int = 0
	for stack: int in a.draft.stacks:
		held += stack
	assert_int(held).is_equal(3)  # buy-out + pick of draft one, pick of draft two


func test_another_seed_makes_another_run() -> void:
	var a: SimWorld = _start(9)
	var b: SimWorld = _start(10)
	_play(a)
	_play(b)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_thinking_time_does_not_change_the_run() -> void:
	var quick: SimWorld = _start(9)
	var slow: SimWorld = _start(9)
	for _n: int in 600:
		slow.step()  # a player staring at the draft screen: the tick does not advance
	assert_int(slow.tick).is_equal(0)
	assert_str(slow.state_hash()).is_equal(quick.state_hash())
	_play(quick)
	_play(slow)
	assert_str(slow.state_hash()).is_equal(quick.state_hash())
	assert_int(slow.events.event_hash).is_equal(quick.events.event_hash)


func test_draft_commands_use_the_draft_streams_only() -> void:
	var w: SimWorld = _start(9)
	_play(w)
	var reference: SimRng = SimRng.new(9)
	for n: int in 2:
		var name: StringName = StringName("draft:%d" % n)
		reference.stream(name).state = w.rng.stream(name).state
	var got: StateHasher = StateHasher.new()
	var want: StateHasher = StateHasher.new()
	w.rng.hash_into(got)
	reference.hash_into(want)
	assert_str(got.finish()).is_equal(want.finish())  # no spawn, steer, proc or kit stream was created


func test_a_draft_does_not_shift_the_spawn_stream() -> void:
	var with_draft: SimWorld = _start(9)
	_play(with_draft)
	var plain: SimWorld = VarietyBKit.intermission_world(c, 3, 9)
	var a: float = with_draft.rng.stream(&"spawn").randf()
	var b: float = plain.rng.stream(&"spawn").randf()
	assert_float(a).is_equal(b)


func test_the_offer_of_a_later_draft_does_not_depend_on_the_earlier_decisions() -> void:
	# The pool differs only by what was picked: with equal held directives, offer n is the same (VARIETY_SPEC 9.6).
	var a: SimWorld = VarietyBKit.world_after(c, 6, 4)
	var b: SimWorld = VarietyBKit.world_after(c, 6, 4)
	var _earlier: PackedInt32Array = VarietyBKit.offer_n(b, 0)  # b rolled an earlier offer, a did not
	assert_array(Array(VarietyBKit.offer_n(a, 5))).is_equal(Array(VarietyBKit.offer_n(b, 5)))
