extends GdUnitTestSuite
## PolicyBot (ARCH 6.7): NONE never acts; GREEDY buys the cheapest buyable upgrade (ties by PRIORITY) and fires its
## three abilities on simple triggers. Frozen baseline content only (WORK_PLAN rule 5).


func _greedy() -> PolicyBot:
	return PolicyBot.new(PolicyBot.Policy.GREEDY)


func _only(w: SimWorld) -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


func _attackers(w: SimWorld, n: int) -> void:
	for k: int in n:
		var i: int = w.spawn_enemy(Ids.EN_SKITTER, 4.0, 0.0)
		w.enemies.state[i] = EnemyStore.ST_ATTACKING


func test_none_policy_never_submits_anything() -> void:
	var w: SimWorld = TestContent.world()
	var bot: PolicyBot = PolicyBot.new(PolicyBot.Policy.NONE)
	w.add_scrap(5000)
	for t: int in 600:
		bot.act(w)
		w.step()
		w.events.drain()
	assert_int(bot.commands_submitted).is_equal(0)
	assert_int(w.command_log.entries.size()).is_equal(0)
	assert_int(w.upgrade_levels[Ids.UP_DAMAGE]).is_equal(0)


func test_greedy_buys_the_cheapest_buyable_upgrade() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(1000)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.PURCHASE)
	assert_int(cmd.arg).is_equal(Ids.UP_FIRE_RATE)  # 150 is the cheapest of 150 / 175 / 200 / 350
	w.step()
	bot.act(w)
	assert_int(_only(w).arg).is_equal(Ids.UP_DAMAGE)  # then 175 (fire_rate level 2 costs 240)


func test_greedy_waits_when_nothing_is_affordable() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(149)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)
	assert_int(bot.commands_submitted).is_equal(0)


func test_equal_prices_go_by_the_fixed_priority() -> void:
	var c: ContentSet = TestContent.baseline()
	c.upgrades[Ids.UP_FIRE_RATE].base_cost = 175  # now equal to damage
	var w: SimWorld = SimWorld.new(SimConfig.create(c, 1))
	w.add_scrap(175)
	var bot: PolicyBot = _greedy()
	assert_int(bot.pick_purchase(w)).is_equal(Ids.UP_DAMAGE)  # damage comes before fire_rate in PRIORITY
	c.upgrades[Ids.UP_AUTO_TURRET].base_cost = 175
	c.upgrades[Ids.UP_ARMOR_PIERCING].base_cost = 175
	assert_int(bot.pick_purchase(w)).is_equal(Ids.UP_DAMAGE)


func test_the_smg_is_chosen_in_the_first_intermission_and_never_before() -> void:
	var early: SimWorld = FlowKit.in_phase(GameState.Id.PREPARING)
	for u: int in [Ids.UP_DAMAGE, Ids.UP_FIRE_RATE, Ids.UP_ARMOR_PIERCING, Ids.UP_AUTO_TURRET]:
		early.upgrade_levels[u] = early.content.upgrades[u].max_level  # only the SMG is left
	early.add_scrap(300)
	assert_int(_greedy().pick_purchase(early)).is_equal(-1)  # locked in PREPARING
	var wave_one: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	wave_one.upgrade_levels = early.upgrade_levels.duplicate()
	wave_one.add_scrap(300)
	assert_int(_greedy().pick_purchase(wave_one)).is_equal(-1)  # locked in wave 1
	var rest: SimWorld = FlowKit.in_phase(GameState.Id.INTERMISSION, 1)
	rest.upgrade_levels = early.upgrade_levels.duplicate()
	rest.add_scrap(300)
	assert_int(_greedy().pick_purchase(rest)).is_equal(Ids.UP_SMG)  # open in the first intermission


func test_one_purchase_per_call_with_counting_ids() -> void:
	var w: SimWorld = TestContent.world()
	w.add_scrap(5000)
	var bot: PolicyBot = _greedy()
	for n: int in 3:
		bot.act(w)
		assert_int(w.command_queue.size()).is_equal(1)
		assert_int(w.command_queue[0].command_id).is_equal(n + 1)
		w.step()
	assert_int(bot.commands_submitted).is_equal(3)
	assert_int(w.command_log.entries.size()).is_equal(3)
	assert_int(w.upgrade_levels[Ids.UP_FIRE_RATE] + w.upgrade_levels[Ids.UP_DAMAGE] + w.upgrade_levels[Ids.UP_ARMOR_PIERCING]).is_equal(3)


func test_emp_needs_twelve_attackers() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	_attackers(w, PolicyBot.EMP_ATTACKERS - 1)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)
	_attackers(w, 1)
	bot.act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.ABILITY)
	assert_int(cmd.arg).is_equal(Ids.AB_EMP)


func test_emp_is_not_asked_for_while_it_cools_down() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	_attackers(w, 14)
	w.abilities.cooldown_left[Ids.AB_EMP] = 500
	_greedy().act(w)
	assert_int(w.command_queue.size()).is_equal(0)


func test_shield_follows_a_drop_in_core_integrity() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 1)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)  # nothing hit the core yet
	w.set_core_hp(w.core_hp - 12.0)
	bot.act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.kind).is_equal(SimCommand.Kind.ABILITY)
	assert_int(cmd.arg).is_equal(Ids.AB_SHIELD)
	w.command_queue.clear()
	bot.act(w)  # the core did not lose more since the last call
	assert_int(w.command_queue.size()).is_equal(0)


func test_overdrive_needs_the_boss_alive_and_in_range() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 5)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)  # no boss
	var far: int = w.spawn_enemy(Ids.EN_HULK, 10.0, -16.0)  # 27.6 m from the Warden, range 25
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)
	w.enemies.x[far] = 0.0
	w.enemies.z[far] = 0.0
	bot.act(w)
	var cmd: SimCommand = _only(w)
	assert_int(cmd.arg).is_equal(Ids.AB_OVERDRIVE)


func test_nothing_is_submitted_once_the_run_is_over() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.DEFEAT)
	w.add_scrap(5000)
	var bot: PolicyBot = _greedy()
	bot.act(w)
	assert_int(w.command_queue.size()).is_equal(0)
	assert_int(bot.commands_submitted).is_equal(0)


func test_two_bots_on_the_same_seed_play_the_same_game() -> void:
	var a: SimWorld = TestContent.world(5)
	var b: SimWorld = TestContent.world(5)
	a.add_scrap(900)
	b.add_scrap(900)
	var bot_a: PolicyBot = _greedy()
	var bot_b: PolicyBot = _greedy()
	for t: int in 1500:
		bot_a.act(a)
		bot_b.act(b)
		a.step()
		b.step()
		a.events.drain()
		b.events.drain()
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.events.event_hash).is_equal(b.events.event_hash)
	assert_int(a.command_log.entries.size()).is_greater(0)
