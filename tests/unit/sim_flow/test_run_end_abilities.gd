extends GdUnitTestSuite
## W3-A: an ability that is still active on the tick the run ends is ended at once (ABILITY_ENDED, shield 0). The sim
## does not step after the run, so before this fix `active_left` stayed above 0 forever and a results screen reading
## `is_active` would have shown a stale value.


## SPAWNING world with the shield up and a Hulk standing in its slot, one tick from its hit (90 damage per hit).
func _shield_and_a_killer(core_hp: float, shield_hp: float) -> SimWorld:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.SPAWNING, 2)
	w.submit(SimCommand.ability(1, Ids.AB_SHIELD))
	w.step()
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_true()
	var hulk: int = FlowKit.spawn(w, Ids.EN_HULK)
	w.enemies.state[hulk] = EnemyStore.ST_ATTACKING
	w.enemies.attack_cd[hulk] = 1
	w.shield_hp = shield_hp
	w.set_core_hp(core_hp)
	w.events.drain()
	return w


func test_a_shield_emptied_by_the_killing_blow_is_not_left_active() -> void:
	var w: SimWorld = _shield_and_a_killer(40.0, 30.0)  # 30 absorbed, 60 through: the core falls with the shield gone
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_float(w.core_hp).is_equal(0.0)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.active_left[Ids.AB_SHIELD]).is_equal(0)


func test_ending_the_shield_at_the_end_of_the_run_pushes_one_ability_ended_before_run_finished() -> void:
	var w: SimWorld = _shield_and_a_killer(40.0, 30.0)
	w.step()
	var ended: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.ABILITY_ENDED)
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0].a).is_equal(Ids.AB_SHIELD)
	assert_int(FlowKit.count(w, SimEventKind.Id.RUN_FINISHED)).is_equal(1)
	var kinds: Array[int] = []
	for e: SimEvent in w.events.peek():
		kinds.append(e.kind)
	assert_bool(kinds.find(SimEventKind.Id.ABILITY_ENDED) < kinds.find(SimEventKind.Id.RUN_FINISHED)).is_true()
	var shield_events: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.SHIELD_CHANGED)
	assert_float(shield_events[shield_events.size() - 1].f).is_equal(0.0)  # the dome goes away in the view


func test_an_overdrive_that_outlives_the_last_enemy_ends_with_the_victory() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	w.waves_completed = 4
	w.submit(SimCommand.ability(1, Ids.AB_OVERDRIVE))
	w.step()  # the command is applied, then the last wave counts as cleared: nothing is alive
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_bool(w.abilities.is_active(Ids.AB_OVERDRIVE)).is_false()
	assert_int(w.abilities.active_left[Ids.AB_OVERDRIVE]).is_equal(0)
	var ended: Array[SimEvent] = FlowKit.events_of(w, SimEventKind.Id.ABILITY_ENDED)
	assert_int(ended.size()).is_equal(1)
	assert_int(ended[0].a).is_equal(Ids.AB_OVERDRIVE)


func test_a_run_that_ends_with_nothing_active_pushes_no_ability_ended() -> void:
	var w: SimWorld = FlowKit.in_phase(GameState.Id.CLEARING, 5)
	w.waves_completed = 4
	w.step()
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ENDED)).is_equal(0)
	assert_int(FlowKit.count(w, SimEventKind.Id.RUN_FINISHED)).is_equal(1)


func test_the_finished_world_stays_frozen_after_its_abilities_ended() -> void:
	var w: SimWorld = _shield_and_a_killer(40.0, 30.0)
	w.step()
	var frozen: String = w.state_hash()
	var cooldown: int = w.abilities.cooldown_left[Ids.AB_SHIELD]
	FlowKit.step_n(w, 600)
	assert_str(w.state_hash()).is_equal(frozen)
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(cooldown)
	assert_int(FlowKit.count(w, SimEventKind.Id.RUN_FINISHED)).is_equal(1)
	assert_int(FlowKit.count(w, SimEventKind.Id.ABILITY_ENDED)).is_equal(1)
