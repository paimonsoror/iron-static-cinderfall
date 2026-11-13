extends GdUnitTestSuite
## V4-T: the specialists in the field (CONTENT 13): `hoarder` swaps to its highest tier, `spammer` fires every ability and
## call the tick it is legal, `hoarder` and `turret_rush` play the abilities of `greedy`, `risk` those of `balanced`.
## Hand-made states on TestContent.variety().


func _only(w: SimWorld) -> SimCommand:
	assert_int(w.command_queue.size()).is_equal(1)
	return w.command_queue[0]


# --- swaps ---


func _armed(policy_weapons: Array[StringName], active: int) -> SimWorld:
	var w: SimWorld = VarietyHKit.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 2
	for slot: int in policy_weapons.size():
		VarietyHKit.carry(w, slot, policy_weapons[slot])
	w.arsenal.active = active
	w.tick = 600
	return w


func _swaps(policy: int, w: SimWorld) -> Array[int]:
	PolicyBot.new(policy).act(w)
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.SWAP_WEAPON:
			out.append(c.arg)
	return out


func test_hoarder_swaps_to_the_higher_tier_when_it_is_ready() -> void:
	assert_array(_swaps(PolicyBot.Policy.HOARDER, _armed([&"pistol", &"lmg"], 0))).is_equal([1])
	assert_array(_swaps(PolicyBot.Policy.HOARDER, _armed([&"pistol", &"lmg"], 1))).is_empty()  # already in hand
	assert_array(_swaps(PolicyBot.Policy.HOARDER, _armed([&"lmg", &"pistol"], 1))).is_equal([0])


func test_hoarder_waits_while_the_higher_tier_reloads_and_bridges_with_the_other_weapon() -> void:
	var reloading: SimWorld = _armed([&"pistol", &"lmg"], 0)
	reloading.arsenal.slot_reload_left[1] = 100
	assert_array(_swaps(PolicyBot.Policy.HOARDER, reloading)).is_empty()  # the lmg is not ready: stay on the pistol
	var spent: SimWorld = _armed([&"pistol", &"lmg"], 1)
	spent.arsenal.slot_reload_left[1] = 100
	assert_array(_swaps(PolicyBot.Policy.HOARDER, spent)).is_equal([0])  # long reload: fire the pistol meanwhile
	var nearly: SimWorld = _armed([&"pistol", &"lmg"], 1)
	nearly.arsenal.slot_reload_left[1] = 20
	assert_array(_swaps(PolicyBot.Policy.HOARDER, nearly)).is_empty()  # not worth a swap


func test_the_other_specialists_never_swap_but_risk_swaps_like_balanced() -> void:
	for policy: int in [PolicyBot.Policy.SPAMMER, PolicyBot.Policy.TURRET_RUSH, PolicyBot.Policy.GREEDY]:
		var w: SimWorld = _armed([&"pistol", &"arc_projector"], 0)
		VarietyHKit.crowd(w, 20, 3.0)
		assert_array(_swaps(policy, w)).is_empty()
	var risky: SimWorld = _armed([&"pistol", &"arc_projector"], 0)
	VarietyHKit.crowd(risky, 20, 3.0)
	assert_array(_swaps(PolicyBot.Policy.RISK, risky)).is_equal([1])


# --- abilities and calls ---


func _combat() -> SimWorld:
	var w: SimWorld = VarietyHKit.world()
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 2
	return w


func _used(w: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for c: SimCommand in w.command_queue:
		if c.kind == SimCommand.Kind.ABILITY:
			out.append(c.arg)
	return out


func test_spammer_fires_every_ability_the_tick_it_is_ready() -> void:
	var w: SimWorld = _combat()  # no enemy at all: it fires anyway
	PolicyBot.new(PolicyBot.Policy.SPAMMER).act(w)
	assert_array(_used(w)).is_equal([Ids.AB_EMP, Ids.AB_SHIELD, Ids.AB_OVERDRIVE])
	var cooling: SimWorld = _combat()
	cooling.abilities.cooldown_left[Ids.AB_EMP] = 90
	cooling.abilities.cooldown_left[Ids.AB_SHIELD] = 90
	PolicyBot.new(PolicyBot.Policy.SPAMMER).act(cooling)
	assert_array(_used(cooling)).is_equal([Ids.AB_OVERDRIVE])


func test_spammer_calls_the_strike_the_tick_the_sim_allows_it() -> void:
	var w: SimWorld = _combat()
	var strike: int = w.content.event_index(&"deadfall_strike")
	w.events_state.charges[strike] = 1
	PolicyBot.new(PolicyBot.Policy.SPAMMER).act(w)
	var calls: int = 0
	for c: SimCommand in w.command_queue:
		calls += 1 if c.kind == SimCommand.Kind.CALL_EVENT and c.arg == strike else 0
	assert_int(calls).is_equal(1 if EventSystem.block_reason(w, strike) == Reason.Id.OK else 0)
	var empty: SimWorld = _combat()
	empty.events_state.charges[strike] = 0
	PolicyBot.new(PolicyBot.Policy.SPAMMER).act(empty)
	for c: SimCommand in empty.command_queue:
		if c.kind == SimCommand.Kind.CALL_EVENT:  # another player event (core_vent) may be legal; the strike has no charge
			assert_int(c.arg).is_not_equal(strike)


func test_spammer_does_nothing_between_waves() -> void:
	var w: SimWorld = VarietyHKit.world()  # PREPARING
	PolicyBot.new(PolicyBot.Policy.SPAMMER).act(w)
	assert_array(w.command_queue).is_empty()


func test_hoarder_and_turret_rush_use_the_abilities_of_greedy() -> void:
	for policy: int in [PolicyBot.Policy.HOARDER, PolicyBot.Policy.TURRET_RUSH]:
		var w: SimWorld = _combat()
		VarietyHKit.crowd(w, 11, 3.0, true)
		PolicyBot.new(policy).act(w)
		assert_array(_used(w)).is_empty()  # EMP at 12, not 11
		VarietyHKit.crowd(w, 1, 3.0, true)
		PolicyBot.new(policy).act(w)
		assert_array(_used(w)).is_equal([Ids.AB_EMP])


func test_risk_uses_the_abilities_of_balanced() -> void:
	var w: SimWorld = _combat()
	VarietyHKit.crowd(w, 10, 3.0, true)
	PolicyBot.new(PolicyBot.Policy.RISK).act(w)
	assert_array(_used(w)).is_equal([Ids.AB_EMP])  # balanced fires the EMP at 10
