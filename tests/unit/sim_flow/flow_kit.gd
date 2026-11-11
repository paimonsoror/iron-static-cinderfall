class_name FlowKit
extends RefCounted
## Shared helpers for the sim_flow suites. Content is always TestContent.baseline() (WORK_PLAN rule 5).


## A fresh world on the frozen baseline, in PREPARING.
static func world(run_seed: int = 1) -> SimWorld:
	return TestContent.world(run_seed)


## A world placed in `target` by legal set_phase transitions only (no stepping). `wave_number` is written to
## world.wave for every phase except PREPARING. INTERMISSION gets a full countdown.
static func in_phase(target: int, wave_number: int = 1) -> SimWorld:
	var w: SimWorld = TestContent.world()
	if target == GameState.Id.PREPARING:
		return w
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = wave_number
	w.phase_ticks_left = 0
	if target == GameState.Id.CLEARING or target == GameState.Id.INTERMISSION or target == GameState.Id.VICTORY:
		w.set_phase(GameState.Id.CLEARING)
	if target == GameState.Id.INTERMISSION:
		w.set_phase(GameState.Id.INTERMISSION)
		w.phase_ticks_left = w.content.mission.intermission_ticks
	elif target == GameState.Id.VICTORY:
		w.set_phase(GameState.Id.VICTORY)
	elif target == GameState.Id.DEFEAT:
		w.set_phase(GameState.Id.DEFEAT)
	return w


static func step_n(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		w.step()


## Steps the simulation system alone (no commands, spawns or combat): for pure timer tests.
static func ability_steps(w: SimWorld, ticks: int) -> void:
	for n: int in ticks:
		AbilitySystem.step(w)


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


static func count(w: SimWorld, kind: int) -> int:
	return events_of(w, kind).size()


## Kills every living enemy through the shared mutator (pays Scrap).
static func kill_all(w: SimWorld) -> void:
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] == 1:
			w.kill_enemy(i, DamageSource.Id.WARDEN)


## Spawns one enemy of `type_index` far from anything; returns its store index.
static func spawn(w: SimWorld, type_index: int) -> int:
	return w.spawn_enemy(type_index, 5.0, 0.0)


## Steps until the phase equals `target`, killing all enemies before every step when `clear_enemies` is set.
## Returns the number of steps taken, or -1 when `limit` steps were not enough.
static func run_until(w: SimWorld, target: int, limit: int, clear_enemies: bool = false) -> int:
	for n: int in limit:
		if w.phase == target:
			return n
		if clear_enemies:
			kill_all(w)
		w.step()
	return limit if w.phase == target else -1


## Plays the whole current wave: the spawn schedule counts as done and every enemy dies. Returns when the phase
## is no longer SPAWNING or CLEARING (INTERMISSION, or a terminal phase) and turns the hook back off, so the next
## wave starts normally.
static func clear_wave(w: SimWorld) -> void:
	w.phase_state.force_wave_spawned = true
	var guard: int = 0
	while (w.phase == GameState.Id.SPAWNING or w.phase == GameState.Id.CLEARING) and guard < 4000:
		kill_all(w)
		w.step()
		guard += 1
	w.phase_state.force_wave_spawned = false
