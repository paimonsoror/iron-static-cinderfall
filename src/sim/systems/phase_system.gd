class_name PhaseSystem
extends RefCounted
## Run phases and win/lose flow (ARCH 6.6 "Economy, abilities, flow"). The only writer of phase, wave,
## waves_completed and phase_ticks_left.
##
## PREPARING (prepare_ticks) -> wave n SPAWNING -> CLEARING -> INTERMISSION (intermission_ticks) -> wave n + 1 ...
## -> VICTORY after the last wave is cleared. DEFEAT the tick core_hp <= 0, checked before any wave-clear logic.
## At most one phase change per call of pre_step or post_step. Terminal phases push RUN_FINISHED exactly once.
##
## `world.wave` stays at n through CLEARING and the INTERMISSION after it, and becomes n + 1 when that wave starts.
## SpawnSystem.begin_wave receives the 1-based wave number (the same value as `world.wave` and WAVE_STARTED.a).


## PREPARING with prepare_ticks (the phase itself is the SimWorld default).
static func init_world(world: SimWorld) -> void:
	world.wave = 0
	world.phase_ticks_left = world.content.mission.prepare_ticks


## Tick step 3: PREPARING and INTERMISSION count down; at 0 the next wave starts.
static func pre_step(world: SimWorld) -> void:
	if world.phase != GameState.Id.PREPARING and world.phase != GameState.Id.INTERMISSION:
		return
	world.phase_ticks_left = maxi(0, world.phase_ticks_left - 1)
	if world.phase_ticks_left == 0:
		_start_next_wave(world)


## Tick step 10: DEFEAT first, then SPAWNING -> CLEARING, then CLEARING -> INTERMISSION or VICTORY.
static func post_step(world: SimWorld) -> void:
	var phase: int = world.phase
	if phase != GameState.Id.SPAWNING and phase != GameState.Id.CLEARING:
		return
	if world.core_hp <= 0.0:
		world.set_phase(GameState.Id.DEFEAT)
		_finish_run(world)
	elif phase == GameState.Id.SPAWNING:
		if world.phase_state.force_wave_spawned or SpawnSystem.is_wave_fully_spawned(world):
			world.set_phase(GameState.Id.CLEARING)
	elif world.alive_count() == 0:
		_clear_wave(world)


## Ends INTERMISSION now and starts the next wave. Returns a Reason.Id (WRONG_STATE outside INTERMISSION).
static func skip_intermission(world: SimWorld) -> int:
	if world.phase != GameState.Id.INTERMISSION:
		return Reason.Id.WRONG_STATE
	_start_next_wave(world)
	return Reason.Id.OK


static func _start_next_wave(world: SimWorld) -> void:
	world.wave += 1
	world.phase_ticks_left = 0
	world.set_phase(GameState.Id.SPAWNING)
	if world.wave < world.stats.wave_start_tick.size():
		world.stats.wave_start_tick[world.wave] = world.tick
	SpawnSystem.begin_wave(world, world.wave)
	var total: int = 0
	if world.wave >= 1 and world.wave <= world.content.waves.size():
		total = world.content.waves[world.wave - 1].total_count()
	world.events.push(SimEventKind.Id.WAVE_STARTED, world.wave, total)


## Every scheduled enemy is dead: count the wave and move to INTERMISSION, or to VICTORY after the last wave.
static func _clear_wave(world: SimWorld) -> void:
	world.waves_completed += 1
	if world.wave < world.stats.wave_clear_tick.size():
		world.stats.wave_clear_tick[world.wave] = world.tick
	world.events.push(SimEventKind.Id.WAVE_CLEARED, world.wave)
	if world.wave >= world.content.waves.size():
		world.set_phase(GameState.Id.VICTORY)
		_finish_run(world)
		return
	world.set_phase(GameState.Id.INTERMISSION)
	world.phase_ticks_left = world.content.mission.intermission_ticks
	world.events.push(SimEventKind.Id.INTERMISSION_STARTED, world.wave, world.phase_ticks_left)


## Active abilities end, then RUN_FINISHED (result, waves completed, core hp), once per run.
static func _finish_run(world: SimWorld) -> void:
	world.phase_ticks_left = 0
	if world.phase_state.run_finished:
		return
	world.phase_state.run_finished = true
	AbilitySystem.end_all(world)
	world.events.push(SimEventKind.Id.RUN_FINISHED, world.result(), world.waves_completed, world.core_hp)
