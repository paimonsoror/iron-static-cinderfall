class_name AbilitySystem
extends RefCounted
## EMP, shield, overdrive (ARCH 6.6 "Economy, abilities, flow"). All timers are integer ticks.
##
## Timer convention: activation (tick step 2) sets the full duration or cooldown, and this system's step (tick
## step 5) of the same tick already counts one tick of it. So a 480 tick shield activated by a command at tick T
## is active for the steps of ticks T .. T + 479 and ends in the step of tick T + 479; a 2,100 tick EMP cooldown
## activated at tick T allows the next activation at tick T + 2,100. Called outside step() (tests), the value is
## the full duration until the next step.
##
## Cooldowns run in every non-terminal phase (intermissions included). Activation is legal only in SPAWNING and
## CLEARING.
##
## Variety content (VARIETY_SPEC 7.4, 13.2): a Static Front answers every activation with LOCKED_BY_EVENT and freezes the
## cooldowns (an ability that is already active runs to its end); the cooldown rate is ModState.ability_cd_rate_mul times
## the jammer rate (EventRates.cooldown_ticks); the cooldowns, durations, shield and EMP numbers take the directive stats
## emp_cd_mul / shield_cd_mul / od_cd_mul / ability_cd_mul (factors on the base cooldown), shield_dur_add / od_dur_add /
## emp_stun_add (seconds added) and shield_absorb_add (hit points added). With the neutral ModState of the legacy content
## every number is the definition's own.


## Returns a Reason.Id; pushes ABILITY_ACTIVATED or ABILITY_REJECTED. A rejection starts no cooldown.
static func activate(world: SimWorld, command_id: int, ability_index: int) -> int:
	var reason: int = block_reason(world, ability_index)
	if reason != Reason.Id.OK:
		world.events.push(SimEventKind.Id.ABILITY_REJECTED, ability_index, reason, command_id)
		return reason
	var def: AbilityDef = world.content.abilities[ability_index]
	var st: AbilityState = world.abilities
	world.events.push(SimEventKind.Id.ABILITY_ACTIVATED, ability_index, command_id)
	var duration: int = duration_ticks_of(world, ability_index)
	st.active_left[ability_index] = maxi(0, duration)
	if def.cooldown_start == AbilityDef.CooldownStart.ON_ACTIVATE or duration <= 0:
		st.cooldown_left[ability_index] = cooldown_ticks_of(world, ability_index)
	match ability_index:
		Ids.AB_EMP:
			_apply_emp(world, def)
		Ids.AB_SHIELD:
			world.shield_hp = absorb_of(world)
			world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, world.shield_hp, world.shield_hp)
			EventSystem.on_shield_activated(world)
		_:
			pass
	CoreHooks.on_ability(world, ability_index)
	return Reason.Id.OK


## Reason.Id.OK when the ability can start now. Check order: state, id, already active, locked by a Static Front,
## cooling down.
static func block_reason(world: SimWorld, ability_index: int) -> int:
	if world.phase != GameState.Id.SPAWNING and world.phase != GameState.Id.CLEARING:
		return Reason.Id.WRONG_STATE
	if ability_index < 0 or ability_index >= world.content.abilities.size() or ability_index >= world.abilities.active_left.size():
		return Reason.Id.UNKNOWN_ID
	if world.abilities.active_left[ability_index] > 0:
		return Reason.Id.ALREADY_ACTIVE
	if EventRates.lock_active(world):
		return Reason.Id.LOCKED_BY_EVENT
	if world.abilities.cooldown_left[ability_index] > 0:
		return Reason.Id.ON_COOLDOWN
	return Reason.Id.OK


## The cooldown an activation of the ability starts, in ticks: the definition's, times the ability's own directive factor
## (emp_cd_mul, shield_cd_mul, od_cd_mul) and ability_cd_mul.
static func cooldown_ticks_of(world: SimWorld, ability_index: int) -> int:
	var def: AbilityDef = world.content.abilities[ability_index]
	var factor: float = world.mods.ability_cd_mul
	match ability_index:
		Ids.AB_EMP:
			factor *= world.mods.emp_cd_mul
		Ids.AB_SHIELD:
			factor *= world.mods.shield_cd_mul
		Ids.AB_OVERDRIVE:
			factor *= world.mods.od_cd_mul
	if factor == 1.0:
		return def.cooldown_ticks
	return maxi(0, roundi(float(def.cooldown_ticks) * factor))


## How long the ability stays active, in ticks: the definition's plus shield_dur_add or od_dur_add (seconds).
static func duration_ticks_of(world: SimWorld, ability_index: int) -> int:
	var def: AbilityDef = world.content.abilities[ability_index]
	if def.duration_ticks <= 0:
		return def.duration_ticks
	var extra: float = 0.0
	match ability_index:
		Ids.AB_SHIELD:
			extra = world.mods.shield_dur_add
		Ids.AB_OVERDRIVE:
			extra = world.mods.od_dur_add
	return maxi(1, def.duration_ticks + roundi(extra * 60.0))


## The shield's absorb: the definition's plus shield_absorb_add.
static func absorb_of(world: SimWorld) -> float:
	return world.content.abilities[Ids.AB_SHIELD].absorb + world.mods.shield_absorb_add


## The EMP's stun of an ordinary enemy, in ticks: the definition's plus emp_stun_add (seconds).
static func emp_stun_ticks_of(world: SimWorld) -> int:
	return world.content.abilities[Ids.AB_EMP].stun_ticks + roundi(world.mods.emp_stun_add * 60.0)


## Ability timers, stun and immunity countdowns, shield expiry (tick step 5, every non-terminal phase).
static func step(world: SimWorld) -> void:
	var st: AbilityState = world.abilities
	var cooling: int = EventRates.cooldown_ticks(world)
	for a: int in mini(world.content.abilities.size(), st.active_left.size()):
		var def: AbilityDef = world.content.abilities[a]
		var was_active: bool = st.active_left[a] > 0
		if was_active:
			st.active_left[a] -= 1
			var depleted: bool = a == Ids.AB_SHIELD and world.shield_hp <= 0.0
			if st.active_left[a] == 0 or depleted:
				_end(world, a, def)
		# A cooldown that starts when the ability ends does not run while it is active, nor on the ending tick.
		if st.cooldown_left[a] > 0 and (def.cooldown_start == AbilityDef.CooldownStart.ON_ACTIVATE or not was_active):
			st.cooldown_left[a] = maxi(0, st.cooldown_left[a] - cooling)
	_step_enemy_timers(world)


## The run just ended (PhaseSystem calls this as it finishes the run, before `RUN_FINISHED`): every ability that is
## still active ends now, with the usual `ABILITY_ENDED` and, for the shield, `SHIELD_CHANGED`. `step()` is a no-op
## after the run, so without this a shield that the killing blow emptied (or an overdrive that outlived the last
## enemy) would read as active forever.
static func end_all(world: SimWorld) -> void:
	var st: AbilityState = world.abilities
	for a: int in mini(world.content.abilities.size(), st.active_left.size()):
		if st.active_left[a] > 0:
			_end(world, a, world.content.abilities[a], false)


## Every living enemy without stun immunity: stun_ticks = max(stun_ticks, stun). The boss gets boss_stun_ticks.
static func _apply_emp(world: SimWorld, def: AbilityDef) -> void:
	var store: EnemyStore = world.enemies
	var stun: int = emp_stun_ticks_of(world)
	world.events_state.emp_until = world.tick + stun
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.stun_immune_ticks[i] > 0:
			continue
		var is_boss: bool = world.content.enemies[store.type[i]].is_boss
		var ticks: int = def.boss_stun_ticks if is_boss else stun
		if ticks > store.stun_ticks[i]:
			store.stun_ticks[i] = ticks
			world.events.push(SimEventKind.Id.ENEMY_STUNNED, store.id[i], ticks)
	CoreHooks.on_emp(world)


## The active period is over (time ran out, or the shield was used up): clear effects and start the cooldown. A shield that
## ends calls CoreHooks.on_shield_end afterwards (shield_burst, the cooldown of a free amber_surge shield); `end_all` at the
## end of a run asks for no hooks.
static func _end(world: SimWorld, ability_index: int, def: AbilityDef, hooks: bool = true) -> void:
	var st: AbilityState = world.abilities
	st.active_left[ability_index] = 0
	if def.cooldown_start == AbilityDef.CooldownStart.ON_END:
		st.cooldown_left[ability_index] = cooldown_ticks_of(world, ability_index)
	if ability_index == Ids.AB_SHIELD:
		world.shield_hp = 0.0
		world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, 0.0, def.absorb)
	world.events.push(SimEventKind.Id.ABILITY_ENDED, ability_index)
	if hooks and ability_index == Ids.AB_SHIELD:
		CoreHooks.on_shield_end(world)


## Counts stun and immunity down. A boss whose stun reaches 0 becomes immune for boss_immunity_ticks (counted from
## the next tick on).
static func _step_enemy_timers(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var immunity_ticks: int = world.content.abilities[Ids.AB_EMP].boss_immunity_ticks
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if store.stun_ticks[i] > 0:
			store.stun_ticks[i] -= 1
			if store.stun_ticks[i] == 0 and world.content.enemies[store.type[i]].is_boss:
				store.stun_immune_ticks[i] = immunity_ticks
		elif store.stun_immune_ticks[i] > 0:
			store.stun_immune_ticks[i] -= 1
