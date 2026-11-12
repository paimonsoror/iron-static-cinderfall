class_name BossSiegeHulk
extends RefCounted
## NODE 9 // SIEGE HULK (`siege_hulk`; VARIETY_SPEC 6, CONTENT 5): act III, always; the act I stand-in of the slice. One of three variants per run (plated, fed,
## overclocked). Every variant: below 25% HP its attack period is -30%.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
##
## The body is the plain heavy attacker it always was (three slots at the cage, its slam through CoreAttackSystem);
## this script adds the enrage and the variant. The variant is the plan's (`plan.boss_variant`, an index into
## RunDef.hulk_variants) and applies only to the Node 9 of the last act of a run with more than one act, the same
## rule the boss briefing uses: the act I stand-in of the slice has none (BossState.NO_VARIANT, 2 phases).
## Enrage: on the first step its HP is below `enrage_frac` the last phase begins (F_ENRAGED, BOSS_PHASE) and its
## attack timer never waits longer than `enrage_period_mult` x its period.
##   hulk_plated       armor 24; at or below 66% and 33% HP a layer of plating goes: armor 12, then 4, and it walks
##                     25% of its base speed faster each time. Phases: 3 plating stages and the enrage (4 pips).
##   hulk_fed          two reclaimers enter where the hulk entered, on the first step; every 20 s the dead ones are
##                     sent again (one that finds a cap full is owed until there is room). While one of them lives
##                     the hulk repairs 1% of its maximum HP once a second (DamageResolver.heal).
##   hulk_overclocked  while it walks: every 12 s a 1.5 s wind-up (BOSS_TELEGRAPH ATK_CHARGE, 90), then 3 s at
##                     three times its speed (F_CHARGING). From the spawn tick S: wind-up at S + 720, charge from
##                     S + 810 to S + 990, next wind-up at S + 1440. A stun during the charge stops it and lasts 2 s
##                     in all; a stun during the wind-up only holds it. At the cage there is nothing left to charge.
## Answers: plated - piercing, armor-ignoring weapons, the window after each shed; fed - the reclaimers are
## priority targets, a strike or a blast on them; overclocked - the EMP during the charge, raw damage before it lands.
## Behaviour keys (BossDef.behaviour, fallbacks of CONTENT 5): enrage_frac 0.25, enrage_period_mult 0.7;
## plated_armor_0 24, plated_armor_1 12, plated_armor_2 4, plated_frac_1 0.66, plated_frac_2 0.33,
## plated_speed_step 0.25; fed_escorts 2, fed_resend_s 20, fed_heal_frac_per_s 0.01; oc_period_s 12, oc_windup_s 1.5,
## oc_charge_s 3, oc_speed_mult 3, oc_cancel_stun_s 2.

const PLATED: StringName = &"hulk_plated"
const FED: StringName = &"hulk_fed"
const OVERCLOCKED: StringName = &"hulk_overclocked"

const T_CLOCK: int = 0  ## fed: ticks since the last re-send; overclocked: ticks since the last wind-up began
const T_CHARGE: int = 1  ## overclocked: ticks of the charge left
const T_HEAL: int = 2  ## fed: ticks toward the next repair pulse
const T_STAGE: int = 3  ## plated: layers of plating shed (0..2)
const T_ENTRY_X: int = 4  ## where the hulk entered, in millimetres (the reclaimers enter there)
const T_ENTRY_Z: int = 5
const T_ESCORT: int = 6  ## first of MAX_ESCORTS entries: enemy id, 0 = none, OWED = to be sent
const MAX_ESCORTS: int = 4
const OWED: int = -1
const HEAL_PULSE_TICKS: int = 60
const ESCORT_GAP_M: float = 1.2
const PLATED_PHASES: int = 4


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 2


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(world: SimWorld, enemy_index: int) -> void:
	var variant: int = _plan_variant(world)
	var plated: bool = variant >= 0 and world.content.run.hulk_variants[variant] == PLATED
	BossKit.adopt(world, enemy_index, PLATED_PHASES if plated else phase_count(), T_ESCORT + MAX_ESCORTS)
	var b: BossState = world.boss
	b.variant = variant
	b.timers[T_ENTRY_X] = BossKit.to_milli(world.enemies.x[enemy_index])
	b.timers[T_ENTRY_Z] = BossKit.to_milli(world.enemies.z[enemy_index])


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	if not b.has_flag(BossState.F_ENRAGED) and BossKit.hp_frac(world, enemy_index) < BossKit.num(world, &"enrage_frac", 0.25):
		b.set_flag(BossState.F_ENRAGED, true)
		BossKit.set_phase(world, b.phase_count - 1)
	if b.has_flag(BossState.F_ENRAGED):
		BossEffects.cap_attack_cd(world, enemy_index, enraged_period_ticks(world, enemy_index))
	match variant_id(world):
		PLATED:
			_step_plated(world, enemy_index)
		FED:
			_step_fed(world, enemy_index)
		OVERCLOCKED:
			_step_overclocked(world, enemy_index)
	b.set_flag(BossState.F_BEGUN, true)


## The id of the living hulk's variant (PLATED, FED, OVERCLOCKED), or empty for a hulk without one.
static func variant_id(world: SimWorld) -> StringName:
	var b: BossState = world.boss
	var run: RunDef = world.content.run
	if b.boss_type != Ids.EN_HULK or run == null or b.variant < 0 or b.variant >= run.hulk_variants.size():
		return &""
	return run.hulk_variants[b.variant]


## Ticks between two slams once enraged (the body's period with the wave's modifier x `enrage_period_mult`).
static func enraged_period_ticks(world: SimWorld, enemy_index: int) -> int:
	var def: EnemyDef = world.content.enemies[world.enemies.type[enemy_index]]
	var period: float = float(def.attack_period_ticks) * world.mods.enemy_attack_period_mul
	return maxi(1, roundi(period * BossKit.num(world, &"enrage_period_mult", 0.7)))


## The hulk's armor: its type's value, or the plating that is left on a plated one (BossSystem.armor_of).
static func armor_of(world: SimWorld, base_armor: float) -> float:
	if variant_id(world) != PLATED:
		return base_armor
	match world.boss.timers[T_STAGE]:
		0:
			return BossKit.num(world, &"plated_armor_0", 24.0)
		1:
			return BossKit.num(world, &"plated_armor_1", 12.0)
	return BossKit.num(world, &"plated_armor_2", 4.0)


## The factor on the hulk's walking speed right now (plating shed, a running charge); 1.0 otherwise. For the view.
static func speed_mult(world: SimWorld) -> float:
	match variant_id(world):
		PLATED:
			return 1.0 + BossKit.num(world, &"plated_speed_step", 0.25) * float(world.boss.timers[T_STAGE])
		OVERCLOCKED:
			if world.boss.has_flag(BossState.F_CHARGING):
				return BossKit.num(world, &"oc_speed_mult", 3.0)
	return 1.0


## The plan's variant when this hulk is the Node 9 of the last act, else BossState.NO_VARIANT.
static func _plan_variant(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or world.plan == null or run.acts.size() <= 1 or world.phase_state.act < run.acts.size():
		return BossState.NO_VARIANT
	var v: int = world.plan.boss_variant
	return v if v >= 0 and v < run.hulk_variants.size() else BossState.NO_VARIANT


static func _step_plated(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	var frac: float = BossKit.hp_frac(world, enemy_index)
	var stage: int = 0
	if frac <= BossKit.num(world, &"plated_frac_2", 0.33):
		stage = 2
	elif frac <= BossKit.num(world, &"plated_frac_1", 0.66):
		stage = 1
	if stage > b.timers[T_STAGE]:
		b.timers[T_STAGE] = stage
		if not b.has_flag(BossState.F_ENRAGED):
			BossKit.set_phase(world, stage)
	BossEffects.advance(world, enemy_index, speed_mult(world))


static func _step_fed(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	var es: EnemyStore = world.enemies
	var escorts: int = mini(BossKit.count(world, &"fed_escorts", 2), MAX_ESCORTS)
	if not BossKit.has_type(world, Ids.EN_RECLAIMER):
		return
	var resend: bool = not b.has_flag(BossState.F_BEGUN)
	if BossKit.past_spawn_tick(world, enemy_index):
		b.timers[T_CLOCK] += 1
		if b.timers[T_CLOCK] >= BossKit.ticks(world, &"fed_resend_s", 20.0):
			b.timers[T_CLOCK] = 0
			resend = true
	var alive: int = 0
	for k: int in escorts:
		var id: int = b.timers[T_ESCORT + k]
		if id > 0 and es.index_of(id) >= 0:
			alive += 1
			continue
		if resend:
			id = OWED
		if id == OWED:
			var side: float = ESCORT_GAP_M * float(floori(float(k) / 2.0) + 1) * (1.0 if k % 2 == 0 else -1.0)
			var j: int = BossEffects.send_now(
				world, Ids.EN_RECLAIMER, BossKit.from_milli(b.timers[T_ENTRY_X]), BossKit.from_milli(b.timers[T_ENTRY_Z]) + side
			)
			if j >= 0:
				id = es.id[j]
				alive += 1
		b.timers[T_ESCORT + k] = id
	if alive == 0:
		b.timers[T_HEAL] = 0
		return
	b.timers[T_HEAL] += 1
	if b.timers[T_HEAL] >= HEAL_PULSE_TICKS:
		b.timers[T_HEAL] = 0
		BossEffects.heal(world, enemy_index, heal_per_pulse(world, enemy_index))


## Hit points one repair pulse restores (one pulse a second while a reclaimer of the hulk lives).
static func heal_per_pulse(world: SimWorld, enemy_index: int) -> float:
	return world.enemies.max_hp[enemy_index] * BossKit.num(world, &"fed_heal_frac_per_s", 0.01)


static func _step_overclocked(world: SimWorld, enemy_index: int) -> void:
	var b: BossState = world.boss
	if world.enemies.state[enemy_index] == EnemyStore.ST_ATTACKING:
		_stop_charge(world)
		BossKit.clear_telegraph(world)
		return
	if BossKit.is_stunned(world, enemy_index):
		if b.has_flag(BossState.F_CHARGING):
			_stop_charge(world)
			BossEffects.extend_stun(world, enemy_index, BossKit.ticks(world, &"oc_cancel_stun_s", 2.0))
		return
	if not BossKit.past_spawn_tick(world, enemy_index):
		return
	if b.has_flag(BossState.F_CHARGING):
		BossEffects.advance(world, enemy_index, speed_mult(world))
		b.timers[T_CHARGE] -= 1
		if b.timers[T_CHARGE] <= 0:
			_stop_charge(world)
	b.timers[T_CLOCK] += 1
	if b.telegraph_attack == BossState.ATK_CHARGE:
		if BossKit.telegraph_tick(world, BossState.ATK_CHARGE):
			b.set_flag(BossState.F_CHARGING, true)
			b.timers[T_CHARGE] = BossKit.ticks(world, &"oc_charge_s", 3.0)
	elif b.timers[T_CLOCK] >= BossKit.ticks(world, &"oc_period_s", 12.0):
		b.timers[T_CLOCK] = 0
		BossKit.telegraph(world, BossState.ATK_CHARGE, BossKit.ticks(world, &"oc_windup_s", 1.5))


static func _stop_charge(world: SimWorld) -> void:
	world.boss.set_flag(BossState.F_CHARGING, false)
	world.boss.timers[T_CHARGE] = 0
