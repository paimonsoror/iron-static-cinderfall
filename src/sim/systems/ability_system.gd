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


## Returns a Reason.Id; pushes ABILITY_ACTIVATED or ABILITY_REJECTED. A rejection starts no cooldown.
static func activate(world: SimWorld, command_id: int, ability_index: int) -> int:
	var reason: int = block_reason(world, ability_index)
	if reason != Reason.Id.OK:
		world.events.push(SimEventKind.Id.ABILITY_REJECTED, ability_index, reason, command_id)
		return reason
	var def: AbilityDef = world.content.abilities[ability_index]
	var st: AbilityState = world.abilities
	world.events.push(SimEventKind.Id.ABILITY_ACTIVATED, ability_index, command_id)
	st.active_left[ability_index] = maxi(0, def.duration_ticks)
	if def.cooldown_start == AbilityDef.CooldownStart.ON_ACTIVATE or def.duration_ticks <= 0:
		st.cooldown_left[ability_index] = def.cooldown_ticks
	match ability_index:
		Ids.AB_EMP:
			_apply_emp(world, def)
		Ids.AB_SHIELD:
			world.shield_hp = def.absorb
			world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, world.shield_hp, def.absorb)
		_:
			pass
	return Reason.Id.OK


## Reason.Id.OK when the ability can start now. Check order: state, id, already active, cooling down.
static func block_reason(world: SimWorld, ability_index: int) -> int:
	if world.phase != GameState.Id.SPAWNING and world.phase != GameState.Id.CLEARING:
		return Reason.Id.WRONG_STATE
	if ability_index < 0 or ability_index >= world.content.abilities.size() or ability_index >= world.abilities.active_left.size():
		return Reason.Id.UNKNOWN_ID
	if world.abilities.active_left[ability_index] > 0:
		return Reason.Id.ALREADY_ACTIVE
	if world.abilities.cooldown_left[ability_index] > 0:
		return Reason.Id.ON_COOLDOWN
	return Reason.Id.OK


## Ability timers, stun and immunity countdowns, shield expiry (tick step 5, every non-terminal phase).
static func step(world: SimWorld) -> void:
	var st: AbilityState = world.abilities
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
			st.cooldown_left[a] -= 1
	_step_enemy_timers(world)


## Every living enemy without stun immunity: stun_ticks = max(stun_ticks, stun). The boss gets boss_stun_ticks.
static func _apply_emp(world: SimWorld, def: AbilityDef) -> void:
	var store: EnemyStore = world.enemies
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.stun_immune_ticks[i] > 0:
			continue
		var is_boss: bool = world.content.enemies[store.type[i]].is_boss
		var ticks: int = def.boss_stun_ticks if is_boss else def.stun_ticks
		if ticks > store.stun_ticks[i]:
			store.stun_ticks[i] = ticks
			world.events.push(SimEventKind.Id.ENEMY_STUNNED, store.id[i], ticks)


## The active period is over (time ran out, or the shield was used up): clear effects and start the cooldown.
static func _end(world: SimWorld, ability_index: int, def: AbilityDef) -> void:
	var st: AbilityState = world.abilities
	st.active_left[ability_index] = 0
	if def.cooldown_start == AbilityDef.CooldownStart.ON_END:
		st.cooldown_left[ability_index] = def.cooldown_ticks
	if ability_index == Ids.AB_SHIELD:
		world.shield_hp = 0.0
		world.events.push(SimEventKind.Id.SHIELD_CHANGED, 0, 0, 0.0, def.absorb)
	world.events.push(SimEventKind.Id.ABILITY_ENDED, ability_index)


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
