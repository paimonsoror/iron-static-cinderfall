extends GdUnitTestSuite
## V1-S: the sandboxes of the variety milestone (VARIETY_SPEC 13.8): SimPuppet scenarios `hold<N>+<M>` and `chain`
## (PuppetChaos), the HUD sandbox states `--state=draft|route|boss_brief|salvage|combat2`, and the new debug arguments.

var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()
	MatLib.configure(c.tokens)


func _puppet(scenario_name: String, bodies: bool) -> SimPuppet:
	var p: SimPuppet = SimPuppet.new()
	auto_free(p)
	add_child(p)
	p.setup(c, scenario_name, 1, bodies)
	return p


func _run(p: SimPuppet, ticks: int) -> void:
	for _t: int in ticks:
		p.step_once()


func _types_alive(p: SimPuppet) -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	var st: EnemyStore = p.world.enemies
	for i: int in st.high_water:
		if st.alive[i] == 1:
			out[st.type[i]] = out.get(st.type[i], 0) + 1
	return out


func test_parse_reads_the_variety_scenarios() -> void:
	var plus: Dictionary[String, Variant] = SimPuppet.parse("hold50+40", 50, 40)
	assert_int(plus["hold"]).is_equal(50)
	assert_int(plus["minis"]).is_equal(40)
	assert_bool(plus["chain"]).is_false()
	var clamped: Dictionary[String, Variant] = SimPuppet.parse("hold99+99", 50, 40)
	assert_int(clamped["hold"]).is_equal(50)
	assert_int(clamped["minis"]).is_equal(40)
	var legacy: Dictionary[String, Variant] = SimPuppet.parse("hold20+10", 50)  # no swarm cap: no minis
	assert_int(legacy["minis"]).is_equal(0)
	var chain: Dictionary[String, Variant] = SimPuppet.parse("chain", 50, 40)
	assert_bool(chain["chain"]).is_true()
	assert_int(chain["hold"]).is_equal(SimPuppet.CHAIN_HOLD)
	var plain: Dictionary[String, Variant] = SimPuppet.parse("hold28", 50, 40)
	assert_int(plain["hold"]).is_equal(28)
	assert_int(plain["minis"]).is_equal(0)
	var junk: Dictionary[String, Variant] = SimPuppet.parse("hold+", 50, 40)
	assert_int(junk["hold"]).is_equal(50)


func test_hold_plus_minis_keeps_both_crowds() -> void:
	var p: SimPuppet = _puppet("hold20+12", true)
	_run(p, 240)
	assert_int(p.chaos.minis_alive()).is_between(9, 12)  # a kill is replaced within a few ticks
	assert_int(p.world.alive_count() - p.chaos.minis_alive()).is_between(18, 20)
	assert_int(_types_alive(p).get(Ids.EN_MOTE, 0)).is_equal(p.chaos.minis_alive())
	assert_int(p.chaos.arcs).is_greater(0)
	assert_int(p.events.count_of(SimEventKind.Id.CHAIN_ARC)).is_equal(p.chaos.arcs)


func test_without_variety_bodies_every_row_is_a_legacy_type() -> void:
	for scenario_name: String in ["hold20+12", "chain"]:
		var p: SimPuppet = _puppet(scenario_name, false)
		_run(p, 420)
		for type_index: int in _types_alive(p):
			assert_int(type_index).is_less(Ids.LEGACY_ENEMY_COUNT)
		assert_int(p.chaos.minis_alive()).is_equal(0)


func test_chain_runs_the_strike_and_the_blast_chain() -> void:
	var p: SimPuppet = _puppet("chain", true)
	assert_int(p.hold).is_equal(SimPuppet.CHAIN_HOLD)
	_run(p, 1)
	assert_int(_types_alive(p).get(Ids.EN_BURSTER, 0)).is_equal(PuppetChaos.CHAIN_LEN)  # the line walked in
	_run(p, PuppetChaos.T_WARN)
	assert_int(p.events.count_of(SimEventKind.Id.EVENT_WARNED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.AREA_BLAST)).is_equal(0)  # a warning comes before the effect
	_run(p, PuppetChaos.CYCLE - PuppetChaos.T_WARN - 2)
	assert_int(p.events.count_of(SimEventKind.Id.DELAYED_HIT_LAUNCHED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.EVENT_STARTED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.EVENT_ENDED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.AREA_BLAST)).is_equal(1 + PuppetChaos.CHAIN_LEN)
	assert_int(p.chaos.blasts).is_equal(1 + PuppetChaos.CHAIN_LEN)
	assert_int(p.events.count_of(SimEventKind.Id.POOL_STARTED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.POOL_ENDED)).is_equal(1)
	assert_int(p.events.count_of(SimEventKind.Id.CHAIN_ARC)).is_greater(8)
	assert_int(_types_alive(p).get(Ids.EN_BURSTER, 0)).is_equal(0)  # the line went off, one kill each
	_run(p, 4)
	assert_int(_types_alive(p).get(Ids.EN_BURSTER, 0)).is_equal(PuppetChaos.CHAIN_LEN)  # the next lap


func test_the_chain_events_reach_the_bus() -> void:
	var bus: GameSignalLog = GameSignalLog.new()
	bus.attach()
	var p: SimPuppet = _puppet("chain", true)
	_run(p, PuppetChaos.CYCLE - 1)
	bus.detach()
	assert_int(bus.count(&"event_warned")).is_equal(1)
	assert_str(str(bus.first_args(&"event_warned")[0])).is_equal("deadfall_strike")
	assert_int(bus.count(&"area_blast")).is_equal(1 + PuppetChaos.CHAIN_LEN)
	assert_float(bus.first_args(&"area_blast")[3]).is_equal_approx(4.0, 0.0001)  # the strike: 400 cm
	assert_int(bus.count(&"chain_arc")).is_greater(8)
	assert_int(bus.count(&"delayed_hit")).is_equal(1)
	assert_int(bus.count(&"pool_changed")).is_equal(2)
	assert_int(bus.count(&"enemy_killed")).is_greater_equal(PuppetChaos.CHAIN_LEN)


func test_the_boss_scenario_telegraphs_and_the_old_scenarios_do_not_script_chaos() -> void:
	var boss: SimPuppet = _puppet("boss", false)
	_run(boss, PuppetChaos.BOSS_EVERY)
	assert_int(boss.events.count_of(SimEventKind.Id.BOSS_TELEGRAPH)).is_equal(1)
	var plain: SimPuppet = _puppet("hold10", false)
	_run(plain, 400)
	assert_bool(plain.chaos.active()).is_false()
	assert_int(plain.events.count_of(SimEventKind.Id.CHAIN_ARC)).is_equal(0)
	assert_int(plain.world.alive_count()).is_between(9, 10)


func test_the_view_handshake_is_off_until_the_actor_layer_supports_the_types() -> void:
	var view: BattleView = ViewIntegrationKit.battle_view(self, TestContent.baseline())
	var supported: bool = view.actor_layer.has_method("supports_enemy_type")
	var drawn: bool = VarietySandboxProbe.draws_variety(view)
	assert_bool(drawn and not supported).is_false()  # never real variety bodies for a view that cannot draw them


func _hud_sandbox() -> HudSandbox:
	var packed: PackedScene = load("res://src/debug/hud_sandbox.tscn") as PackedScene
	var node: HudSandbox = packed.instantiate() as HudSandbox
	var host: Control = Control.new()
	auto_free(host)
	host.size = Vector2(1080.0, 2400.0)
	add_child(host)
	host.add_child(node)
	return node


func test_the_hud_sandbox_shows_every_variety_state() -> void:
	var sb: HudSandbox = _hud_sandbox()
	var awaits: Dictionary[String, int] = {
		"draft": RunApi.AWAIT_DRAFT, "route": RunApi.AWAIT_ROUTE, "boss_brief": RunApi.AWAIT_BOSS_BRIEF,
		"salvage": RunApi.AWAIT_SALVAGE, "combat2": RunApi.AWAIT_NONE,
	}
	for state: String in awaits:
		assert_bool(sb.show_state(state)).is_true()
		assert_int(sb.api().awaiting()).is_equal(awaits[state])
		if state == "combat2":
			assert_object(sb.overlay()).is_null()
			assert_int(sb.api().weapon_slot_count()).is_equal(2)
		else:
			assert_object(sb.overlay()).is_not_null()
			assert_bool(sb.overlay().get_parent() == sb).is_true()
			assert_int(UiKit.labels(sb.overlay()).size()).is_greater(0)  # the stub shows the header at least
	assert_bool(sb.show_state("nonsense")).is_false()


func test_a_pinned_state_does_not_cycle() -> void:
	var sb: HudSandbox = _hud_sandbox()
	assert_bool(sb.show_state("draft")).is_true()
	var step: int = sb.current_step()
	for _n: int in 4:
		sb._process(3.0)
	assert_int(sb.current_step()).is_equal(step)
	assert_int(sb.api().awaiting()).is_equal(RunApi.AWAIT_DRAFT)


func test_debug_args_parse_the_variety_flags() -> void:
	var a: DebugArgs = DebugArgs.parse(PackedStringArray([
		"--state=DRAFT", "--kit=k_standard", "--unlock=all", "--daily", "--scenario=hold50+40",
	]))
	assert_str(a.hud_state).is_equal("draft")
	assert_str(a.kit).is_equal("k_standard")
	assert_str(a.unlock).is_equal("all")
	assert_bool(a.daily).is_true()
	assert_str(a.scenario).is_equal("hold50+40")
	assert_int(a.scenario_n).is_equal(0)  # not a Game hold scenario: only the view sandbox reads the +M form
	var one: DebugArgs = DebugArgs.parse(PackedStringArray([
		"--capture-scene=res://src/debug/hud_sandbox.tscn --state=salvage", "--capture-out=C:/x/y.png",
	]))
	assert_str(one.hud_state).is_equal("salvage")
	assert_bool(one.wants_capture()).is_true()
	assert_str(DebugArgs.parse(PackedStringArray([])).hud_state).is_equal("")
