class_name BossLancePlatform
extends RefCounted
## NODE 5 // LANCE PLATFORM (`lance_platform`; VARIETY_SPEC 6, CONTENT 5): act I. Walks to its standoff point and plants. Cycle 9 s: a 3 s telegraphed charge, then
## a beam at the core. +50% damage taken while charging; an EMP during the charge cancels the shot.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
##
## The platform plants the first tick it is within its range of the core (EnemyDef.standoff_m, 14 m): it is parked as
## an attacker without a slot, so it never walks on and never touches the cage. From then on the beam IS its core
## attack: CoreAttackSystem counts its attack timer (EnemyDef.attack_period, 9 s) and deals EnemyDef.core_damage (160,
## shield first), and this script adds what makes it a boss attack. Timeline from the plant tick P: the charge starts at
## P + 360 (BOSS_TELEGRAPH ATK_LANCE, 180; F_CHARGING; the vents are open: damage taken x1.5), the beam lands at
## P + 540, the next charge starts at P + 900.
## A stun that begins during the charge (the EMP) cancels the shot: the cycle restarts from zero and the stun lasts 2 s
## in all, then the usual 5 s immunity. A stun outside the charge only holds the timer (CoreAttackSystem's rule).
## Answers to the beam: the EMP, the Shield (it absorbs its part), and burst damage through the open vents.
## Behaviour keys (BossDef.behaviour, fallbacks of CONTENT 5): charge_s 3, charge_damage_taken_mult 1.5,
## cancel_stun_s 2, plant_m (only when the body has no standoff_m) 14.

const TIMER_COUNT: int = 4
const PLANT_EPS_M: float = 0.05


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 1


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(world: SimWorld, enemy_index: int) -> void:
	BossKit.adopt(world, enemy_index, phase_count(), TIMER_COUNT)
	world.boss.set_flag(BossState.F_BEGUN, true)


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	var es: EnemyStore = world.enemies
	var period: int = period_ticks(world, enemy_index)
	if es.state[enemy_index] != EnemyStore.ST_ATTACKING:
		_stand_down(world)
		b.set_flag(BossState.F_PLANTED, false)
		if not _in_range(world, enemy_index):
			return
		BossEffects.park(world, enemy_index, period)
	b.set_flag(BossState.F_PLANTED, true)
	if BossKit.is_stunned(world, enemy_index):
		if b.has_flag(BossState.F_CHARGING):
			_stand_down(world)
			BossEffects.restart_attack(world, enemy_index, period)
			BossEffects.extend_stun(world, enemy_index, BossKit.ticks(world, &"cancel_stun_s", 2.0))
		return
	var left: int = es.attack_cd[enemy_index]
	if left > charge_ticks(world, period):
		_stand_down(world)
	elif b.has_flag(BossState.F_CHARGING):
		b.telegraph_left = left
	else:
		b.set_flag(BossState.F_CHARGING, true)
		BossKit.telegraph(world, BossState.ATK_LANCE, left)


## Ticks from one beam to the next (the body's attack period with the wave's modifier, as CoreAttackSystem restarts it).
static func period_ticks(world: SimWorld, enemy_index: int) -> int:
	var def: EnemyDef = world.content.enemies[world.enemies.type[enemy_index]]
	return maxi(2, roundi(float(def.attack_period_ticks) * world.mods.enemy_attack_period_mul))


## Ticks of the charge at the end of the cycle (always shorter than the cycle).
static func charge_ticks(world: SimWorld, period: int) -> int:
	return clampi(BossKit.ticks(world, &"charge_s", 3.0), 1, period - 1)


## x1.5 while the vents are open (BossSystem.damage_taken_mult).
static func damage_taken_mult(world: SimWorld) -> float:
	if world.boss.has_flag(BossState.F_CHARGING):
		return BossKit.num(world, &"charge_damage_taken_mult", 1.5)
	return 1.0


## The charge is over or cancelled: vents closed, no telegraph.
static func _stand_down(world: SimWorld) -> void:
	world.boss.set_flag(BossState.F_CHARGING, false)
	BossKit.clear_telegraph(world)


static func _in_range(world: SimWorld, enemy_index: int) -> bool:
	var es: EnemyStore = world.enemies
	var arena: ArenaDef = world.content.arena
	var def: EnemyDef = world.content.enemies[es.type[enemy_index]]
	var reach: float = (def.standoff_m if def.standoff_m > 0.0 else BossKit.num(world, &"plant_m", 14.0)) + PLANT_EPS_M
	var dx: float = es.x[enemy_index] - arena.core_x
	var dz: float = es.z[enemy_index] - arena.core_z
	return dx * dx + dz * dz <= reach * reach
