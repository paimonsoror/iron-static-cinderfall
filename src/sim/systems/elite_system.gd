class_name EliteSystem
extends RefCounted
## Elites (VARIETY_SPEC 5.2, CONTENT 4.3): a bodied enemy with one or two affixes. The plan decides who is an elite and
## which affixes it carries (PlanElites: the combination rules and the forbidden pairs); this file gives the affixes
## their effect. SimWorld.spawn_enemy asks `spawn_hp` for every spawn and calls `apply` for an elite. Writes
## EnemyExtState.hp_scale_milli, ward_milli (WARDED) and fuse_ticks (the REGENERATING delay; an elite never has a fuse:
## a burster is never elite). Pushes ELITE_SPAWNED(enemy id, affix mask).
##
## Where each affix acts:
##   PLATED       `armor_add` (DamageResolver.effective_armor adds it) and HP x1.3 (`spawn_hp`)
##   SWIFT        StatusSystem multiplies NavState.speed_mul
##   VOLATILE     `on_killed`: a death blast through the hazard queue, like the burster's
##   REGENERATING `regen_tick` (StatusSystem calls it per elite); StatusSystem.absorb restarts the delay on every hit
##   WARDED       a personal ward in ext.ward_milli (StatusSystem.absorb drains it, StatusSystem refills it)
##   MAGNETIC, SHROUDED   Targeting
##   OVERCLOCKER  AuraFields.overclock (speed and attack period of the enemies around it)
##   ANCHORED     StatusSystem.apply_stun / apply_slow and MovementSystem.knockback refuse; a stun set elsewhere is cleared
##   LEECHING     `on_core_hit` (CoreAttackSystem calls it after a hit that reached the core)
## The affix numbers below have no field in data/enemies.json yet (AffixDef holds ops only): first-pass values of
## CONTENT 4.3, to move into the data when the schema gets a place for them.

## Positions in OpDef.AFFIX_FLAGS, and in NavState.aff (the affix mask that carries the flag).
const A_VOLATILE: int = 0
const A_REGEN: int = 1
const A_WARDED: int = 2
const A_MAGNETIC: int = 3
const A_OVERCLOCK: int = 4
const A_ANCHORED: int = 5
const A_LEECH: int = 6
const A_SHROUD: int = 7

const VOLATILE_RADIUS_M: float = 3.0
const VOLATILE_DAMAGE: float = 120.0
const VOLATILE_CORE_DAMAGE: float = 50.0
const VOLATILE_CORE_RANGE_M: float = 3.0
const REGEN_DELAY_TICKS: int = 120  ## 2 s without damage
const REGEN_FRAC_PER_S: float = 0.02
const REGEN_PULSE_TICKS: int = 30
const WARD_FRAC: float = 0.4  ## of max HP
const WARD_REGEN_TICKS: int = 300  ## 5 s without absorbing
const MAGNETIC_RANGE_M: float = 12.0
const OVERCLOCK_RANGE_M: float = 4.0
const OVERCLOCK_SPEED_MUL: float = 1.3
const OVERCLOCK_PERIOD_MUL: float = 0.8
const LEECH_RANGE_M: float = 4.0
const LEECH_HEAL: float = 30.0
const SHROUD_RANGE_M: float = 12.0


## Hit points a newly spawned enemy starts with: the type's hp x the act tier x the wave modifier (enemy_hp_mul), and
## for an elite x RunDef.elite_hp_mult x the `hp_mul` of its affixes. A boss uses BossDef.hp as it is. The legacy
## content gets the plain value of the type. SimWorld.spawn_enemy calls it.
static func spawn_hp(world: SimWorld, def: EnemyDef, affix_mask: int) -> float:
	var content: ContentSet = world.content
	var run: RunDef = content.run
	if run == null:
		return def.hp
	if def.is_boss:
		for b: BossDef in content.bosses:
			if b.enemy_index == def.index:
				return b.hp
		return def.hp
	var hp: float = def.hp * hp_tier(world) * world.mods.enemy_hp_mul
	if affix_mask != 0:
		hp *= run.elite_hp_mult * stat(content, affix_mask, &"hp_mul", 1.0)
	return hp


## Marks store index `enemy_index` as an elite with `affix_mask`: the HP scale, the personal ward of WARDED at full.
## SimWorld.spawn_enemy calls it for a mask != 0, after it set F_ELITE, the mask and the hit points.
static func apply(world: SimWorld, enemy_index: int, affix_mask: int) -> void:
	var store: EnemyStore = world.enemies
	var ext: EnemyExtState = world.ext
	var def: EnemyDef = world.content.enemies[store.type[enemy_index]]
	if def.hp > 0.0:
		ext.hp_scale_milli[enemy_index] = roundi(store.max_hp[enemy_index] / def.hp * 1000.0)
	if (affix_mask & world.nav.aff[A_WARDED]) != 0:
		ext.ward_milli[enemy_index] = StatusSystem.ward_max_milli(world, enemy_index)
	world.events.push(SimEventKind.Id.ELITE_SPAWNED, store.id[enemy_index], affix_mask)


## Living elites (the cap is RunDef.max_elites_alive).
static func alive_elites(world: SimWorld) -> int:
	var n: int = 0
	for i: int in world.enemies.high_water:
		if world.enemies.alive[i] == 1 and world.ext.is_elite(i):
			n += 1
	return n


## The HP tier of the current act (ActDef.hp_mult); 1 in the legacy content and before the run has an act.
static func hp_tier(world: SimWorld) -> float:
	var run: RunDef = world.content.run
	if run == null:
		return 1.0
	var act: ActDef = run.act(world.phase_state.act)
	return act.hp_mult if act != null else 1.0


## One affix mask per OpDef.AFFIX_FLAGS entry: the affixes of `content` that carry the flag (0 = none does).
static func flag_masks(content: ContentSet) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(OpDef.AFFIX_FLAGS.size())
	for a: AffixDef in content.affixes:
		for op: OpDef in a.ops:
			if op.kind != OpDef.Kind.FLAG:
				continue
			var at: int = OpDef.AFFIX_FLAGS.find(String(op.target))
			if at >= 0:
				out[at] |= 1 << a.index
	return out


## The per-enemy stat `stat_name` (OpDef.AFFIX_STATS) of an elite with `affix_mask`, starting from `base`: every `add`
## op adds, every `mul` op multiplies (so "hp_mul add 0.3" on a base of 1 is x1.3).
static func stat(content: ContentSet, affix_mask: int, stat_name: StringName, base: float) -> float:
	var value: float = base
	if affix_mask == 0:
		return value
	for a: AffixDef in content.affixes:
		if (affix_mask & (1 << a.index)) == 0:
			continue
		for op: OpDef in a.ops:
			if op.target != stat_name:
				continue
			if op.kind == OpDef.Kind.ADD:
				value += op.value
			elif op.kind == OpDef.Kind.MUL:
				value *= op.value
	return value


## True when the enemy at `enemy_index` carries the affix flag `which` (an A_* constant).
static func has(world: SimWorld, enemy_index: int, which: int) -> bool:
	return (world.ext.affix_mask[enemy_index] & world.nav.aff[which]) != 0


static func is_anchored(world: SimWorld, enemy_index: int) -> bool:
	return (world.ext.affix_mask[enemy_index] & world.nav.aff[A_ANCHORED]) != 0


## The armor PLATED adds to the enemy at `enemy_index` (0 for everything else). DamageResolver.effective_armor adds it
## to the type's armor.
static func armor_add(world: SimWorld, enemy_index: int) -> float:
	var mask: int = world.ext.affix_mask[enemy_index]
	if mask == 0:
		return 0.0
	return stat(world.content, mask, &"armor_add", 0.0)


## REGENERATING, once per tick per elite: the delay since the last damage runs down (StatusSystem.absorb restarts it),
## then the elite heals REGEN_FRAC_PER_S of its max HP per second in pulses. A stunned elite does not regenerate.
static func regen_tick(world: SimWorld, enemy_index: int) -> void:
	var ext: EnemyExtState = world.ext
	var store: EnemyStore = world.enemies
	if ext.fuse_ticks[enemy_index] > 0:
		ext.fuse_ticks[enemy_index] -= 1
		return
	if store.stun_ticks[enemy_index] > 0 or store.hp[enemy_index] >= store.max_hp[enemy_index]:
		return
	if (world.tick + store.id[enemy_index]) % REGEN_PULSE_TICKS != 0:
		return
	var amount: float = store.max_hp[enemy_index] * REGEN_FRAC_PER_S * float(REGEN_PULSE_TICKS) / 60.0
	StatusSystem.heal_enemy(world, store.id[enemy_index], enemy_index, amount)


## VOLATILE: the elite's death queues a blast on the enemies around it (and on the core when it dies next to the cage,
## unless it consumed itself). StatusSystem.on_enemy_killed calls it before the store slot is freed.
static func on_killed(world: SimWorld, enemy_index: int, source: int) -> void:
	if not world.ext.is_elite(enemy_index) or not has(world, enemy_index, A_VOLATILE):
		return
	var store: EnemyStore = world.enemies
	var arena: ArenaDef = world.content.arena
	var x: float = store.x[enemy_index]
	var z: float = store.z[enemy_index]
	var core_part: float = 0.0
	var reach: float = arena.core_radius + VOLATILE_CORE_RANGE_M
	var dx: float = x - arena.core_x
	var dz: float = z - arena.core_z
	if source != DeathHooks.SOURCE_SELF and dx * dx + dz * dz <= reach * reach:
		core_part = VOLATILE_CORE_DAMAGE * CoreAttackSystem.core_mult(world)
	HazardSystem.queue_blast(
		world, world.tick + DeathHooks.CHAIN_DELAY_TICKS, HazardState.K_BLAST, x, z, VOLATILE_RADIUS_M, VOLATILE_DAMAGE,
		1.0, DamageResolver.F_AREA, DamageSource.Id.HAZARD, core_part, store.type[enemy_index]
	)


## LEECHING: a core hit of this elite that took core HP (a hit the shield absorbed whole heals nothing) heals every
## enemy within LEECH_RANGE_M of it, itself included, by LEECH_HEAL. Returns the number of enemies healed.
static func on_core_hit(world: SimWorld, enemy_index: int, hp_damage: float) -> int:
	if hp_damage <= 0.0 or world.ext.affix_mask[enemy_index] == 0 or not has(world, enemy_index, A_LEECH):
		return 0
	var store: EnemyStore = world.enemies
	var near: PackedInt32Array = PackedInt32Array()
	AreaDamage.query(world, store.x[enemy_index], store.z[enemy_index], LEECH_RANGE_M, near)
	var healed: int = 0
	var healer_id: int = store.id[enemy_index]
	for j: int in near:
		if StatusSystem.heal_enemy(world, healer_id, j, LEECH_HEAL) > 0.0:
			healed += 1
	return healed
