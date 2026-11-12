class_name BossKit
extends RefCounted
## What the five boss files share (VARIETY_SPEC 6, CONTENT 5): data lookups, the script memory in BossState.timers,
## telegraphs, phases and the stun rule. Everything here writes BossState only; what a boss does to the rest of the
## world goes through BossEffects.
##
## Numbers come from data: the body's EnemyDef and the `behaviour{}` of its BossDef (data/enemies.json `bosses`). Every
## key has the first-pass value of CONTENT 5 as its fallback, so a boss whose data entry is missing or short still
## behaves as the spec says.
##
## Clock convention: a boss file counts its own ticks from the tick after the spawn, and a stunned boss does not count
## (its timers and telegraphs hold). An attack telegraphed at tick T with `b` ticks lands at tick T + b when no stun
## falls between.


## The BossDef of an enemy type, or null (a boss body that the data file does not list as a boss).
static func def_of(world: SimWorld, type_index: int) -> BossDef:
	for b: BossDef in world.content.bosses:
		if b.enemy_index == type_index:
			return b
	return null


## A behaviour number of the living boss's BossDef, or `fallback`.
static func num(world: SimWorld, key: StringName, fallback: float) -> float:
	var def: BossDef = def_of(world, world.boss.boss_type)
	return def.beh(key, fallback) if def != null else fallback


## A behaviour duration in ticks (the key holds seconds), at least 1.
static func ticks(world: SimWorld, key: StringName, fallback_s: float) -> int:
	return maxi(1, Formulas.ticks(num(world, key, fallback_s)))


## A behaviour count, never negative.
static func count(world: SimWorld, key: StringName, fallback: int) -> int:
	return maxi(0, roundi(num(world, key, float(fallback))))


## Makes store index `enemy_index` the living boss: a neutral BossState with its id, type, phase count and `timer_count`
## zeroed script integers.
static func adopt(world: SimWorld, enemy_index: int, phases: int, timer_count: int) -> void:
	var b: BossState = world.boss
	b.reset()
	b.boss_id = world.enemies.id[enemy_index]
	b.boss_type = world.enemies.type[enemy_index]
	b.variant = BossState.NO_VARIANT
	b.phase_count = maxi(1, phases)
	b.timers.resize(maxi(4, timer_count))
	b.timers.fill(0)


static func is_stunned(world: SimWorld, enemy_index: int) -> bool:
	return world.enemies.stun_ticks[enemy_index] > 0


## Fraction of its hit points the enemy has left (0..1).
static func hp_frac(world: SimWorld, enemy_index: int) -> float:
	var max_hp: float = world.enemies.max_hp[enemy_index]
	return world.enemies.hp[enemy_index] / max_hp if max_hp > 0.0 else 0.0


## True on every tick after the one the boss spawned on (the tick a script clock may count).
static func past_spawn_tick(world: SimWorld, enemy_index: int) -> bool:
	return world.tick > world.enemies.spawn_tick[enemy_index]


## Moves the boss to `phase` (0-based) and pushes BOSS_PHASE(phase, phase count). No-op when it is already there.
static func set_phase(world: SimWorld, phase: int) -> void:
	var b: BossState = world.boss
	var clamped: int = clampi(phase, 0, b.phase_count - 1)
	if clamped == b.phase:
		return
	b.phase = clamped
	world.events.push(SimEventKind.Id.BOSS_PHASE, clamped, b.phase_count)


## Starts the telegraph of `attack`: it lands in `lead` ticks. Pushes BOSS_TELEGRAPH(attack, lead).
static func telegraph(world: SimWorld, attack: int, lead: int) -> void:
	var b: BossState = world.boss
	b.telegraph_attack = attack
	b.telegraph_left = maxi(1, lead)
	world.events.push(SimEventKind.Id.BOSS_TELEGRAPH, attack, b.telegraph_left)


## A warning that nothing can interrupt (a breach, the end of the exposed window): the event only, BossState keeps
## `telegraph_attack` for the attacks a tool can answer.
static func announce(world: SimWorld, attack: int, lead: int) -> void:
	world.events.push(SimEventKind.Id.BOSS_TELEGRAPH, attack, maxi(1, lead))


static func clear_telegraph(world: SimWorld) -> void:
	world.boss.telegraph_attack = BossState.ATK_NONE
	world.boss.telegraph_left = 0


## One tick of the running telegraph of `attack`. True on the tick it lands (the telegraph is then cleared).
static func telegraph_tick(world: SimWorld, attack: int) -> bool:
	var b: BossState = world.boss
	if b.telegraph_attack != attack or b.telegraph_left <= 0:
		return false
	b.telegraph_left -= 1
	if b.telegraph_left > 0:
		return false
	clear_telegraph(world)
	return true


## True when the EMP was activated on this tick (the command step of the same tick pushed ABILITY_ACTIVATED).
static func emp_fired_this_tick(world: SimWorld) -> bool:
	var buffer: Array[SimEvent] = world.events.peek()
	var at: int = buffer.size() - 1
	while at >= 0 and buffer[at].tick == world.tick:
		if buffer[at].kind == SimEventKind.Id.ABILITY_ACTIVATED and buffer[at].a == Ids.AB_EMP:
			return true
		at -= 1
	return false


## True while the Shield ability holds absorb points (the brace of the Tremor Rig's stomp).
static func shield_up(world: SimWorld) -> bool:
	return world.shield_hp > 0.0


## The enemy type exists in this content (a type the content was cut down from is skipped by the scripts).
static func has_type(world: SimWorld, type_index: int) -> bool:
	return type_index >= 0 and type_index < world.content.enemies.size() and world.content.enemies[type_index] != null


## Metres as integer millimetres and back (positions a script has to remember).
static func to_milli(metres: float) -> int:
	return roundi(metres * 1000.0)


static func from_milli(milli: int) -> float:
	return float(milli) / 1000.0
