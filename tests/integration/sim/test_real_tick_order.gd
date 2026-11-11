extends GdUnitTestSuite
## Wave 1 findings the units could not check because they stepped one system at a time: here every tick is the
## real `world.step()` order. Lab worlds (frozen baseline, nothing spawns, enemies placed by the test).


## Called after every step with the tick's drained events; returns false to stop the run early.
class Watch:
	extends RefCounted

	func after(_world: SimWorld, _events: Array[SimEvent]) -> bool:
		return true


## Follows the shield through the tick that empties it and the one after.
class ShieldWatch:
	extends Watch
	var prev: float = 0.0
	var depleted_at: int = -1
	var ended_at: int = -1
	var absorbed: float = 0.0
	var hp_loss: float = 0.0
	var went_negative: bool = false
	var ended_events_on_depletion_tick: int = -1
	var still_flagged_on_depletion_tick: bool = false

	func after(world: SimWorld, events: Array[SimEvent]) -> bool:
		if world.shield_hp < 0.0:
			went_negative = true
		for e: SimEvent in events:
			if e.kind == SimEventKind.Id.CORE_HIT:
				absorbed += e.g
				hp_loss += e.f
			if e.kind == SimEventKind.Id.ABILITY_ENDED and e.a == Ids.AB_SHIELD:
				ended_at = world.tick
		if prev > 0.0 and world.shield_hp == 0.0 and depleted_at < 0:
			depleted_at = world.tick
			ended_events_on_depletion_tick = HarnessKit.count_of(events, SimEventKind.Id.ABILITY_ENDED)
			still_flagged_on_depletion_tick = world.abilities.is_active(Ids.AB_SHIELD)
		prev = world.shield_hp
		return ended_at < 0


class UntilOver:
	extends Watch
	var finished: Array[SimEvent] = []

	func after(world: SimWorld, events: Array[SimEvent]) -> bool:
		for e: SimEvent in events:
			if e.kind == SimEventKind.Id.RUN_FINISHED:
				finished.append(e)
		return not world.is_over()


func _run(w: SimWorld, limit: int, watch: Watch) -> void:
	for t: int in limit:
		w.step()
		if not watch.after(w, w.events.drain()):
			return


func test_the_shield_is_cleared_the_tick_after_the_core_attack_empties_it() -> void:
	var w: SimWorld = HarnessKit.lab_world()
	w.submit(SimCommand.ability(1, Ids.AB_SHIELD))
	HarnessKit.garrison(w, 12)
	var watch: ShieldWatch = ShieldWatch.new()
	_run(w, 600, watch)
	assert_bool(watch.went_negative).is_false()
	assert_int(watch.depleted_at).is_greater(0)
	# the hit that emptied the shield did so on a tick where the ability was still flagged on and had not ended
	assert_int(watch.ended_events_on_depletion_tick).is_equal(0)
	assert_bool(watch.still_flagged_on_depletion_tick).is_true()
	# AbilitySystem (step 5) sees shield_hp == 0 on the very next tick and ends the ability
	assert_int(watch.ended_at).is_equal(watch.depleted_at + 1)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_bool(w.abilities.is_active(Ids.AB_SHIELD)).is_false()
	assert_int(w.abilities.cooldown_left[Ids.AB_SHIELD]).is_equal(w.content.abilities[Ids.AB_SHIELD].cooldown_ticks)
	assert_float(watch.absorbed).is_equal(100.0)  # exactly the shield, never more
	assert_float(w.stats.damage_absorbed).is_equal(100.0)
	assert_float(watch.hp_loss).is_greater(0.0)  # the overflow of the emptying hit reached the core
	assert_float(w.core_max_hp - w.core_hp).is_equal(watch.hp_loss)


func test_a_new_shield_is_refused_while_the_old_one_cools_down() -> void:
	var w: SimWorld = HarnessKit.lab_world()
	w.submit(SimCommand.ability(1, Ids.AB_SHIELD))
	HarnessKit.garrison(w, 12)
	_run(w, 600, ShieldWatch.new())
	assert_float(w.shield_hp).is_equal(0.0)
	w.submit(SimCommand.ability(2, Ids.AB_SHIELD))
	w.step()
	var events: Array[SimEvent] = w.events.drain()
	var rejected: SimEvent = HarnessKit.first_of(events, SimEventKind.Id.ABILITY_REJECTED)
	assert_object(rejected).is_not_null()
	assert_int(rejected.b).is_equal(Reason.Id.ON_COOLDOWN)
	assert_float(w.shield_hp).is_equal(0.0)


func test_the_core_dying_ends_the_run_once_with_defeat() -> void:
	var w: SimWorld = HarnessKit.lab_world()
	w.set_core_hp(30.0)
	HarnessKit.garrison(w, 12)
	var watch: UntilOver = UntilOver.new()
	_run(w, 600, watch)
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_float(w.core_hp).is_equal(0.0)
	assert_float(w.shield_hp).is_equal(0.0)
	assert_int(w.alive_count()).is_equal(12)  # the garrison cannot die; the run ended anyway
	assert_int(watch.finished.size()).is_equal(1)
	assert_int(watch.finished[0].a).is_equal(RunResult.Id.DEFEAT)
	assert_int(watch.finished[0].b).is_equal(0)
	assert_float(watch.finished[0].f).is_equal(0.0)
	assert_bool(w.phase_state.run_finished).is_true()
	# a finished world stays finished: no tick, no event, no second RUN_FINISHED
	var tick: int = w.tick
	var total: int = w.events.total
	for n: int in 10:
		w.step()
	assert_int(w.tick).is_equal(tick)
	assert_int(w.events.total).is_equal(total)


func _last_enemy_world(core: float) -> SimWorld:
	var w: SimWorld = HarnessKit.lab_world()
	w.wave = 5
	w.phase_state.force_wave_spawned = true
	w.set_phase(GameState.Id.CLEARING)
	var i: int = w.spawn_enemy(Ids.EN_SKITTER, w.warden.x + 3.0, w.warden.z)
	w.enemies.hp[i] = 1.0
	w.warden.fire_acc_milli = 60000  # the first shot is due this tick
	w.set_core_hp(core)
	w.events.drain()
	return w


func test_the_last_enemy_dying_on_the_tick_the_core_is_at_zero_is_a_defeat_not_a_victory() -> void:
	var w: SimWorld = _last_enemy_world(0.0)
	w.step()
	var events: Array[SimEvent] = w.events.drain()
	assert_int(HarnessKit.count_of(events, SimEventKind.Id.ENEMY_KILLED)).is_equal(1)  # it did die this tick
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.result()).is_equal(RunResult.Id.DEFEAT)
	assert_int(w.waves_completed).is_equal(0)  # the wave was not counted as cleared
	assert_int(HarnessKit.count_of(events, SimEventKind.Id.WAVE_CLEARED)).is_equal(0)
	assert_int(HarnessKit.count_of(events, SimEventKind.Id.RUN_FINISHED)).is_equal(1)
	assert_int(HarnessKit.first_of(events, SimEventKind.Id.RUN_FINISHED).a).is_equal(RunResult.Id.DEFEAT)


func test_the_same_kill_with_a_live_core_is_the_victory() -> void:
	var w: SimWorld = _last_enemy_world(1000.0)
	w.step()
	var events: Array[SimEvent] = w.events.drain()
	assert_int(w.alive_count()).is_equal(0)
	assert_int(w.phase).is_equal(GameState.Id.VICTORY)
	assert_int(w.waves_completed).is_equal(1)
	assert_int(HarnessKit.first_of(events, SimEventKind.Id.RUN_FINISHED).a).is_equal(RunResult.Id.VICTORY)


func test_a_lethal_hit_from_the_last_attacker_ends_the_run_with_it_alive() -> void:
	# The only way the core dies in real tick order: an enemy that is still alive hits it (step 9), so DEFEAT is
	# reached with that enemy alive and the wave cannot clear.
	var w: SimWorld = HarnessKit.lab_world()
	w.set_core_hp(5.0)
	HarnessKit.garrison(w, 1)
	_run(w, 400, UntilOver.new())
	assert_int(w.phase).is_equal(GameState.Id.DEFEAT)
	assert_int(w.alive_count()).is_equal(1)
	assert_int(w.waves_completed).is_equal(0)
