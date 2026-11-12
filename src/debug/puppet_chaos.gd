class_name PuppetChaos
extends RefCounted
## The variety part of SimPuppet (VARIETY_SPEC 13.8): minis, a burster chain with a Deadfall Strike, arcs, a pool, a
## telegraph and a boss telegraph, scripted on the puppet clock so the view tasks do not wait for the sim systems
## (which are stubs). Bodies are real store rows spawned through `world.spawn_enemy`; kills go through
## `world.kill_enemy`; every effect is a real SimEvent pushed into `world.events` (debug writes) and reaches the bus
## through PuppetEvents, exactly as a run will deliver it.
##
## `real_bodies` false (the view cannot draw the new enemy types yet): no minis are spawned and the chain line is
## made of skitters; the effect events are the same. See SimPuppet.setup.
##
## Timeline of `chain`, repeating every CYCLE ticks: 0 the line of CHAIN_LEN walks in; T_WARN the strike is called
## (EVENT_WARNED, a 2 s telegraph at the line's middle); T_LAUNCH the round is in the air (DELAYED_HIT_LAUNCHED);
## T_IMPACT it lands (EVENT_STARTED, AREA_BLAST) and the line goes off one body every CHAIN_STEP ticks (AREA_BLAST and
## a kill each); then a pool burns for POOL_TICKS (POOL_STARTED, POOL_ENDED). Every ARC_EVERY ticks an arc of ARC_JUMPS
## jumps runs from the Warden through the nearest enemies (CHAIN_ARC). `boss` adds BOSS_TELEGRAPH every BOSS_EVERY ticks.

const CYCLE: int = 360
const CHAIN_LEN: int = 6
const CHAIN_STEP: int = 6
const LINE_SPACING_M: float = 1.7
const LINE_TRAVEL: float = 0.5
const T_WARN: int = 60
const T_LAUNCH: int = 120
const T_IMPACT: int = 180
const STRIKE_RADIUS_CM: int = 400
const BLAST_RADIUS_CM: int = 260
const POOL_RADIUS_CM: int = 220
const POOL_TICKS: int = 90
const ARC_EVERY: int = 37
const ARC_JUMPS: int = 4
const ARC_RANGE_M: float = 3.0
const MINI_EVERY: int = 3
const BOSS_EVERY: int = 240
const BOSS_AT: int = 120  ## the tick of each BOSS_EVERY cycle on which the telegraph starts
const BOSS_TELEGRAPH_TICKS: int = 90

var minis: int = 0  ## minis to hold alive
var chain: bool = false
var boss: bool = false
var real_bodies: bool = false
var blasts: int = 0  ## AREA_BLAST events pushed so far (tests, reports)
var arcs: int = 0

var _world: SimWorld
var _content: ContentSet
var _rng: RandomNumberGenerator
var _line: PackedInt32Array = PackedInt32Array()  ## enemy ids of the current chain line
var _strike: Vector2 = Vector2.ZERO
var _pool_id: int = 0
var _pool_left: int = 0
var _event_index: int = 0


func setup(world: SimWorld, content: ContentSet, rng: RandomNumberGenerator) -> void:
	_world = world
	_content = content
	_rng = rng
	_event_index = maxi(0, content.event_index(&"deadfall_strike"))


func active() -> bool:
	return minis > 0 or chain or boss


## Minis alive right now (store rows of a mini type).
func minis_alive() -> int:
	var n: int = 0
	for i: int in _world.enemies.high_water:
		if _world.enemies.alive[i] == 1 and _content.enemies[_world.enemies.type[i]].is_mini():
			n += 1
	return n


## One puppet tick; `clock` is the puppet clock (ticks since the script started).
func tick(clock: int) -> void:
	if real_bodies and minis > 0 and clock % MINI_EVERY == 0 and minis_alive() < minis:
		_spawn_mini()
	if clock % ARC_EVERY == 0 and (chain or minis > 0):
		_arc()
	if boss and clock % BOSS_EVERY == BOSS_AT:
		_world.events.push(SimEventKind.Id.BOSS_TELEGRAPH, 0, BOSS_TELEGRAPH_TICKS)
	if _pool_left > 0:
		_pool_left -= 1
		if _pool_left == 0:
			_world.events.push(SimEventKind.Id.POOL_ENDED, _pool_id, 0, _strike.x, _strike.y)
	if chain:
		_guard_line()
		_chain((clock - 1) % CYCLE)


func _chain(t: int) -> void:
	if t == 0:
		_spawn_line()
	elif t == T_WARN:
		_world.events.push(SimEventKind.Id.CHARGES_CHANGED, _event_index, 1)
		_world.events.push(SimEventKind.Id.EVENT_WARNED, _event_index, T_IMPACT - T_WARN, _strike.x, _strike.y)
	elif t == T_LAUNCH:
		_world.events.push(SimEventKind.Id.DELAYED_HIT_LAUNCHED, HazardState.K_STRIKE, T_IMPACT - T_LAUNCH, _strike.x, _strike.y)
	elif t == T_IMPACT:
		_world.events.push(SimEventKind.Id.EVENT_STARTED, _event_index, 0, _strike.x, _strike.y)
		_blast(HazardState.K_STRIKE, STRIKE_RADIUS_CM, _strike.x, _strike.y)
		_world.events.push(SimEventKind.Id.EVENT_ENDED, _event_index)
	var since: int = t - T_IMPACT - CHAIN_STEP
	if since >= 0 and since % CHAIN_STEP == 0 and floori(float(since) / float(CHAIN_STEP)) < _line.size():
		_detonate(floori(float(since) / float(CHAIN_STEP)))
	if t == T_IMPACT + CHAIN_STEP * (CHAIN_LEN + 1):
		_pool_id += 1
		_pool_left = POOL_TICKS
		_world.events.push(SimEventKind.Id.POOL_STARTED, _pool_id, POOL_RADIUS_CM, _strike.x, _strike.y)


## The line: CHAIN_LEN bodies LINE_SPACING_M apart along the flow field, the first one LINE_TRAVEL of the way in.
func _spawn_line() -> void:
	_line.clear()
	var arena: ArenaDef = _content.arena
	var region: SpawnRegionDef = arena.spawn_regions[0]
	var p: Vector2 = Vector2(lerpf(region.x0, region.x1, 0.5), lerpf(region.z0, region.z1, 0.5))
	var flow: FlowField = _world.nav.flow
	var total: float = flow.sample_cost(p.x, p.y)
	if is_inf(total):
		return
	var points: PackedVector2Array = PackedVector2Array()
	var walked: float = 0.0
	var next_at: float = total * LINE_TRAVEL - LINE_SPACING_M * float(CHAIN_LEN - 1)
	while walked < total and points.size() < CHAIN_LEN:
		if walked >= next_at:
			points.append(p)
			next_at += LINE_SPACING_M
		var dir: Vector2 = flow.sample_dir(p.x, p.y)
		if dir == Vector2.ZERO:
			break
		p += dir * 0.1
		walked += 0.1
	var kind: int = Ids.EN_BURSTER if real_bodies and _content.enemies.size() > Ids.EN_BURSTER else Ids.EN_SKITTER
	var sum: Vector2 = Vector2.ZERO
	for q: Vector2 in points:
		var i: int = _world.spawn_enemy(kind, q.x, q.y)
		if i >= 0:
			_line.append(_world.enemies.id[i])
		sum += q
	if not points.is_empty():
		_strike = sum / float(points.size())


## The line is never shot down before it goes off (debug write, like SimPuppet._guard_boss): the chain is the show.
func _guard_line() -> void:
	for enemy_id: int in _line:
		var i: int = _world.enemies.index_of(enemy_id)
		if i >= 0:
			_world.enemies.hp[i] = _world.enemies.max_hp[i]


## Body `k` of the line goes off: a blast where it stands now, and it dies (the kill goes through the real mutator).
func _detonate(k: int) -> void:
	var i: int = _world.enemies.index_of(_line[k])
	if i < 0:
		return
	_blast(HazardState.K_BLAST, BLAST_RADIUS_CM, _world.enemies.x[i], _world.enemies.z[i])
	_world.kill_enemy(i, DamageSource.Id.HAZARD)


func _blast(kind: int, radius_cm: int, x: float, z: float) -> void:
	blasts += 1
	_world.events.push(SimEventKind.Id.AREA_BLAST, kind, radius_cm, x, z)


## An arc from the Warden (id 0) to its target and on through the nearest not-yet-hit enemies (lowest id on ties).
func _arc() -> void:
	var st: EnemyStore = _world.enemies
	var from_id: int = 0
	var at: Vector2 = Vector2(_world.warden.x, _world.warden.z)
	var hit: Dictionary[int, bool] = {}
	var next: int = st.index_of(_world.warden.target_id)
	var reach: float = INF
	for _jump: int in ARC_JUMPS + 1:
		if next < 0:
			next = _nearest(at, reach, hit)
		if next < 0:
			return
		_world.events.push(SimEventKind.Id.CHAIN_ARC, from_id, st.id[next])
		arcs += 1
		hit[st.id[next]] = true
		from_id = st.id[next]
		at = Vector2(st.x[next], st.z[next])
		next = -1
		reach = ARC_RANGE_M


func _nearest(at: Vector2, reach: float, hit: Dictionary[int, bool]) -> int:
	var st: EnemyStore = _world.enemies
	var best: int = -1
	var best_d: float = reach * reach
	for i: int in st.high_water:
		if st.alive[i] == 0 or hit.has(st.id[i]):
			continue
		var d: float = Vector2(st.x[i], st.z[i]).distance_squared_to(at)
		if d < best_d or (d == best_d and best >= 0 and st.id[i] < st.id[best]):
			best = i
			best_d = d
	return best


func _spawn_mini() -> void:
	if _content.enemies.size() <= Ids.EN_MOTE:
		return
	var arena: ArenaDef = _content.arena
	var region: SpawnRegionDef = arena.spawn_regions[_rng.randi() % arena.spawn_regions.size()]
	var t: float = _rng.randf()
	var _i: int = _world.spawn_enemy(Ids.EN_MOTE, lerpf(region.x0, region.x1, t), lerpf(region.z0, region.z1, t))
