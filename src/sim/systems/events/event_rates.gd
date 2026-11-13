class_name EventRates
extends RefCounted
## The rates that events, modifiers and jammers put on the player's tools (VARIETY_SPEC 7.4, 13.2; CONTENT 5, 6). Pure
## reads of the world: AbilitySystem asks for the cooldown ticks of this tick, TurretSystem for the fire rate of a pad.
##
## Ability cooldowns: a Static Front freezes them (no tick passes); otherwise the rate is ModState.ability_cd_rate_mul
## times the jammer rate (the jammer's `cooldown_rate` while at least one jammer lives and is not stunned). A rate that
## is not 1.0 skips or repeats cooldown ticks with an integer pattern of the tick number, so it needs no state.
## Turrets: Core Surge x2, ModState.t_rate_mul, the fire-rate level sentry_link gives them (TurretRules), last_stand_protocol,
## `od_turrets` while Overdrive runs, and the jammer aura (the jammer's `turret_rate_mult` for a pad inside `aura_radius`).
## A Static Front puts the jammer auras down.

const RATE_ONE: int = 1000


## True while a Static Front keeps abilities (and the jammer auras) down.
static func lock_active(world: SimWorld) -> bool:
	return world.events_state.ability_lock_ticks > 0


## How many cooldown ticks pass on the current tick: 0 under a Static Front, else the rate's pattern (1 at rate 1.0).
static func cooldown_ticks(world: SimWorld) -> int:
	if lock_active(world):
		return 0
	var rate: int = cooldown_rate_milli(world)
	if rate == RATE_ONE:
		return 1
	return maxi(0, _passed(world.tick, rate) - _passed(world.tick - 1, rate))


## Ability cooldown rate x 1000 (1000 = full speed) without the Static Front freeze.
static func cooldown_rate_milli(world: SimWorld) -> int:
	var rate: float = world.mods.ability_cd_rate_mul
	var jam: float = jammer_cooldown_rate(world)
	if jam < 1.0:
		rate *= jam
	return maxi(0, roundi(rate * 1000.0))


## The slowest `cooldown_rate` among the jammers that are alive and not stunned; 1.0 with none or under a Static Front.
static func jammer_cooldown_rate(world: SimWorld) -> float:
	if lock_active(world) or not _has_jammers(world):
		return 1.0
	var store: EnemyStore = world.enemies
	var rate: float = 1.0
	var i: int = store.type.find(Ids.EN_JAMMER)  # a freed slot has type 0, so a hit is a living jammer
	while i >= 0:
		if store.alive[i] == 1 and store.stun_ticks[i] == 0:
			rate = minf(rate, world.content.enemies[Ids.EN_JAMMER].beh(&"cooldown_rate", 1.0))
		i = store.type.find(Ids.EN_JAMMER, i + 1)
	return rate


## Fire rate x 1000 of the turret on `pad` this tick (1000 = the base rate).
static func turret_rate_milli(world: SimWorld, pad: int) -> int:
	var es: EventState = world.events_state
	var rate: float = world.mods.t_rate_mul * ModRules.last_stand_turret_rate(world)
	var inherited: int = TurretRules.rate_level(world)
	if inherited > 0:
		rate *= 1.0 + world.content.upgrades[Ids.UP_FIRE_RATE].per_level * float(inherited)
	if es.turret_rate_ticks > 0:
		rate *= float(es.turret_rate_milli) / 1000.0
	if world.abilities.is_active(Ids.AB_OVERDRIVE) and world.mods.has_flag(&"od_turrets"):
		rate *= float(world.content.abilities[Ids.AB_OVERDRIVE].fire_rate_mult_milli) / 1000.0
	rate *= jammer_turret_rate(world, world.turrets.x[pad], world.turrets.z[pad])
	return maxi(0, roundi(rate * 1000.0))


## The `turret_rate_mult` of the weakest jammer aura that covers (x, z); 1.0 when none does.
static func jammer_turret_rate(world: SimWorld, x: float, z: float) -> float:
	if lock_active(world) or not _has_jammers(world):
		return 1.0
	var store: EnemyStore = world.enemies
	var def: EnemyDef = world.content.enemies[Ids.EN_JAMMER]
	var reach: float = def.beh(&"aura_radius")
	var rate: float = 1.0
	var i: int = store.type.find(Ids.EN_JAMMER)
	while i >= 0:
		if store.alive[i] == 1 and store.stun_ticks[i] == 0:
			var dx: float = store.x[i] - x
			var dz: float = store.z[i] - z
			if dx * dx + dz * dz <= reach * reach:
				rate = minf(rate, def.beh(&"turret_rate_mult", 1.0))
		i = store.type.find(Ids.EN_JAMMER, i + 1)
	return rate


## True while the turrets are offline (brownout, Low Power, a stomp).
static func turrets_offline(world: SimWorld) -> bool:
	return world.events_state.turret_offline_ticks > 0


## True during the 10 s of a Core Surge (the Warden's reload and vent are instant while it lasts).
static func surge_active(world: SimWorld) -> bool:
	var es: EventState = world.events_state
	return es.turret_rate_ticks > 0 and es.turret_rate_milli > RATE_ONE


## True when the content has the jammer type (the legacy content has four enemies only).
static func _has_jammers(world: SimWorld) -> bool:
	return world.content.run != null and Ids.EN_JAMMER < world.content.enemies.size()


## Whole cooldown ticks that have passed by tick `t` at `rate` (x 1000): floor(t * rate / 1000).
static func _passed(t: int, rate: int) -> int:
	return floori(float(t * rate) / 1000.0)
