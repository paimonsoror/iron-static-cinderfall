extends GdUnitTestSuite
## V1-S: GameEventRelay maps the sim events of the variety milestone to the new Events signals (VARIETY_SPEC 13.4),
## and the RunApi base class, GameRunFlow and FakeRunApi carry the new members.

var _relay: GameEventRelay
var _log: GameSignalLog
var c: ContentSet


func before_test() -> void:
	c = TestContent.variety()
	_relay = GameEventRelay.new(c)
	_log = GameSignalLog.new()
	_log.attach()


func after_test() -> void:
	_log.detach()


func _send(kind: int, a: int = 0, b: int = 0, f: float = 0.0, g: float = 0.0) -> bool:
	var e: SimEvent = SimEvent.new()
	e.kind = kind
	e.a = a
	e.b = b
	e.f = f
	e.g = g
	return _relay.relay(e)


func test_draft_route_and_await_events() -> void:
	_send(SimEventKind.Id.ACT_STARTED, 2)
	_send(SimEventKind.Id.DIRECTIVE_PICKED, c.directive_index(&"glass_cannon"), 1)
	_send(SimEventKind.Id.ROUTE_OFFERED, 3, 2)
	_send(SimEventKind.Id.ROUTE_PICKED, 3, 1)
	_send(SimEventKind.Id.AWAIT_CHANGED, PhaseState.Await.DRAFT, PhaseState.Await.NONE)
	assert_array(_log.first_args(&"act_started")).is_equal([2])
	assert_array(_log.first_args(&"directive_picked")).is_equal([&"glass_cannon", 1])
	assert_int(_log.count(&"route_offered")).is_equal(1)
	assert_array(_log.first_args(&"route_picked")).is_equal([1])
	assert_array(_log.first_args(&"await_changed")).is_equal([RunApi.AWAIT_DRAFT])
	assert_int(_log.count(&"salvage_offered")).is_equal(0)
	_send(SimEventKind.Id.AWAIT_CHANGED, PhaseState.Await.SALVAGE, PhaseState.Await.NONE)
	assert_int(_log.count(&"salvage_offered")).is_equal(1)


func test_draft_offered_carries_the_ids_of_the_bound_world() -> void:
	_send(SimEventKind.Id.DRAFT_OFFERED, 1, 3)
	var unbound: Array = _log.first_args(&"draft_offered")
	var unbound_ids: Array = unbound[0]
	assert_int(unbound_ids.size()).is_equal(0)
	var w: SimWorld = SimWorld.new(SimConfig.create(c, 1))
	w.draft.offer = PackedInt32Array([6, 0, -1])  # debug write: DraftSystem fills it once V2-B lands
	_relay.world = w
	_log.clear()
	_send(SimEventKind.Id.DRAFT_REROLLED, 1, 60)
	var bound: Array = _log.first_args(&"draft_offered")
	var bound_ids: Array = bound[0]
	assert_array(bound_ids).is_equal([&"incendiary_tips", &"hot_loads", &""])


func test_weapon_blast_arc_and_pool_events() -> void:
	_send(SimEventKind.Id.WEAPON_SWAPPED, 1, Ids.WP_ARC_PROJECTOR)
	_send(SimEventKind.Id.WEAPON_VENTED, 1, 150)
	_send(SimEventKind.Id.AREA_BLAST, HazardState.K_BLAST, 260, 3.0, -2.0)
	_send(SimEventKind.Id.CHAIN_ARC, 0, 17)
	_send(SimEventKind.Id.DELAYED_HIT_LAUNCHED, HazardState.K_STRIKE, 120, 1.0, 2.0)
	_send(SimEventKind.Id.POOL_STARTED, 4, 220, 1.0, 2.0)
	_send(SimEventKind.Id.POOL_ENDED, 4, 0, 1.0, 2.0)
	assert_array(_log.first_args(&"weapon_swapped")).is_equal([1, &"arc_projector"])
	assert_array(_log.first_args(&"weapon_vented")).is_equal([1])
	var blast: Array = _log.first_args(&"area_blast")
	assert_int(blast[0]).is_equal(HazardState.K_BLAST)
	assert_float(blast[1]).is_equal(3.0)
	assert_float(blast[2]).is_equal(-2.0)
	assert_float(blast[3]).is_equal_approx(2.6, 0.0001)  # centimeters in the sim, meters on the bus
	assert_array(_log.first_args(&"chain_arc")).is_equal([0, 17])
	assert_array(_log.first_args(&"delayed_hit")).is_equal([HazardState.K_STRIKE, 1.0, 2.0, 120])
	var started: Array = _log.first_args(&"pool_changed")
	assert_bool(started[4]).is_true()
	assert_float(started[3]).is_equal_approx(2.2, 0.0001)
	assert_bool(_log.last_args(&"pool_changed")[4]).is_false()


func test_elite_ward_event_and_boss_events() -> void:
	_send(SimEventKind.Id.ENEMY_SPAWNED, 41, Ids.EN_RUSHER, 5.0, -3.0)
	_send(SimEventKind.Id.ELITE_SPAWNED, 41, 0b101)
	_send(SimEventKind.Id.WARD_CHANGED, 41, 0, 30.0, 120.0)
	_send(SimEventKind.Id.WARD_BROKEN, 41)
	_send(SimEventKind.Id.EVENT_WARNED, 0, 120, 2.0, -3.0)
	_send(SimEventKind.Id.EVENT_STARTED, 0, 0, 2.0, -3.0)
	_send(SimEventKind.Id.EVENT_ENDED, 0)
	_send(SimEventKind.Id.EVENT_CANCELLED, 0, Reason.Id.LOCKED_BY_EVENT)
	_send(SimEventKind.Id.BOSS_TELEGRAPH, 2, 90)
	_send(SimEventKind.Id.BOSS_PHASE, 1, 2)
	_send(SimEventKind.Id.CHARGES_CHANGED, 0, 2)
	_send(SimEventKind.Id.COMMAND_REJECTED, 77, Reason.Id.NO_CHARGES)
	assert_array(_log.first_args(&"elite_spawned")).is_equal([41, &"rusher", 5])
	assert_array(_log.first_args(&"ward_changed")).is_equal([41, 0.25])
	assert_array(_log.last_args(&"ward_changed")).is_equal([41, 0.0])
	assert_array(_log.first_args(&"event_warned")).is_equal([&"deadfall_strike", 120, 2.0, -3.0])
	assert_array(_log.first_args(&"event_started")).is_equal([&"deadfall_strike"])
	assert_int(_log.count(&"event_ended")).is_equal(2)
	assert_array(_log.first_args(&"boss_telegraph")).is_equal([2, 90])
	assert_array(_log.first_args(&"boss_phase")).is_equal([1])
	assert_array(_log.first_args(&"charges_changed")).is_equal([&"deadfall_strike", 2])
	assert_array(_log.first_args(&"command_rejected")).is_equal([77, Reason.Id.NO_CHARGES])


func test_crate_events_and_the_kinds_without_a_signal() -> void:
	_send(SimEventKind.Id.CRATE_DROPPED, 1, 0, 2.0, -3.0)
	_send(SimEventKind.Id.CRATE_SECURED, 1)
	_send(SimEventKind.Id.CRATE_LOST, 2)
	assert_array(_log.first_args(&"crate_dropped")).is_equal([2.0, -3.0])
	assert_int(_log.count(&"crate_secured")).is_equal(1)
	assert_int(_log.count(&"crate_lost")).is_equal(1)
	_log.clear()
	for kind: int in [
		SimEventKind.Id.BOSS_BRIEFED, SimEventKind.Id.SALVAGE_RESOLVED, SimEventKind.Id.ENEMY_SPLIT,
		SimEventKind.Id.ENEMY_HEALED, SimEventKind.Id.CORE_HEALED,
	]:
		assert_bool(_send(kind)).is_false()
		assert_bool(GameEventRelay.NO_SIGNAL.has(kind)).is_true()
	assert_int(_log.rows.size()).is_equal(0)


func test_run_api_base_defaults() -> void:
	var api: RunApi = RunApi.new()
	assert_int(api.awaiting()).is_equal(RunApi.AWAIT_NONE)
	assert_int(api.act()).is_equal(1)
	assert_int(api.act_count()).is_equal(1)
	assert_int(api.draft_offer().size()).is_equal(0)
	assert_int(api.draft_reroll_cost() + api.draft_buyout_cost() + api.patch_cost() + api.free_rerolls()).is_equal(0)
	assert_int(api.route_option_count()).is_equal(0)
	assert_bool(api.route_option(0).is_empty()).is_true()
	assert_bool(api.boss_brief().is_empty()).is_true()
	assert_bool(api.salvage_offer().is_empty()).is_true()
	assert_int(api.weapon_slot_count()).is_equal(1)
	var slot: Dictionary = api.weapon_slot(0)
	assert_str(str(slot["id"])).is_equal("pistol")
	assert_int(slot["state"]).is_equal(RunApi.SLOT_READY)
	assert_bool(api.weapon_slot(1).is_empty()).is_true()
	assert_int(api.active_slot()).is_equal(0)
	assert_int(api.event_charges(&"deadfall_strike")).is_equal(0)
	assert_int(api.call_block_reason(&"deadfall_strike")).is_equal(Reason.Id.WRONG_STATE)
	assert_int(api.active_events().size()).is_equal(0)
	assert_int(api.directive_stacks(&"hot_loads")).is_equal(0)
	assert_bool(api.build_tags().is_empty()).is_true()
	assert_int(api.boss_phase()).is_equal(0)
	assert_int(api.boss_phase_count()).is_equal(1)
	assert_int(api.run_seed()).is_equal(0)
	api.pick_directive(api.next_command_id(), 0)  # the base commands do nothing and do not fail
	api.continue_run()


func test_a_bound_sim_run_api_describes_the_legacy_weapon_as_slot_zero() -> void:
	var api: FakeRunApi = FakeRunApi.new()
	api.fake_weapon_id = &"smg"
	api.fake_magazine = 0
	api.fake_magazine_size = 30
	api.fake_reload_ticks_left = 40
	var slot: Dictionary = api.weapon_slot(0)  # no fake slots set: the base class builds it from the legacy queries
	assert_str(str(slot["id"])).is_equal("smg")
	assert_int(slot["size"]).is_equal(30)
	assert_int(slot["state"]).is_equal(RunApi.SLOT_RELOADING)
	assert_int(slot["ticks_left"]).is_equal(40)


func test_game_run_flow_fills_the_launch_fields() -> void:
	var cfg: SimConfig = SimConfig.create(c, 1)
	GameRunFlow.set_launch(&"k_standard", true)
	GameRunFlow.apply_launch(cfg, c)
	assert_int(cfg.kit_index).is_equal(0)
	assert_bool(cfg.daily).is_true()
	var next: SimConfig = SimConfig.create(c, 2)
	GameRunFlow.apply_launch(next, c)  # the pending launch was consumed
	assert_bool(next.daily).is_false()
	GameRunFlow.set_launch(&"k_unknown", false)
	GameRunFlow.apply_launch(next, c)
	assert_int(next.kit_index).is_equal(0)  # an unknown kit is the standard kit
	var legacy: SimConfig = SimConfig.create(TestContent.baseline(), 2)
	GameRunFlow.apply_launch(legacy, legacy.content)
	assert_int(legacy.kit_index).is_equal(0)
	assert_bool(GameRunFlow.resume_from_disk(null)).is_false()
	assert_bool(GameRunFlow.open_archive(null)).is_false()
