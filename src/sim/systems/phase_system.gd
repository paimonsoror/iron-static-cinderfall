class_name PhaseSystem
extends RefCounted
## Run phases and win/lose flow (ARCH 6.6 "Economy, abilities, flow"). The only writer of phase, wave,
## waves_completed, phase_ticks_left and (through PhaseAwaits) PhaseState.awaiting, act and breather.
##
## PREPARING (prepare_ticks) -> wave n SPAWNING -> CLEARING -> INTERMISSION (intermission_ticks) -> wave n + 1 ...
## -> VICTORY after the last wave is cleared. DEFEAT the tick core_hp <= 0, checked before any wave-clear logic.
## At most one phase change per call of pre_step or post_step. Terminal phases push RUN_FINISHED exactly once.
##
## `world.wave` stays at n through CLEARING and the INTERMISSION after it, and becomes n + 1 when that wave starts.
## SpawnSystem.begin_wave receives the 1-based wave number (the same value as `world.wave` and WAVE_STARTED.a).
##
## A generated run (`world.plan != null`, VARIETY_SPEC 2.5) replaces the countdown of the INTERMISSION by the awaits
## SALVAGE, DRAFT, ROUTE or BOSS_BRIEF (the simulation holds its tick, SimWorld.step) and a short breather. The wave count
## comes from the plan. The legacy 5-wave content has no plan and keeps the old behaviour exactly.
##
## CONTRACT FOR THE DRAFT AND SALVAGE AWAITS. PhaseSystem opens them (`DraftSystem.open`, `SalvageSystem.open_next`) and
## goes on when they are answered: the draft is answered when `draft.open` is false, a salvage when `salvage.offer` is
## empty. Two ways reach that point. A system may release its own await (DraftSystem sets `awaiting` to NONE, and the
## same tick's pre_step goes on). Otherwise the command layer must call `PhaseSystem.advance_await(world)` after the
## applied commands (SimWorld.step stops at a held await, so nothing else would notice that SalvageSystem.resolve emptied
## the offer). The call is idempotent and safe at any time.


## PREPARING with prepare_ticks (the phase itself is the SimWorld default).
static func init_world(world: SimWorld) -> void:
	world.wave = 0
	world.phase_ticks_left = world.content.mission.prepare_ticks


## Tick step 3: PREPARING and INTERMISSION count down; at 0 the next wave starts. With a plan the INTERMISSION counts
## only in the breather, and a combat tick may drop the crate of a route reward.
static func pre_step(world: SimWorld) -> void:
	if world.plan != null and GameState.is_combat(world.phase):
		PhaseAwaits.on_wave_tick(world)
		return
	if world.phase != GameState.Id.PREPARING and world.phase != GameState.Id.INTERMISSION:
		return
	if world.plan != null and world.phase == GameState.Id.INTERMISSION and not world.phase_state.breather:
		PhaseAwaits.advance(world)  # an await that its system released (awaiting back to NONE) goes on at once
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


## Ends INTERMISSION now and starts the next wave (the breather skip). With a plan, the CONTINUE button of the boss
## briefing is also a skip (it starts the breather); a pending salvage, draft or route choice cannot be skipped.
## Returns a Reason.Id (WRONG_STATE outside INTERMISSION).
static func skip_intermission(world: SimWorld) -> int:
	if world.phase != GameState.Id.INTERMISSION:
		return Reason.Id.WRONG_STATE
	if world.plan != null:
		var ps: PhaseState = world.phase_state
		if ps.awaiting == PhaseState.Await.BOSS_BRIEF:
			PhaseAwaits.enter_breather(world)
			return Reason.Id.OK
		if ps.awaiting != PhaseState.Await.NONE or not ps.breather:
			return Reason.Id.WRONG_STATE
	_start_next_wave(world)
	return Reason.Id.OK


## PICK_ROUTE (VARIETY_SPEC 2.4): records the option in RunPlan.chosen and leaves the ROUTE await for the breather.
## Returns a Reason.Id: NOT_AWAITING outside the ROUTE await, INVALID_CHOICE for an option the wave does not have.
static func pick_route(world: SimWorld, _command_id: int, option: int) -> int:
	if world.plan == null or world.phase_state.awaiting != PhaseState.Await.ROUTE:
		return Reason.Id.NOT_AWAITING
	var next_wave: int = world.wave + 1
	var pw: PlannedWave = world.plan.wave(next_wave)
	if pw == null or option < 0 or option >= pw.options.size():
		return Reason.Id.INVALID_CHOICE
	world.plan.chosen[next_wave - 1] = option
	if next_wave < world.stats.route_choices.size():
		world.stats.route_choices[next_wave] = option
	world.events.push(SimEventKind.Id.ROUTE_PICKED, next_wave, option)
	PhaseAwaits.enter_breather(world)
	return Reason.Id.OK


## Moves the intermission on after a draft or salvage choice finished (see the class comment). Safe to call at any time:
## it does nothing while a choice is still pending, outside the INTERMISSION and without a plan.
static func advance_await(world: SimWorld) -> void:
	PhaseAwaits.advance(world)


## Waves in the run: the plan's, or the scripted waves of the legacy content.
static func wave_count(world: SimWorld) -> int:
	return world.plan.wave_count() if world.plan != null else world.content.waves.size()


static func _start_next_wave(world: SimWorld) -> void:
	world.wave += 1
	world.phase_ticks_left = 0
	if world.plan != null:
		PhaseAwaits.begin_wave(world)
	world.set_phase(GameState.Id.SPAWNING)
	if world.wave < world.stats.wave_start_tick.size():
		world.stats.wave_start_tick[world.wave] = world.tick
	SpawnSystem.begin_wave(world, world.wave)
	var total: int = 0
	if world.plan != null:
		var option: RouteOption = world.plan.option(world.wave)
		total = option.total_count() if option != null else 0
	elif world.wave >= 1 and world.wave <= world.content.waves.size():
		total = world.content.waves[world.wave - 1].total_count()
	world.events.push(SimEventKind.Id.WAVE_STARTED, world.wave, total)


## Every scheduled enemy is dead: count the wave and move to INTERMISSION, or to VICTORY after the last wave.
static func _clear_wave(world: SimWorld) -> void:
	world.waves_completed += 1
	if world.wave < world.stats.wave_clear_tick.size():
		world.stats.wave_clear_tick[world.wave] = world.tick
	world.events.push(SimEventKind.Id.WAVE_CLEARED, world.wave)
	if world.wave >= wave_count(world):
		world.set_phase(GameState.Id.VICTORY)
		_finish_run(world)
		return
	world.set_phase(GameState.Id.INTERMISSION)
	if world.plan == null:
		world.phase_ticks_left = world.content.mission.intermission_ticks
		world.events.push(SimEventKind.Id.INTERMISSION_STARTED, world.wave, world.phase_ticks_left)
		return
	world.phase_ticks_left = 0
	PhaseAwaits.begin_intermission(world)
	world.events.push(SimEventKind.Id.INTERMISSION_STARTED, world.wave, 0)
	PhaseAwaits.advance(world)


## Active abilities end, then RUN_FINISHED (result, waves completed, core hp), once per run.
static func _finish_run(world: SimWorld) -> void:
	world.phase_ticks_left = 0
	if world.phase_state.run_finished:
		return
	world.phase_state.run_finished = true
	AbilitySystem.end_all(world)
	world.events.push(SimEventKind.Id.RUN_FINISHED, world.result(), world.waves_completed, world.core_hp)
