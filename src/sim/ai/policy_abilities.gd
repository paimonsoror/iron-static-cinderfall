class_name PolicyAbilities
extends RefCounted
## The `balanced` bot's use of the three abilities and the player-triggered events (CONTENT 13, 9 and 6). Decisions
## depend on the world and on the bot's note of the core a call ago, never on how often `act` is called: the scans that
## cost something run on a fixed tick modulus, and an await freezes the tick.

## EMP at this many attackers (or to interrupt a telegraphed boss attack).
const EMP_ATTACKERS: int = 10
## Shield on the hit that takes the core from at least this fraction to below it (or before a lance beam).
const SHIELD_CORE: float = 0.6
## Overdrive on a boss in range, or at this many enemies alive.
const OVERDRIVE_ALIVE: int = 20
## Deadfall Strike on a cluster this big within STRIKE_RADIUS_M, or on an elite pair.
const STRIKE_CLUSTER: int = 10
const STRIKE_RADIUS_M: float = 4.0
## Core Vent at this many attackers while the core is above VENT_CORE.
const VENT_ATTACKERS: int = 12
const VENT_CORE: float = 0.4
## Ticks between two scans for a cluster (the scan is quadratic in the enemies alive).
const SCAN_PERIOD: int = 12
## Any other player-called event (the data may add some) is called when it is legal and this many enemies are alive.
const OTHER_CALL_ALIVE: int = 15


## One look at the field: submits whatever the heuristics ask for this tick. Abilities are legal only in combat.
static func act(world: SimWorld, bot: PolicyBot) -> void:
	if not GameState.is_combat(world.phase):
		return
	var attackers: int = PolicySenses.attackers(world)
	if _ready(world, Ids.AB_EMP) and (attackers >= EMP_ATTACKERS or PolicySenses.boss_telegraphing(world)):
		bot.send(world, SimCommand.Kind.ABILITY, Ids.AB_EMP)
	if _ready(world, Ids.AB_SHIELD) and (_crossed_shield_line(world, bot) or PolicySenses.lance_beam_coming(world)):
		bot.send(world, SimCommand.Kind.ABILITY, Ids.AB_SHIELD)
	if _ready(world, Ids.AB_OVERDRIVE) and (PolicySenses.boss_in_range(world) or world.alive_count() >= OVERDRIVE_ALIVE):
		bot.send(world, SimCommand.Kind.ABILITY, Ids.AB_OVERDRIVE)
	_act_events(world, bot, attackers)


static func _ready(world: SimWorld, ability_index: int) -> bool:
	return world.ability_block_reason(ability_index) == Reason.Id.OK


## The core was at or above SHIELD_CORE at the last call and is below it now.
static func _crossed_shield_line(world: SimWorld, bot: PolicyBot) -> bool:
	if bot.last_core_hp < 0.0:
		return false
	var before: float = bot.last_core_hp / maxf(world.core_max_hp, 1.0)
	return before >= SHIELD_CORE and PolicySenses.core_fraction(world) < SHIELD_CORE


static func _act_events(world: SimWorld, bot: PolicyBot, attackers: int) -> void:
	var strike: int = world.content.event_index(&"deadfall_strike")
	if strike >= 0 and world.tick % SCAN_PERIOD == 0 and EventSystem.block_reason(world, strike) == Reason.Id.OK:
		if PolicySenses.densest(world, STRIKE_RADIUS_M) >= STRIKE_CLUSTER or PolicySenses.elite_pair(world, STRIKE_RADIUS_M):
			bot.send(world, SimCommand.Kind.CALL_EVENT, strike)
	var vent: int = world.content.event_index(&"core_vent")
	if vent >= 0 and attackers >= VENT_ATTACKERS and PolicySenses.core_fraction(world) > VENT_CORE:
		if EventSystem.block_reason(world, vent) == Reason.Id.OK:
			bot.send(world, SimCommand.Kind.CALL_EVENT, vent)
	for def: EventDef in world.content.events:
		if def.who != EventDef.Who.PLAYER or def.index == strike or def.index == vent:
			continue
		if world.alive_count() >= OTHER_CALL_ALIVE and EventSystem.block_reason(world, def.index) == Reason.Id.OK:
			bot.send(world, SimCommand.Kind.CALL_EVENT, def.index)
