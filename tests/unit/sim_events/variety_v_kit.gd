class_name VarietyVKit
extends RefCounted
## Helpers for tests/unit/sim_events (task V4-V). Worlds come from TestContent.variety() only. Enemies are placed with
## spawn_enemy and the systems are stepped directly, in the order of SimWorld.step (events, abilities, turrets,
## hazards), so these tests do not depend on movement, spawning or the phase flow. Event indices are those of events.json.

const STRIKE: int = 0
const VENT: int = 1
const FREIGHT: int = 2
const ACCORD: int = 3
const DROP: int = 4
const SURGE: int = 5
const RUNAWAY: int = 6
const STATIC: int = 7
const BREACH: int = 8
const RECOUNT: int = 9
const TOUGH_HP: float = 1.0e9


## A variety world in a combat phase, in wave `wave` of the plan (its act is taken from the plan); `long_run` gives the
## 15-wave, three-act content of long_content.
static func world(run_seed: int = 1, wave: int = 4, long_run: bool = false) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfig.create(long_content() if long_run else TestContent.variety(), run_seed))
	w.phase = GameState.Id.SPAWNING
	begin_wave(w, wave)
	return w


## Starts wave `wave` as PhaseSystem does for the events: the wave number, the act, the start tick, EventSystem.begin_wave.
static func begin_wave(w: SimWorld, wave: int) -> void:
	w.wave = wave
	w.stats.wave_start_tick[wave] = w.tick
	w.phase_state.act = w.plan.wave(wave).act
	EventSystem.begin_wave(w, wave)


## Removes the planned events of every wave (the tests plan their own).
static func clear_plan(w: SimWorld) -> void:
	for pw: PlannedWave in w.plan.waves:
		pw.events.clear()


## Plans `event_index` in wave `wave`, its warning `offset` ticks after the wave starts.
static func plan_event(w: SimWorld, wave: int, event_index: int, offset: int) -> void:
	var pe: PlannedEvent = PlannedEvent.new()
	pe.event_index = event_index
	pe.start_offset = offset
	var events: Array[PlannedEvent] = w.plan.wave(wave).events
	events.append(pe)
	events.sort_custom(func(a: PlannedEvent, b: PlannedEvent) -> bool: return a.start_offset < b.start_offset)


static func place(w: SimWorld, type_index: int, x: float, z: float, state: int = EnemyStore.ST_MOVING) -> int:
	var i: int = w.spawn_enemy(type_index, x, z)
	w.enemies.state[i] = state
	w.enemies.path_dist[i] = 100.0
	return i


static func tough(w: SimWorld, index: int) -> void:
	w.enemies.hp[index] = TOUGH_HP
	w.enemies.max_hp[index] = TOUGH_HP


static func taken(w: SimWorld, index: int) -> float:
	return w.enemies.max_hp[index] - w.enemies.hp[index]


## One tick in the order of SimWorld.step for the systems of this task (no movement, spawning or weapons).
static func tick(w: SimWorld) -> void:
	w.tick += 1
	w.events.current_tick = w.tick
	EventSystem.step(w)
	AbilitySystem.step(w)
	TurretSystem.step(w)
	_sync_prev(w)
	HazardSystem.step(w)


## The movement step copies every position to prev_x / prev_z before it moves anyone; these tests have no movement step.
static func _sync_prev(w: SimWorld) -> void:
	for i: int in w.enemies.high_water:
		w.enemies.prev_x[i] = w.enemies.x[i]
		w.enemies.prev_z[i] = w.enemies.z[i]


## The call as the command applies it: at the start of the next tick, before the event steps of that tick.
static func call_on_next_tick(w: SimWorld, event_index: int) -> int:
	w.tick += 1
	w.events.current_tick = w.tick
	var reason: int = EventSystem.call_event(w, 1000 + w.tick, event_index)
	EventSystem.step(w)
	AbilitySystem.step(w)
	TurretSystem.step(w)
	HazardSystem.step(w)
	return reason


## The world of a run whose kit grants `n` charges of the Deadfall Strike (a SIGNAL-like kit made in the test).
static func kit_world(n: int) -> SimWorld:
	var content: ContentSet = TestContent.variety()
	var grant: OpDef = OpDef.new()
	grant.kind = OpDef.Kind.GRANT
	grant.target = &"event_charge"
	grant.arg = &"deadfall_strike"
	grant.value = float(n)
	var kit: KitDef = KitDef.new()
	kit.id = &"k_test_signal"
	kit.index = content.kits.size()
	kit.ops = [grant]
	content.kits.append(kit)
	var cfg: SimConfig = SimConfig.create(content, 1)
	cfg.kit_index = kit.index
	return SimWorld.new(cfg)


## A combat world on content that lists the given directives (an id the slice data does not have is appended), each held
## with the given number of stacks.
static func directive_world(held: Dictionary[StringName, int]) -> SimWorld:
	var content: ContentSet = TestContent.variety()
	for id: StringName in held:
		if content.directive(id) == null:
			var d: DirectiveDef = DirectiveDef.new()
			d.id = id
			d.index = content.directives.size()
			d.max_stacks = 3
			content.directives.append(d)
	var w: SimWorld = SimWorld.new(SimConfig.create(content, 1))
	w.phase = GameState.Id.SPAWNING
	begin_wave(w, 4)
	for id: StringName in held:
		w.draft.stacks[content.directive_index(id)] = held[id]
	ModSystem.recompute(w)
	return w


## The slice content stretched to 15 waves and three acts (acts II and III with two event slots per wave), for plan rules.
static func long_content() -> ContentSet:
	var c: ContentSet = TestContent.variety()
	for n: int in range(6, 16):
		var s: WaveSlotDef = WaveSlotDef.new()
		s.index = n
		s.act = 2 if n <= 10 else 3
		s.kind = WaveSlotDef.Kind.BOSS if n % 5 == 0 else WaveSlotDef.Kind.NORMAL
		s.budget = 100.0
		s.window_ticks = 2000
		s.peak_bodied = 40
		s.peak_minis = 20
		s.event_slots = 2
		c.run.waves.append(s)
	return c


static func run(w: SimWorld, ticks: int) -> void:
	for _n: int in ticks:
		tick(w)


## Runs until `kind` has been pushed `n` times in all (or `limit` ticks pass). Returns the tick of the n-th push, or -1.
static func run_until(w: SimWorld, kind: int, n: int, limit: int) -> int:
	for _t: int in limit:
		tick(w)
		if count(w, kind) >= n:
			return w.tick
	return -1


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func count(w: SimWorld, kind: int) -> int:
	return events_of(w, kind).size()


static func ticks_of(w: SimWorld, kind: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, kind):
		out.append(e.tick)
	return out


## The events of `kind` whose first payload is `event_index`.
static func ticks_for(w: SimWorld, kind: int, event_index: int) -> Array[int]:
	var out: Array[int] = []
	for e: SimEvent in events_of(w, kind):
		if e.a == event_index:
			out.append(e.tick)
	return out


## Number of living enemies.
static func alive(w: SimWorld) -> int:
	return w.alive_count()
