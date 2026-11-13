class_name BossBroodCarrier
extends RefCounted
## NODE 3 // BROOD CARRIER (`brood_carrier`; VARIETY_SPEC 6, CONTENT 5): act I. Every 6 s it opens its hatches and releases 6 motes; at 50% HP it molts: armor 0, a
## release every 3 s. A stun resets the hatch timer.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
##
## Timeline from the spawn tick S: the hatches glow at S + 300 (BOSS_TELEGRAPH ATK_HATCH, 60), the motes leave at
## S + 360, and so on every 360 ticks; after the molt every 180. While the carrier is stunned the hatch clock is held
## at 0 and a running telegraph is dropped, so the next release is a full period after the stun ends. The motes leave
## on a ring around the body; a mote that finds the swarm cap full waits in the spawn queue.
## Answers to the hatch: area and chain weapons on the motes, a stun (the EMP), and the molt as a damage window.
## Behaviour keys (BossDef.behaviour, fallbacks of CONTENT 5): hatch_period_s 6, hatch_count 6, hatch_warn_s 1,
## molt_frac 0.5, molt_period_s 3, molt_armor 0.

const T_CLOCK: int = 0  ## ticks since the last release (or the spawn, or the end of a stun)
const TIMER_COUNT: int = 4
const RING_MARGIN_M: float = 0.4  ## the motes leave this far outside the body's radius


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 2


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(world: SimWorld, enemy_index: int) -> void:
	BossKit.adopt(world, enemy_index, phase_count(), TIMER_COUNT)
	world.boss.set_flag(BossState.F_BEGUN, true)


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	if not b.has_flag(BossState.F_MOLTED) and BossKit.hp_frac(world, enemy_index) <= BossKit.num(world, &"molt_frac", 0.5):
		_molt(world)
	if BossKit.is_stunned(world, enemy_index):
		b.timers[T_CLOCK] = 0
		BossKit.clear_telegraph(world)
		return
	if not BossKit.past_spawn_tick(world, enemy_index):
		return
	var period: int = period_ticks(world)
	var warn: int = warn_ticks(world, period)
	b.timers[T_CLOCK] += 1
	if b.telegraph_attack == BossState.ATK_HATCH:
		if BossKit.telegraph_tick(world, BossState.ATK_HATCH):
			b.timers[T_CLOCK] = 0
			_release(world, enemy_index)
	elif b.timers[T_CLOCK] >= period - warn:
		BossKit.telegraph(world, BossState.ATK_HATCH, warn)


## Ticks between two releases now (shorter after the molt).
static func period_ticks(world: SimWorld) -> int:
	if world.boss.has_flag(BossState.F_MOLTED):
		return BossKit.ticks(world, &"molt_period_s", 3.0)
	return BossKit.ticks(world, &"hatch_period_s", 6.0)


## Ticks the hatches glow before a release (always shorter than the period).
static func warn_ticks(world: SimWorld, period: int) -> int:
	return clampi(BossKit.ticks(world, &"hatch_warn_s", 1.0), 1, maxi(1, period - 1))


## The carrier's armor: its type's value, or `molt_armor` after the molt (BossSystem.armor_of).
static func armor_of(world: SimWorld, base_armor: float) -> float:
	if world.boss.has_flag(BossState.F_MOLTED):
		return BossKit.num(world, &"molt_armor", 0.0)
	return base_armor


## Half HP: the plating is gone and the hatches cycle faster. A telegraph that already runs lands as announced; a
## release that the shorter period would bring at once still gets its full warning.
static func _molt(world: SimWorld) -> void:
	var b: BossState = world.boss
	b.set_flag(BossState.F_MOLTED, true)
	BossKit.set_phase(world, 1)
	var period: int = period_ticks(world)
	var warn: int = warn_ticks(world, period)
	if b.telegraph_attack != BossState.ATK_HATCH:
		b.timers[T_CLOCK] = mini(b.timers[T_CLOCK], period - warn - 1)


## `hatch_count` motes on a ring around the body, the first one toward the core, in a fixed order. A point inside a
## prop falls back to the body's own position.
static func _release(world: SimWorld, enemy_index: int) -> void:
	if not BossKit.has_type(world, Ids.EN_MOTE):
		return
	var es: EnemyStore = world.enemies
	var arena: ArenaDef = world.content.arena
	var bx: float = es.x[enemy_index]
	var bz: float = es.z[enemy_index]
	var ring: float = world.content.enemies[es.type[enemy_index]].radius + RING_MARGIN_M
	var base: float = atan2(arena.core_z - bz, arena.core_x - bx)
	var n: int = BossKit.count(world, &"hatch_count", 6)
	for k: int in n:
		var angle: float = base + TAU * float(k) / float(n)
		var x: float = bx + cos(angle) * ring
		var z: float = bz + sin(angle) * ring
		if NavGeometry.inside_any(arena.obstacles, x, z, 0.0):
			x = bx
			z = bz
		BossEffects.send(world, Ids.EN_MOTE, x, z)
