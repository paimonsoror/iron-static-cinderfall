class_name BossTremorRig
extends RefCounted
## NODE 7 // TREMOR RIG (`tremor_rig`; VARIETY_SPEC 6, CONTENT 5): act II. Stomps every 10 s (turrets offline 4 s, the magazine emptied; an active Shield negates
## it) and opens borer breaches at 66% and 33% HP.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
##
## Stomp timeline from the spawn tick S: the ring shows at S + 510 (BOSS_TELEGRAPH ATK_STOMP, 90), the stomp lands at
## S + 600, and so on every 600 ticks; a stun holds the clock and the telegraph. When it lands with the Shield up it does
## nothing (F_BRACED); otherwise the turrets are offline for 240 ticks and the magazine of the weapon in the Warden's
## hands is emptied (a heat weapon has none and keeps firing). The stomp never touches the core.
## Breaches: on the tick T its HP is at or below 66% (then 33%) the phase advances and the cracks show
## (BOSS_TELEGRAPH ATK_BREACH, 150, an announcement: BossState keeps `telegraph_attack` for the stomp); at T + 150
## three borers come out of each of two breach points of the arena. `breach_points` gives the cracked points to the
## view. Borers that find a cap full wait in the spawn queue. One breach at a time: a hit that crosses both
## thresholds opens the second after the first. An arena without breach points or a content without the borer turns a
## breach into an early stomp (VARIETY_SPEC 15.5).
## Answers to the stomp: the Shield as a brace, a heat weapon in hand, and a stun to delay it.
## Behaviour keys (BossDef.behaviour, fallbacks of CONTENT 5): stomp_period_s 10, stomp_warn_s 1.5,
## stomp_offline_s 4, breach_frac_1 0.66, breach_frac_2 0.33, breach_points 2, breach_borers 3, breach_warn_s (the
## borer's `breach_delay_s`, 2.5).

const T_CLOCK: int = 0  ## ticks since the last stomp (or the spawn)
const T_STAGE: int = 1  ## breaches started so far (0..2) = the phase
const T_BREACH: int = 2  ## ticks until the cracked points open (0 = no breach pending)
const T_POINT: int = 3  ## first of MAX_POINTS entries: index into ArenaDef.breach_points + 1 (0 = none)
const MAX_POINTS: int = 4
const BREACH_STAGES: int = 2
const BORER_RING_M: float = 0.5  ## borers of one breach point come out on a ring of this radius


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 3


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(world: SimWorld, enemy_index: int) -> void:
	BossKit.adopt(world, enemy_index, phase_count(), T_POINT + MAX_POINTS)
	world.boss.set_flag(BossState.F_BEGUN, true)


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	if b.timers[T_BREACH] > 0:
		b.timers[T_BREACH] -= 1
		if b.timers[T_BREACH] == 0:
			_open_breach(world)
	elif b.timers[T_STAGE] < _stage_for(world, enemy_index):
		_start_breach(world)
	if BossKit.is_stunned(world, enemy_index) or not BossKit.past_spawn_tick(world, enemy_index):
		return
	b.timers[T_CLOCK] += 1
	if b.telegraph_attack == BossState.ATK_STOMP:
		if BossKit.telegraph_tick(world, BossState.ATK_STOMP):
			b.timers[T_CLOCK] = 0
			_stomp(world)
	elif b.timers[T_CLOCK] >= period_ticks(world) - warn_ticks(world):
		BossKit.telegraph(world, BossState.ATK_STOMP, warn_ticks(world))


static func period_ticks(world: SimWorld) -> int:
	return maxi(2, BossKit.ticks(world, &"stomp_period_s", 10.0))


## Ticks the ring shows before a stomp (always shorter than the period).
static func warn_ticks(world: SimWorld) -> int:
	return clampi(BossKit.ticks(world, &"stomp_warn_s", 1.5), 1, period_ticks(world) - 1)


## The breach points that are cracked right now (empty when no breach is pending), for the view.
static func breach_points(world: SimWorld) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var b: BossState = world.boss
	if b.boss_type != Ids.EN_TREMOR_RIG or b.timers[T_BREACH] <= 0:
		return out
	var points: PackedVector2Array = world.content.arena.breach_points
	for k: int in MAX_POINTS:
		var at: int = b.timers[T_POINT + k] - 1
		if at >= 0 and at < points.size():
			out.append(points[at])
	return out


## The stomp lands: nothing behind an active Shield, else turrets offline and the magazine emptied.
static func _stomp(world: SimWorld) -> void:
	var b: BossState = world.boss
	var braced: bool = BossKit.shield_up(world)
	b.set_flag(BossState.F_BRACED, braced)
	if braced:
		return
	BossEffects.turrets_offline(world, BossKit.ticks(world, &"stomp_offline_s", 4.0))
	BossEffects.dump_magazine(world)


## Breaches the rig's HP calls for: one at or below `breach_frac_1`, two at or below `breach_frac_2`.
static func _stage_for(world: SimWorld, enemy_index: int) -> int:
	var frac: float = BossKit.hp_frac(world, enemy_index)
	if frac <= BossKit.num(world, &"breach_frac_2", 0.33):
		return BREACH_STAGES
	if frac <= BossKit.num(world, &"breach_frac_1", 0.66):
		return 1
	return 0


## The next breach begins: the phase advances and its points crack. The points follow the arena's list in order (the
## first breach takes the first two, the second the next two), so no random stream is drawn.
static func _start_breach(world: SimWorld) -> void:
	var b: BossState = world.boss
	var stage: int = b.timers[T_STAGE]
	b.timers[T_STAGE] = stage + 1
	BossKit.set_phase(world, stage + 1)
	var points: PackedVector2Array = world.content.arena.breach_points
	var want: int = mini(mini(BossKit.count(world, &"breach_points", 2), MAX_POINTS), points.size())
	if want <= 0 or not BossKit.has_type(world, Ids.EN_BORER):
		if b.telegraph_attack != BossState.ATK_STOMP:
			b.timers[T_CLOCK] = maxi(b.timers[T_CLOCK], period_ticks(world) - warn_ticks(world) - 1)
		return
	for k: int in MAX_POINTS:
		b.timers[T_POINT + k] = ((stage * want + k) % points.size()) + 1 if k < want else 0
	var borer: EnemyDef = world.content.enemies[Ids.EN_BORER]
	b.timers[T_BREACH] = BossKit.ticks(world, &"breach_warn_s", borer.beh(&"breach_delay_s", 2.5))
	BossKit.announce(world, BossState.ATK_BREACH, b.timers[T_BREACH])


## The cracked points open: `breach_borers` borers at each, on a small ring, in a fixed order.
static func _open_breach(world: SimWorld) -> void:
	var b: BossState = world.boss
	var points: PackedVector2Array = world.content.arena.breach_points
	var borers: int = BossKit.count(world, &"breach_borers", 3)
	for k: int in MAX_POINTS:
		var at: int = b.timers[T_POINT + k] - 1
		b.timers[T_POINT + k] = 0
		if at < 0 or at >= points.size():
			continue
		var px: float = points[at].x
		var pz: float = points[at].y
		for j: int in borers:
			var angle: float = TAU * float(j) / float(maxi(1, borers))
			BossEffects.send(world, Ids.EN_BORER, px + cos(angle) * BORER_RING_M, pz + sin(angle) * BORER_RING_M)
