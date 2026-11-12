class_name VarietyAKit
extends RefCounted
## Helpers of the V2-A suites (run plan, wave builder, phase flow). Content is TestContent.variety() (WORK_PLAN rule 5);
## `long_content` stretches the slice to the 15 waves and 3 acts of CONTENT 1.1 so act and late-wave rules can be tested.


static func content() -> ContentSet:
	return TestContent.variety()


static func world(run_seed: int = 1, c: ContentSet = null) -> SimWorld:
	return SimWorld.new(SimConfig.create(c if c != null else content(), run_seed))


## The slice content with waves 6 to 15 added (acts II and III, bosses at 10 and 15) and a boss pool for each act.
static func long_content() -> ContentSet:
	var c: ContentSet = content()
	var budgets: Array[float] = [78.0, 92.0, 108.0, 124.0, 70.0, 140.0, 156.0, 172.0, 190.0, 120.0]
	var windows: Array[float] = [30.0, 32.0, 34.0, 36.0, 50.0, 36.0, 38.0, 40.0, 42.0, 60.0]
	for n: int in range(6, 16):
		var s: WaveSlotDef = WaveSlotDef.new()
		s.index = n
		s.act = 2 if n <= 10 else 3
		s.kind = WaveSlotDef.Kind.BOSS if n % 5 == 0 else WaveSlotDef.Kind.NORMAL
		s.budget = budgets[n - 6]
		s.window_ticks = roundi(windows[n - 6] * 60.0)
		s.peak_bodied = 40
		s.peak_minis = 20
		s.event_slots = 2 if n >= 12 and n <= 14 else 1
		c.run.waves.append(s)
	c.bosses.append(_boss(c, Ids.EN_AEGIS_ARRAY, 2))
	c.bosses.append(_boss(c, Ids.EN_HULK, 3))
	c.bosses[0].pool_act = 1
	return c


static func _boss(c: ContentSet, enemy_index: int, pool_act: int) -> BossDef:
	var b: BossDef = BossDef.new()
	b.id = c.enemies[enemy_index].id
	b.enemy_index = enemy_index
	b.pool_act = pool_act
	b.hp = c.enemies[enemy_index].hp
	b.escort_enemy = PackedInt32Array([Ids.EN_SKITTER, Ids.EN_RUSHER])
	b.escort_share = PackedFloat32Array([0.6, 0.4])
	return b


## A pack made of `enemies` with equal shares, all in the right region, starting at 0.
static func pack_of(c: ContentSet, id: StringName, enemies: PackedInt32Array, min_act: int = 1) -> PackDef:
	var p: PackDef = PackDef.new()
	p.id = id
	p.index = c.run.packs.size()
	p.min_act = min_act
	for e: int in enemies:
		p.group_enemy.append(e)
		p.group_share.append(1.0 / float(enemies.size()))
		p.group_region.append(&"right")
		p.group_start.append(0.0)
		p.group_tempo.append(1.0)
	c.run.packs.append(p)
	return p


static func slot(c: ContentSet, wave_number: int) -> WaveSlotDef:
	return c.run.wave_slot(wave_number)


## Total cost of the bodies of `groups`.
static func spent(c: ContentSet, groups: Array[SpawnGroupDef]) -> float:
	var sum: float = 0.0
	for g: SpawnGroupDef in groups:
		sum += float(g.count) * c.enemies[g.enemy_index].cost
	return sum


static func group(enemy_index: int, count: int, start_tick: int, interval_ticks: int, region: StringName) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.enemy_index = enemy_index
	g.count = count
	g.start_tick = start_tick
	g.interval_ticks = interval_ticks
	g.region_id = region
	return g


## Makes `groups` the first wave of the plan and begins it by hand (the nav-test way): SPAWNING, one tick, begin_wave and
## the spawn step of that tick. Returns the tick of wave tick 0.
static func start_wave(w: SimWorld, groups: Array[SpawnGroupDef]) -> int:
	w.plan.waves[0].options[0].groups = groups
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = 1
	w.tick += 1
	w.events.current_tick = w.tick
	SpawnSystem.begin_wave(w, 1)
	SpawnSystem.step(w)
	return w.tick


## `ticks` more spawn steps (no movement, no combat).
static func tick_spawn(w: SimWorld, ticks: int) -> void:
	for _k: int in ticks:
		w.tick += 1
		w.events.current_tick = w.tick
		SpawnSystem.step(w)


## `groups` without its first group (the boss of a boss wave).
static func tail(groups: Array[SpawnGroupDef]) -> Array[SpawnGroupDef]:
	var out: Array[SpawnGroupDef] = []
	for k: int in range(1, groups.size()):
		out.append(groups[k])
	return out


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


## Steps until the world awaits a choice or is over; false when `limit` steps were not enough. Kills every enemy
## before each step and counts the schedule as spawned, so a wave ends at once.
static func run_to_await(w: SimWorld, limit: int = 20000) -> bool:
	for _n: int in limit:
		if w.phase_state.awaiting != PhaseState.Await.NONE or w.is_over():
			w.phase_state.force_wave_spawned = false
			return w.phase_state.awaiting != PhaseState.Await.NONE
		if GameState.is_combat(w.phase):
			w.phase_state.force_wave_spawned = true
			kill_all(w)
		w.step()
	w.phase_state.force_wave_spawned = false
	return false


## Like `run_to_await`, but a salvage or a draft on the way is closed (through its system, with no command, so the
## command log and the tick stay those of the route tests): stops at the next ROUTE or BOSS_BRIEF await.
static func run_to_route(w: SimWorld, limit: int = 20000) -> bool:
	for _n: int in 12:
		if not run_to_await(w, limit):
			return false
		if not close_choice(w):
			return true
	return false


## Closes an open salvage (scrapped) or draft (skipped) through its system and moves the intermission on. False when
## the world waits for something else (a route, a boss briefing) or for nothing.
static func close_choice(w: SimWorld) -> bool:
	match w.phase_state.awaiting:
		PhaseState.Await.SALVAGE:
			SalvageSystem.resolve(w, 0, SalvageSystem.ACTION_SCRAP)
		PhaseState.Await.DRAFT:
			DraftSystem.skip(w, 0)
		_:
			return false
	PhaseSystem.advance_await(w)
	return true


static func kill_all(w: SimWorld) -> void:
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1:
			w.kill_enemy(i, DamageSource.Id.WARDEN)


## One answer of a trivial bot to the current await: ROUTE picks `route_pick`, BOSS_BRIEF continues, DRAFT and SALVAGE
## are closed through their systems (`close_choice`: skipped, scrapped). Returns false when nothing awaits.
static func answer(w: SimWorld, command_id: int, route_pick: int = 0) -> bool:
	match w.phase_state.awaiting:
		PhaseState.Await.ROUTE:
			w.submit(SimCommand.pick_route(command_id, route_pick))
		PhaseState.Await.BOSS_BRIEF:
			w.submit(SimCommand.skip(command_id))
		PhaseState.Await.DRAFT, PhaseState.Await.SALVAGE:
			close_choice(w)
		_:
			return false
	w.step()
	return true


## Plays a whole run with a bot that answers every route and boss briefing at once (drafts and crates on the way are
## closed, `run_to_route`); `think` ticks of waiting precede each answer. Returns the number of waits answered.
static func play(w: SimWorld, think: int, route_pick: int = 0, max_waits: int = 60) -> int:
	var answered: int = 0
	var command_id: int = 1
	while answered < max_waits and not w.is_over():
		if not run_to_route(w):
			break
		for _t: int in think:
			w.step()
		answer(w, command_id, route_pick)
		command_id += 1
		answered += 1
		w.events.drain()
	return answered


## Like `play` but nothing is cheated: the Warden and the turrets fight the waves, and the bot only sends commands (so the
## command log is a complete record and `Replay.run` can reproduce the run). Stops at the first await it has answered
## `answers` routes or boss briefings or after `max_ticks` (a draft is skipped and a crate scrapped by command on the
## way, and not counted). Returns the route and briefing answers sent.
static func play_natural(w: SimWorld, think: int, route_pick: int, answers: int = 1, max_ticks: int = 60000) -> int:
	var sent: int = 0
	var command_id: int = 1
	for _n: int in max_ticks:
		if w.is_over() or sent >= answers:
			break
		if w.phase_state.awaiting == PhaseState.Await.NONE:
			w.step()
			continue
		for _t: int in think:
			w.step()
		match w.phase_state.awaiting:
			PhaseState.Await.ROUTE:
				w.submit(SimCommand.pick_route(command_id, route_pick))
				sent += 1
			PhaseState.Await.BOSS_BRIEF:
				w.submit(SimCommand.skip(command_id))
				sent += 1
			PhaseState.Await.DRAFT:
				w.submit(SimCommand.skip_draft(command_id))
			PhaseState.Await.SALVAGE:
				w.submit(SimCommand.salvage(command_id, 0, SalvageSystem.ACTION_SCRAP))
		command_id += 1
		w.step()
	return sent
