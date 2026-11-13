class_name SimPuppet
extends Node
## A live, fake battle for the view sandbox (ARCH 11). It builds a real SimWorld and runs the REAL tick systems
## (commands, abilities, movement with attack slots and stuck recovery, weapon, turrets, core attacks) in the same order
## as `SimWorld.step`, but replaces the spawn schedule and the phases with a scenario: it holds N enemies alive, buys
## the SMG and both turrets and fires the three abilities through the real command queue. Every sim event is forwarded
## to `Events` (PuppetEvents), so the view reacts exactly as it will in a run: shots, enemy damage and kills, core
## hits, reloads, shield, overdrive, EMP stun, turret deploys, weapon swap, stuck enemies.
## Scenarios: `hold10`, `hold28`, `hold50` (50 and wave 5 add a Siege Hulk) and `boss` (the Hulk and a small escort,
## low core). The puppet changes sim state only through public sim calls, commands and the few debug writes marked below.
## Variety scenarios (VARIETY_SPEC 13.8, scripted by PuppetChaos): `hold<N>+<M>` adds M minis to the crowd of N, `chain`
## is a crowd of CHAIN_HOLD with a burster line, a Deadfall Strike, a chain of blasts, arcs and a pool on a loop.
## V5-B lab scenarios on the real boss and event systems (the sim steps them like a run would): `boss:<id>` holds a crowd around the
## named boss (siege_hulk, brood_carrier, lance_platform, aegis_array, tremor_rig, or the Node 9 variants hulk_plated, hulk_fed,
## hulk_overclocked) and lets BossSystem run its script; `event:<id>` opens the named chaos event (any id of events.json) once the
## crowd is walking and lets EventSystem run its warning and its effect.

const TICK_DT: float = 1.0 / 60.0
const PREROLL_TICKS: int = 180
const SPAWN_EVERY_TICKS: int = 5
const DAMAGE_MULT: float = 0.3  ## the crowd must survive long enough to be looked at
const BOSS_ESCORT: int = 14
const MIX: Array[int] = [0, 0, 0, 1, 0, 2, 0, 0, 1, 2]  ## six skitters, two hollow wardens, two rushers
## Seconds after the start: when each action first happens (abilities repeat whenever they are ready again).
const T_TURRET_0: float = 0.5
const T_TURRET_1: float = 1.0
const T_SMG: float = 1.5
const T_STUCK: float = 1.2
const T_ABILITY: Array[float] = [8.0, 2.0, 3.0]  ## EMP, shield, overdrive (Ids.AB_*)
const RETRY_TICKS: int = 180
const CHAIN_HOLD: int = 24
const LAB_HOLD: int = 30  ## the crowd around an event
const T_EVENT: float = 0.5  ## seconds after the start: the event of an `event:<id>` scenario opens (and again once it is over)
const BOSS_TYPES: Dictionary[StringName, int] = {
	&"siege_hulk": Ids.EN_HULK, &"hulk_plated": Ids.EN_HULK, &"hulk_fed": Ids.EN_HULK, &"hulk_overclocked": Ids.EN_HULK,
	&"brood_carrier": Ids.EN_BROOD_CARRIER, &"lance_platform": Ids.EN_LANCE_PLATFORM, &"aegis_array": Ids.EN_AEGIS_ARRAY,
	&"tremor_rig": Ids.EN_TREMOR_RIG,
}

var world: SimWorld
var events: PuppetEvents
var scenario: String = "hold50"
var hold: int = 50
var boss_mode: bool = false
var boss_kind: StringName = &""  ## `boss:<id>`: which boss (empty = the Siege Hulk of the plain `boss` scenario)
var event_id: StringName = &""  ## `event:<id>`: which chaos event to open
var second_weapon: StringName = &""  ## set before `setup`: the Warden also carries this weapon in slot 2 (a HUD capture shows two cards)
var tick_usec_avg: float = 0.0  ## moving average of one puppet tick (the sim systems), for the perf line
var tick_sink: Callable = Callable()  ## called with the microseconds of every tick (PerfHud.record_tick_usec)
var chaos: PuppetChaos = PuppetChaos.new()  ## the variety script (minis, chain, arcs, telegraphs)

var _content: ContentSet
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _acc: float = 0.0
var _clock: int = 0
var _next_command: int = 1
var _spawned_n: int = 0
var _next_try: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _stuck_done: bool = false
var _scripting: bool = false
var _lab: bool = false  ## the real boss, event, status and hazard systems run too (a `boss:<id>` or `event:<id>` scenario)
var _event_index: int = -1
var _next_event_tick: int = 0
var _core_floor: float = 0.25
var _core_refill: float = 1.0


## `scenario_name`: `hold<N>` (N clamped to the enemy cap), `hold<N>+<M>` (M minis, clamped to `swarm_cap`), `chain`
## `chain<N>+<M>`, `boss`, `boss:<id>` or `event:<id>`; anything else is hold50. Returns {hold, boss, minis, chain, boss_kind, event}.
static func parse(scenario_name: String, enemy_cap: int, swarm_cap: int = 0) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {"hold": 50, "boss": false, "minis": 0, "chain": false, "boss_kind": &"", "event": &""}
	var crowd: String = scenario_name.substr(4) if scenario_name.begins_with("hold") else ""
	var plus: int = crowd.find("+")
	if scenario_name == "boss":
		out["hold"] = BOSS_ESCORT + 1
		out["boss"] = true
	elif scenario_name.begins_with("boss:"):
		out["hold"] = BOSS_ESCORT + 1
		out["boss"] = true
		out["boss_kind"] = StringName(scenario_name.substr(5))
	elif scenario_name.begins_with("event:"):
		out["hold"] = mini(LAB_HOLD, enemy_cap)
		out["event"] = StringName(scenario_name.substr(6))
	elif scenario_name.begins_with("chain"):  # `chain` (CHAIN_HOLD bodies) or `chain<N>+<M>` (N bodies and M minis around the line)
		var tail: String = scenario_name.substr(5)
		var split: int = tail.find("+")
		out["hold"] = mini(CHAIN_HOLD, enemy_cap)
		out["chain"] = true
		if split > 0 and tail.substr(0, split).is_valid_int() and tail.substr(split + 1).is_valid_int():
			out["hold"] = clampi(tail.substr(0, split).to_int(), 1, enemy_cap)
			out["minis"] = clampi(tail.substr(split + 1).to_int(), 0, swarm_cap)
	elif plus > 0 and crowd.substr(0, plus).is_valid_int() and crowd.substr(plus + 1).is_valid_int():
		out["hold"] = clampi(crowd.substr(0, plus).to_int(), 1, enemy_cap)
		out["minis"] = clampi(crowd.substr(plus + 1).to_int(), 0, swarm_cap)
	elif crowd.is_valid_int():
		out["hold"] = clampi(crowd.to_int(), 1, enemy_cap)
	return out


## `variety_bodies`: the view that renders this puppet can draw the variety enemy types (minis, bursters). False
## (the default) keeps every store row one of the four legacy types; the variety effect events are pushed either way.
func setup(content: ContentSet, scenario_name: String = "hold50", puppet_seed: int = 1, variety_bodies: bool = false) -> void:
	_content = content
	scenario = scenario_name
	var spec: Dictionary[String, Variant] = parse(scenario_name, content.mission.enemy_cap, content.mission.swarm_cap)
	hold = spec["hold"]
	boss_mode = spec["boss"]
	boss_kind = spec["boss_kind"]
	event_id = spec["event"]
	_lab = boss_kind != &"" or event_id != &""
	chaos.minis = spec["minis"]
	chaos.chain = spec["chain"]
	chaos.boss = boss_mode
	chaos.real_bodies = variety_bodies and content.is_variety()
	_rng.seed = puppet_seed
	var cfg: SimConfig = SimConfig.create(content, puppet_seed)
	cfg.debug_damage_mult = DAMAGE_MULT
	cfg.debug_start_scrap = 5000
	world = SimWorld.new(cfg)
	world.phase = GameState.Id.SPAWNING  # debug write: abilities and purchases are legal in this phase
	world.wave = 5 if (boss_mode or hold >= 40) else 3  # debug write: unlocks the SMG (min_wave 2)
	events = PuppetEvents.new(content)
	chaos.setup(world, content, _rng)
	if second_weapon != &"" and content.weapon(second_weapon) != null and world.arsenal.slot_count > 1:
		ArsenalSystem.give_weapon(world, 1, Ids.WEAPONS.find(second_weapon))
	if boss_mode:
		_core_floor = 0.08
		_core_refill = 0.3
		world.set_core_hp(world.core_max_hp * 0.3)
	if boss_mode or hold >= 40:
		var boss_type: int = BOSS_TYPES.get(boss_kind, Ids.EN_HULK)
		var boss: int = _spawn_along_path(boss_type, 0.55)
		if boss >= 0:
			_spawned_n += 1
			_pick_variant()
	_event_index = content.event_index(event_id) if event_id != &"" else -1
	while world.alive_count() < hold:
		var _i: int = _spawn_along_path(MIX[_spawned_n % MIX.size()], _rng.randf_range(0.05, 1.0))
		_spawned_n += 1
	for _t: int in PREROLL_TICKS:
		_tick()
	_flush()
	_clock = 0  # the script (turrets, SMG, abilities) starts when the view does, so its effects are seen live
	_scripting = true


## Advances the puppet by `delta` seconds in 60 Hz steps; returns the interpolation alpha for rendering.
func advance(delta: float) -> float:
	_acc += minf(delta, 0.1)
	while _acc >= TICK_DT:
		_acc -= TICK_DT
		_tick()
	_flush()
	return _acc / TICK_DT


## One fixed tick, in the order of SimWorld.step minus spawning and phases.
func step_once() -> void:
	_tick()
	_flush()


func clock_seconds() -> float:
	return float(_clock) * TICK_DT


func _tick() -> void:
	var started: int = Time.get_ticks_usec()
	_clock += 1
	_script()
	world.tick += 1
	world.events.current_tick = world.tick
	CommandSystem.apply_queued(world)
	if _lab:
		EventSystem.step(world)
	AbilitySystem.step(world)
	if _lab:
		StatusSystem.step(world)
	MovementSystem.step(world)
	WeaponSystem.step(world)
	TurretSystem.step(world)
	if _lab:
		HazardSystem.step(world)
	CoreAttackSystem.step(world)
	if _lab:
		BossSystem.step(world)
	if _scripting and chaos.active():
		chaos.tick(_clock)
	_guard_boss()
	_repair_core()
	_top_up()
	var spent: float = float(Time.get_ticks_usec() - started)
	tick_usec_avg = lerpf(tick_usec_avg, spent, 0.05) if tick_usec_avg > 0.0 else spent
	if tick_sink.is_valid():
		tick_sink.call(spent)


func _flush() -> void:
	var _n: int = events.forward(world.events.drain())


# ---------------------------------------------------------------- scenario script


## Commands go through the real queue; the timeline is the puppet's clock, not the sim's.
func _script() -> void:
	if not _scripting:
		return
	var seconds: float = float(_clock) * TICK_DT
	if _clock == roundi(T_TURRET_0 / TICK_DT) or _clock == roundi(T_TURRET_1 / TICK_DT):
		_command(SimCommand.purchase(_cmd_id(), Ids.UP_AUTO_TURRET))
	if _clock == roundi(T_SMG / TICK_DT):
		_command(SimCommand.purchase(_cmd_id(), Ids.UP_SMG))
	if _event_index >= 0 and _event_open_due(seconds):
		var _slot: int = EventSlots.open(world, _event_index)
	if not _stuck_done and seconds >= T_STUCK:
		_stuck_done = true
		_mark_stuck(2)
	for a: int in Ids.ABILITIES.size():
		if seconds >= T_ABILITY[a] and _clock >= _next_try[a] and world.abilities.is_ready(a):
			_next_try[a] = _clock + RETRY_TICKS
			_command(SimCommand.ability(_cmd_id(), a))


## The named event opens at T_EVENT, and again (after a pause of one second) whenever it has run its course.
func _event_open_due(seconds: float) -> bool:
	if seconds < T_EVENT:
		return false
	for e: int in world.events_state.a_event.size():
		if world.events_state.a_event[e] == _event_index:
			return false
	if _clock < _next_event_tick:
		return false
	_next_event_tick = _clock + roundi(1.0 / TICK_DT)
	return true


## A Node 9 variant is the plan's pick in a run; here the scenario names it (debug write on the boss state the script just filled).
func _pick_variant() -> void:
	var index: int = _content.run.hulk_variants.find(boss_kind) if _content.run != null else -1
	if index < 0 or world.boss.boss_type != Ids.EN_HULK:
		return
	world.boss.variant = index
	if boss_kind == &"hulk_plated":
		world.boss.phase_count = BossSiegeHulk.PLATED_PHASES


func _command(cmd: SimCommand) -> void:
	world.submit(cmd)


func _cmd_id() -> int:
	_next_command += 1
	return _next_command - 1


## Debug writes to the nav trackers (the fields StuckRecovery owns): two moving enemies look stuck, `stuck_ref` is set
## so the real recovery then force-moves them after the grace period (a teleport the view must not slide over).
func _mark_stuck(count: int) -> void:
	var st: EnemyStore = world.enemies
	var nav: NavState = world.nav
	var marked: int = 0
	for i: int in st.high_water:
		if marked >= count:
			break
		if st.alive[i] == 0 or st.state[i] != EnemyStore.ST_MOVING or st.type[i] == Ids.EN_HULK:
			continue
		if nav.track_id[i] != st.id[i]:
			continue
		nav.recoveries[i] += 1
		nav.sep_off[i] = StuckRecovery.GRACE_TICKS
		nav.grace[i] = 1
		nav.stuck_ref[i] = st.path_dist[i] - 30.0
		world.events.push(SimEventKind.Id.ENEMY_STUCK, st.id[i], nav.recoveries[i])
		marked += 1


## The boss is never killed by the puppet; its hp floors at a quarter.
func _guard_boss() -> void:
	var i: int = world.boss_store_index()
	if i >= 0 and world.enemies.hp[i] < world.enemies.max_hp[i] * 0.25:
		world.enemies.hp[i] = world.enemies.max_hp[i] * 0.25


## The core is repaired when the puppet's enemies would have destroyed it, so the sandbox runs on.
func _repair_core() -> void:
	if world.core_hp < world.core_max_hp * _core_floor:
		world.set_core_hp(world.core_max_hp * _core_refill)


## Keeps `hold` enemies alive: a replacement walks in from a spawn region every few ticks.
func _top_up() -> void:
	var bodied: int = world.alive_count() - (chaos.minis_alive() if chaos.minis > 0 else 0)
	if bodied >= hold or _clock % SPAWN_EVERY_TICKS != 0:
		return
	var kind: int = MIX[_spawned_n % MIX.size()]
	_spawned_n += 1
	var _i: int = _spawn_along_path(kind, 0.0)


## Spawns an enemy in a spawn region, then walks it `travel` (0..1) of the way to the core along the flow field.
func _spawn_along_path(type_index: int, travel: float) -> int:
	var arena: ArenaDef = _content.arena
	var region: SpawnRegionDef = arena.spawn_regions[_rng.randi() % arena.spawn_regions.size()]
	var t: float = _rng.randf()
	var p: Vector2 = Vector2(lerpf(region.x0, region.x1, t), lerpf(region.z0, region.z1, t))
	var flow: FlowField = world.nav.flow
	var remaining: float = flow.sample_cost(p.x, p.y) * travel
	if is_inf(remaining):
		remaining = 0.0
	while remaining > 0.0:
		var dir: Vector2 = flow.sample_dir(p.x, p.y)
		if dir == Vector2.ZERO:
			break
		p += dir * 0.5
		remaining -= 0.5
	return world.spawn_enemy(type_index, p.x, p.y)
