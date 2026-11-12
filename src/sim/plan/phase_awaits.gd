class_name PhaseAwaits
extends RefCounted
## The intermission of a generated run (VARIETY_SPEC 2.5, ARCH 4.1), for PhaseSystem: the wave-clear effects, the walk
## through SALVAGE, DRAFT and ROUTE or BOSS_BRIEF, the breather, and what happens when a wave starts (act, modifier,
## events). Every function is a no-op without a plan, so the legacy 5-wave run never reaches this code.
##
## Order after a wave clear: effects first (the route reward, the act-clear repair), then the first await that applies.
## `advance` moves on from the await that was just answered and is idempotent: it does nothing while the current await is
## still pending. It is called by the wave clear, by PhaseSystem.pre_step (a system that answered its await by setting
## `awaiting` to NONE, as DraftSystem does, is picked up on the same tick) and by PhaseSystem.advance_await, which
## CommandSystem calls after the commands whose system cannot release its await itself (SALVAGE).

## CONTENT 1.1: a boss wave repairs the core by this fraction of its maximum.
const ACT_CLEAR_REPAIR_FRAC: float = 0.15
## CONTENT 7.1: the crate of the `rw_crate` reward drops at this fraction of the wave window.
const CRATE_DROP_WINDOW_FRAC: float = 0.4


## Sets `PhaseState.awaiting` and pushes AWAIT_CHANGED(new, previous). The only place that writes it.
static func set_await(world: SimWorld, kind: int) -> void:
	var ps: PhaseState = world.phase_state
	if ps.awaiting == kind:
		return
	var previous: int = ps.awaiting
	ps.awaiting = kind
	world.events.push(SimEventKind.Id.AWAIT_CHANGED, kind, previous)


## Wave `world.wave` is starting: its act (ACT_STARTED when it changes, and at wave 1), its modifier, its events.
static func begin_wave(world: SimWorld) -> void:
	var ps: PhaseState = world.phase_state
	ps.breather = false
	ps.drafted = false
	set_await(world, PhaseState.Await.NONE)
	var pw: PlannedWave = world.plan.wave(world.wave)
	if pw == null:
		return
	if world.wave == 1 or pw.act != ps.act:
		ps.act = pw.act
		world.events.push(SimEventKind.Id.ACT_STARTED, pw.act)
	var option: RouteOption = world.plan.option(world.wave)
	ModSystem.set_wave_modifier(world, option.modifier_index if option != null else -1)
	EventSystem.begin_wave(world, world.wave)


## The intermission begins (a wave was cleared): the wave-clear effects, before the first await. They are the route reward
## of the option that spawned (its crate is dropped during the wave instead, see `on_wave_tick`) and, after a boss wave,
## the act-clear repair.
static func begin_intermission(world: SimWorld) -> void:
	world.phase_state.drafted = false
	world.phase_state.breather = false
	var option: RouteOption = world.plan.option(world.wave)
	if option != null and option.reward_index >= 0:
		var ops: Array[OpDef] = []
		for op: OpDef in world.content.run.route_rewards[option.reward_index].ops:
			if not _is_crate(op):
				ops.append(op)
		if not ops.is_empty():
			ModSystem.grant(world, ops)
	var pw: PlannedWave = world.plan.wave(world.wave)
	if pw != null and pw.is_boss:
		var repair: OpDef = OpDef.new()
		repair.kind = OpDef.Kind.GRANT
		repair.target = &"core_repair_frac"
		repair.value = ACT_CLEAR_REPAIR_FRAC
		var list: Array[OpDef] = [repair]
		ModSystem.grant(world, list)


## Each tick of a combat phase: drops the field crate of an `rw_crate` reward at 40 percent of the wave window.
static func on_wave_tick(world: SimWorld) -> void:
	var option: RouteOption = world.plan.option(world.wave)
	var slot: WaveSlotDef = world.content.run.wave_slot(world.wave)
	if option == null or slot == null or option.reward_index < 0 or world.wave >= world.stats.wave_start_tick.size():
		return
	var at: int = world.stats.wave_start_tick[world.wave] + roundi(CRATE_DROP_WINDOW_FRAC * float(slot.window_ticks))
	if world.tick != at:
		return
	var has_crate: bool = false
	for op: OpDef in world.content.run.route_rewards[option.reward_index].ops:
		has_crate = has_crate or _is_crate(op)
	var points: int = world.content.arena.drop_points.size()
	if has_crate and points > 0:
		SalvageSystem.drop_crate(world, world.wave % points, false)


## Moves the intermission on from the await that was just answered (see the class comment). Fresh (just cleared): the
## salvage of the banked crates, then the draft, then the route choice or the boss briefing of the next wave, then the
## breather. A step the content or the systems do not offer (no crate, no draft opened, a single option) is skipped.
static func advance(world: SimWorld) -> void:
	if world.plan == null or world.phase != GameState.Id.INTERMISSION:
		return
	var ps: PhaseState = world.phase_state
	if ps.breather:
		return
	match ps.awaiting:
		PhaseState.Await.ROUTE, PhaseState.Await.BOSS_BRIEF:
			return
		PhaseState.Await.SALVAGE:
			if not world.salvage.offer.is_empty():
				return
		PhaseState.Await.DRAFT:
			if world.draft.open:
				return
	if not ps.drafted:
		if SalvageSystem.open_next(world):
			set_await(world, PhaseState.Await.SALVAGE)
			return
		DraftSystem.open(world)
		ps.drafted = true
		if world.draft.open:
			set_await(world, PhaseState.Await.DRAFT)
			return
	_open_next_wave_choice(world)


## Leaves every await and starts the breather countdown (`breather_ticks`, at least one tick).
static func enter_breather(world: SimWorld) -> void:
	set_await(world, PhaseState.Await.NONE)
	world.phase_state.breather = true
	world.phase_ticks_left = maxi(1, world.content.mission.breather_ticks)


static func _open_next_wave_choice(world: SimWorld) -> void:
	var next_wave: int = world.wave + 1
	var pw: PlannedWave = world.plan.wave(next_wave)
	if pw == null:
		enter_breather(world)
	elif pw.is_boss:
		var boss_index: int = world.plan.boss_ids[pw.act - 1] if pw.act - 1 < world.plan.boss_ids.size() else -1
		world.events.push(SimEventKind.Id.BOSS_BRIEFED, next_wave, boss_index)
		set_await(world, PhaseState.Await.BOSS_BRIEF)
	elif pw.options.size() > 1:
		world.events.push(SimEventKind.Id.ROUTE_OFFERED, next_wave, pw.options.size())
		set_await(world, PhaseState.Await.ROUTE)
	else:
		enter_breather(world)


static func _is_crate(op: OpDef) -> bool:
	return op.kind == OpDef.Kind.GRANT and op.target == &"crate"
