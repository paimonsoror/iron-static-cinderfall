class_name CoreHooks
extends RefCounted
## The core-side hook points of directives (CONTENT 3.3, 3.4, 3.5): one function per hook. The callers are the systems
## that own the moment (CoreAttackSystem, AbilitySystem, PhaseSystem); each call point is added by the owner of that
## system in its own wave. Call points that exist today: `on_core_hit` (CoreAttackSystem._hit_core) and, as an interim,
## `on_wave_cleared` (DraftSystem.open). The others are listed under "needs owner" in the V4-C report:
##   on_core_changed  callers of SimWorld.set_core_hp (CoreAttackSystem.damage_core)   allow_defeat  PhaseSystem.post_step
##   on_ability, on_emp, on_shield_end  AbilitySystem.activate / _apply_emp / _end   step  once per combat tick
## Every function does nothing on the legacy content. Blasts and bolts of the core are DamageSource.CORE; their kills
## queue their own chain blasts through DeathHooks, never recursion.

const PLATING_DAMAGE: float = 25.0  ## reactive_plating, per stack
const VENT_EVERY_HITS: int = 10  ## ember_vent
const VENT_DAMAGE: float = 120.0
const VENT_RADIUS_M: float = 5.0
const SWITCH_CORE_FRAC: float = 0.2  ## dead_mans_switch
const SWITCH_DAMAGE: float = 600.0
const SWITCH_RADIUS_M: float = 8.0
const LASH_DAMAGE: float = 40.0  ## core_lash
const LASH_PERIOD_TICKS: PackedInt32Array = [90, 72, 54]  ## 1.5 s, 1.2 s, 0.9 s by stack
const TALLY_GUARD_TICKS: int = 300  ## the_tally halves at most once per 5 s
const AMBER_FRAC: float = 0.5  ## amber_surge
const INTEREST_FRAC: float = 0.10  ## compound_interest
const INTEREST_CAP: int = 150
const OVERCLOCK_COST: float = 25.0  ## overclocked_core; the last 25 core HP are never taken
const CASCADE_TICKS: int = 360  ## cascade takes 6 s off the other two cooldowns
const OVERLOAD_DAMAGE: float = 60.0  ## emp_overload, per stack
const SHIELD_BURST_DAMAGE: float = 150.0
const SHIELD_BURST_RADIUS_M: float = 6.0


## reactive_plating, ember_vent, the_tally, amber_surge, dead_mans_switch: after an enemy hit on the core was applied.
## `hp_damage` is what the core lost (the shield took the rest). Order: plating, tally, vent, surge, switch.
static func on_core_hit(world: SimWorld, enemy_index: int, hp_damage: float, _absorbed: float) -> void:
	if world.content.run == null:
		return
	var plating: int = ModRules.held(world, &"reactive_plating")
	if plating > 0 and enemy_index >= 0 and enemy_index < world.enemies.capacity and world.enemies.alive[enemy_index] == 1:
		DamageResolver.hit_ex(
			world, enemy_index, PLATING_DAMAGE * float(plating), DamageResolver.F_IGNORE_ARMOR | DamageResolver.F_AREA,
			DamageSource.Id.CORE
		)
	if hp_damage > 0.0:
		_tally_loses_half(world)
	if ModRules.held(world, &"ember_vent") > 0 and world.combat.core_hits % VENT_EVERY_HITS == 0:
		_blast_at_core(world, VENT_RADIUS_M, VENT_DAMAGE)
	if hp_damage > 0.0:
		on_core_changed(world, world.core_hp + hp_damage, world.core_hp)
	if world.core_hp <= 0.0:
		var _saved: bool = not allow_defeat(world)


## amber_surge: the core went from `before` to `after`. The first drop below half starts a free Shield. Only a crossing
## counts, and the core does not heal during a wave, so it happens at most once per wave. Calling it twice for the same
## change is harmless (a shield that is already up is not started again).
static func on_core_changed(world: SimWorld, before: float, after: float) -> void:
	if world.content.run == null or ModRules.held(world, &"amber_surge") <= 0:
		return
	var line: float = AMBER_FRAC * world.core_max_hp
	if before >= line and after < line and after > 0.0:
		start_free_shield(world)


## dead_mans_switch: called when core_hp <= 0. True = the run is lost; false = the switch saved the core (once per run):
## the core is left at 20% of its maximum and 600 damage hits every enemy within 8 m of it.
static func allow_defeat(world: SimWorld) -> bool:
	if world.content.run == null or world.core_hp > 0.0 or not HookMemory.switch_armed(world):
		return true
	HookMemory.spend_switch(world)
	world.set_core_hp(SWITCH_CORE_FRAC * world.core_max_hp)
	_blast_at_core(world, SWITCH_RADIUS_M, SWITCH_DAMAGE)
	return false


## field_weld, compound_interest, borrowed_time: before the first await of the intermission. The 2% repair of field_weld is skipped after a mod_no_breather wave ("no core repair").
static func on_wave_cleared(world: SimWorld) -> void:
	if world.content.run == null:
		return
	var weld: float = world.mods.core_regen_wave
	if weld > 0.0 and not DraftSystem.breather_denied(world):
		ModSystem.repair_core(world, weld * world.core_max_hp)
	if ModRules.held(world, &"compound_interest") > 0:
		world.add_scrap(mini(INTEREST_CAP, floori(float(world.scrap) * INTEREST_FRAC)))
	if HookMemory.raw(world, &"borrowed_time") > 0:
		HookMemory.add_borrowed_wave(world)
		ModSystem.recompute(world)


## cascade, overclocked_core: an ability was activated.
static func on_ability(world: SimWorld, ability_index: int) -> void:
	if world.content.run == null:
		return
	if ModRules.held(world, &"cascade") > 0:
		for a: int in mini(world.abilities.cooldown_left.size(), world.content.abilities.size()):
			if a != ability_index:
				world.abilities.cooldown_left[a] = maxi(0, world.abilities.cooldown_left[a] - CASCADE_TICKS)
	if ModRules.held(world, &"overclocked_core") > 0 and world.core_hp > OVERCLOCK_COST:
		world.set_core_hp(maxf(OVERCLOCK_COST, world.core_hp - OVERCLOCK_COST))


## emp_overload: the EMP was activated and its stun is applied. 60 damage per stack to every stunned enemy (no recursion:
## a kill queues its blast) and every ward breaks.
static func on_emp(world: SimWorld) -> void:
	var stacks: int = ModRules.held(world, &"emp_overload")
	if world.content.run == null or stacks <= 0:
		return
	var store: EnemyStore = world.enemies
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.stun_ticks[i] <= 0:
			continue
		if world.ext.ward_milli[i] > 0:
			world.ext.ward_milli[i] = 0
			world.events.push(SimEventKind.Id.WARD_BROKEN, store.id[i])
		DamageResolver.hit_ex(
			world, i, OVERLOAD_DAMAGE * float(stacks), DamageResolver.F_AREA, DamageSource.Id.HAZARD
		)


## shield_burst: the shield ended or broke (AbilitySystem._end, after it started the cooldown). 150 damage within 6 m of
## the core. amber_surge: a free shield that ends gives the Shield cooldown back as it was when the shield started.
static func on_shield_end(world: SimWorld) -> void:
	if world.content.run == null:
		return
	var kept: int = HookMemory.free_shield_cooldown(world)
	if kept >= 0:
		world.abilities.cooldown_left[Ids.AB_SHIELD] = kept
		HookMemory.end_free_shield(world)
	if ModRules.held(world, &"shield_burst") > 0:
		_blast_at_core(world, SHIELD_BURST_RADIUS_M, SHIELD_BURST_DAMAGE)


## core_lash: once per combat tick. Every period (1.5 s, 1.2 s, 0.9 s by stack, on the global tick) the core fires a bolt
## of 40 at the best-ranked enemy that is attacking it.
static func step(world: SimWorld) -> void:
	if world.content.run == null or not GameState.is_combat(world.phase):
		return
	var stacks: int = ModRules.held(world, &"core_lash")
	if stacks <= 0 or world.tick % LASH_PERIOD_TICKS[stacks - 1] != 0:
		return
	var target: int = lash_target(world)
	if target >= 0:
		DamageResolver.hit_ex(world, target, LASH_DAMAGE, DamageResolver.F_AREA, DamageSource.Id.CORE)


## The store index of the best-ranked enemy attacking the core (Targeting.compare from the core), or -1.
static func lash_target(world: SimWorld) -> int:
	var store: EnemyStore = world.enemies
	var arena: ArenaDef = world.content.arena
	var best: int = -1
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.state[i] != EnemyStore.ST_ATTACKING:
			continue
		if best < 0 or Targeting.compare(world, i, best, arena.core_x, arena.core_z):
			best = i
	return best


## A Shield that starts for free (amber_surge): the ability is active (the shield of an inactive ability breaks the
## invariant of the sim) with the absorb and the duration it has with its upgrades, and the Shield cooldown stays as it
## was: the cooldown before the start is kept in HookMemory and given back by `on_shield_end` (AbilitySystem._end starts
## the cooldown when any shield ends). Nothing happens while a shield is up.
static func start_free_shield(world: SimWorld) -> void:
	var st: AbilityState = world.abilities
	if world.shield_hp > 0.0 or st.active_left[Ids.AB_SHIELD] > 0:
		return
	var def: AbilityDef = world.content.abilities[Ids.AB_SHIELD]
	var absorb: float = def.absorb + world.mods.shield_absorb_add
	HookMemory.begin_free_shield(world, st.cooldown_left[Ids.AB_SHIELD])
	st.active_left[Ids.AB_SHIELD] = def.duration_ticks + roundi(world.mods.shield_dur_add * float(SimWorld.TICK_RATE))
	world.shield_hp = absorb
	world.events.push(SimEventKind.Id.ABILITY_ACTIVATED, Ids.AB_SHIELD, 0)
	world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, absorb, absorb)


## the_tally: damage through an empty shield halves the bonus, at most once per 5 s.
static func _tally_loses_half(world: SimWorld) -> void:
	if ModRules.held(world, &"the_tally") <= 0:
		return
	var last: int = HookMemory.tally_last_tick(world)
	if last > 0 and world.tick - last < TALLY_GUARD_TICKS:
		return
	HookMemory.set_tally(world, floori(float(HookMemory.tally_pct(world)) / 2.0), world.tick)


## A blast centred on the core (radius x area_mul), full damage everywhere inside, source CORE.
static func _blast_at_core(world: SimWorld, radius: float, damage: float) -> void:
	var arena: ArenaDef = world.content.arena
	AreaDamage.blast(
		world, arena.core_x, arena.core_z, radius * world.mods.area_mul, damage, 1.0, DamageResolver.F_AREA,
		DamageSource.Id.CORE
	)
