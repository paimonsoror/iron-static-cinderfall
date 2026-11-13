class_name BossAegisArray
extends RefCounted
## NODE 6 // AEGIS ARRAY (`aegis_array`; VARIETY_SPEC 6, CONTENT 5): act II. Three ward pylons orbit it; while one lives the boss takes x0.2 damage. When all are
## down it is exposed for 10 s, then redeploys 3, 2, 1.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
##
## Deployments shrink by one pylon each time, as the approved briefing line says ("then redeploys fewer"): 3 pylons at
## the spawn, 2 after the first exposed window, 1 after the second; when that last pylon falls the array stays exposed
## for good. The phase is the deployment (0, 1, 2) and 3 for the final exposed state, so the bar shows 4 pips.
## Timeline: the pylons leave on the first step after the spawn. On the tick T the last pylon of a deployment dies the
## window opens (F_EXPOSED, exposed_left 600; no event of its own: the last pylon's death is the signal); the next
## deployment leaves at T + 600 (BOSS_PHASE). The EMP drops the protection for 3 s (180 ticks) although pylons live.
## Pylons are `ward_pylon` enemies of their own (300 HP, a priority target): the script parks them as attackers that
## never hit and carries them on a ring of `orbit_m` around the boss. A pylon that finds no room (a cap) is owed and
## sent on a later tick. They die with the boss.
## The protection is read by the damage path through BossSystem.damage_taken_mult; it follows `parts_alive` of the
## end of the previous tick.
## Answers: kill the pylons (they are priority targets; a rail shot or a strike hits pylons and boss together), or
## the EMP.
## Behaviour keys (BossDef.behaviour, fallbacks of CONTENT 5): pylons 3, protected_mult 0.2, exposed_s 10,
## emp_drop_s 3, orbit_period_s 6; the ring radius is `orbit_m` of the `ward_pylon` enemy (2.2).

const T_DEPLOY: int = 0  ## index of the current deployment (0 = the first)
const T_PENDING: int = 1  ## pylons of the current deployment still owed
const T_EMP: int = 2  ## ticks the EMP keeps the protection down
const T_SIZE: int = 3  ## pylons the current deployment has in all (the spacing on the ring)
const T_PYLON: int = 4  ## first of MAX_PYLONS enemy ids (0 = empty place on the ring)
const MAX_PYLONS: int = 6


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 4


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(world: SimWorld, enemy_index: int) -> void:
	BossKit.adopt(world, enemy_index, pylon_count(world) + 1, T_PYLON + MAX_PYLONS)


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	if not b.has_flag(BossState.F_BEGUN):
		b.set_flag(BossState.F_BEGUN, true)
		_deploy(world, 0)
	if BossKit.emp_fired_this_tick(world):
		b.timers[T_EMP] = BossKit.ticks(world, &"emp_drop_s", 3.0)
	elif b.timers[T_EMP] > 0:
		b.timers[T_EMP] -= 1
	if b.timers[T_PENDING] == 0 and _count_alive(world) == 0:
		_step_exposed(world)
	_send_pending(world, enemy_index)
	b.parts_alive = _count_alive(world)
	_orbit(world, enemy_index)


## Pylons of the first deployment (each later one has one fewer).
static func pylon_count(world: SimWorld) -> int:
	if not BossKit.has_type(world, Ids.EN_WARD_PYLON):
		return 0
	var def: BossDef = BossKit.def_of(world, Ids.EN_AEGIS_ARRAY)
	return clampi(roundi(def.beh(&"pylons", 3.0)) if def != null else 3, 0, MAX_PYLONS)


## x0.2 while a pylon protects the array and no EMP holds the protection down (BossSystem.damage_taken_mult).
static func damage_taken_mult(world: SimWorld) -> float:
	var b: BossState = world.boss
	if b.parts_alive > 0 and b.timers[T_EMP] == 0:
		return BossKit.num(world, &"protected_mult", 0.2)
	return 1.0


## True while the pylons protect the array (the view draws the ring and the bar from this).
static func is_protected(world: SimWorld) -> bool:
	return world.boss.boss_type == Ids.EN_AEGIS_ARRAY and damage_taken_mult(world) < 1.0


## The boss is gone: its pylons go with it.
static func end(world: SimWorld) -> void:
	var b: BossState = world.boss
	for k: int in MAX_PYLONS:
		if T_PYLON + k >= b.timers.size():
			break
		var j: int = world.enemies.index_of(b.timers[T_PYLON + k]) if b.timers[T_PYLON + k] != 0 else -1
		if j >= 0:
			BossEffects.remove(world, j)


## No pylon is up and none is owed: open the window, count it down, then send the next deployment. After the last
## deployment the array stays exposed (the final phase).
static func _step_exposed(world: SimWorld) -> void:
	var b: BossState = world.boss
	var next: int = b.timers[T_DEPLOY] + 1
	var total: int = b.phase_count - 1
	if not b.has_flag(BossState.F_EXPOSED):
		b.set_flag(BossState.F_EXPOSED, true)
		if next >= total:
			BossKit.set_phase(world, total)
			return
		b.exposed_left = BossKit.ticks(world, &"exposed_s", 10.0)
		return
	if b.exposed_left <= 0:
		return
	b.exposed_left -= 1
	if b.exposed_left == 0:
		_deploy(world, next)


## Starts deployment `index`: its pylons are owed, the ring is cleared, the phase follows.
static func _deploy(world: SimWorld, index: int) -> void:
	var b: BossState = world.boss
	var size: int = maxi(0, b.phase_count - 1 - index)
	b.timers[T_DEPLOY] = index
	b.timers[T_SIZE] = size
	b.timers[T_PENDING] = size
	for k: int in MAX_PYLONS:
		b.timers[T_PYLON + k] = 0
	b.set_flag(BossState.F_EXPOSED, false)
	b.exposed_left = 0
	BossKit.set_phase(world, index)


## Sends the owed pylons into the free places of the ring, lowest place first; one that finds no room stays owed.
static func _send_pending(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	var es: EnemyStore = world.enemies
	var radius: float = _ring_radius(world)
	for k: int in b.timers[T_SIZE]:
		if b.timers[T_PENDING] <= 0:
			return
		if b.timers[T_PYLON + k] != 0:
			continue
		var angle: float = _ring_angle(world, k)
		var j: int = BossEffects.send_now(
			world, Ids.EN_WARD_PYLON, es.x[enemy_index] + cos(angle) * radius, es.z[enemy_index] + sin(angle) * radius
		)
		if j < 0:
			return
		BossEffects.park(world, j, BossEffects.HOLD_ATTACK_CD)
		b.timers[T_PYLON + k] = world.enemies.id[j]
		b.timers[T_PENDING] -= 1


## Living pylons of the current deployment; the place of a dead one is cleared.
static func _count_alive(world: SimWorld) -> int:
	var b: BossState = world.boss
	var alive: int = 0
	for k: int in MAX_PYLONS:
		var id: int = b.timers[T_PYLON + k]
		if id == 0:
			continue
		if world.enemies.index_of(id) >= 0:
			alive += 1
		elif b.timers[T_PENDING] == 0:
			b.timers[T_PYLON + k] = 0
	return alive


## Carries every living pylon to its place on the ring.
static func _orbit(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	var es: EnemyStore = world.enemies
	var radius: float = _ring_radius(world)
	for k: int in MAX_PYLONS:
		var j: int = es.index_of(b.timers[T_PYLON + k]) if b.timers[T_PYLON + k] != 0 else -1
		if j < 0:
			continue
		var angle: float = _ring_angle(world, k)
		BossEffects.carry(world, j, es.x[enemy_index] + cos(angle) * radius, es.z[enemy_index] + sin(angle) * radius)


## Angle of place `k` of the ring on this tick: evenly spaced, turning once per `orbit_period_s`. A function of the
## tick only, so nothing accumulates.
static func _ring_angle(world: SimWorld, k: int) -> float:
	var turn: int = BossKit.ticks(world, &"orbit_period_s", 6.0)
	var size: int = maxi(1, world.boss.timers[T_SIZE])
	return TAU * (float(k) / float(size) + float(world.tick % turn) / float(turn))


static func _ring_radius(world: SimWorld) -> float:
	return world.content.enemies[Ids.EN_WARD_PYLON].beh(&"orbit_m", 2.2)
