class_name PolicyDps
extends RefCounted
## The damage per second a carried weapon deals to one living enemy (V4-T), from the data alone: the weapon's hit as the
## sim computes it (DamageResolver.warden_amount), the armor the enemy keeps against that weapon (armor_ignore, the
## armor_piercing level), the shots per second the build allows, and the share of time the weapon can fire (a magazine
## reloads, a heat weapon vents). Rough on purpose: it ranks weapons against ONE target, which is what a boss fight asks.
## Pure functions of the world; no random stream.

## A cone puts about this share of its pellets on one target.
const CONE_HIT_SHARE: float = 0.7
## A spinning-up weapon averages this share of its top rate; a beam reaches this share of the way from its base to its ramp cap.
const SPIN_UP_SHARE: float = 0.85
const BEAM_RAMP_SHARE: float = 0.75


## Damage per second of the weapon in `slot` on enemy `enemy_index` (0 for an empty slot).
static func vs(world: SimWorld, slot: int, enemy_index: int) -> float:
	var weapon_index: int = PolicyLoadout.weapon_in(world, slot)
	if weapon_index < 0 or enemy_index < 0:
		return 0.0
	var def: WeaponDef = world.content.weapons[weapon_index]
	var level: int = world.arsenal.slot_level[slot]
	var hit: float = DamageResolver.warden_amount(world, enemy_index, def, level)
	if def.kind == WeaponDef.Kind.BEAM and def.ramp_cap > def.damage:
		hit *= (def.damage + (def.ramp_cap - def.damage) * BEAM_RAMP_SHARE) / maxf(def.damage, 0.001)
	var armor: float = DamageResolver.effective_armor(world, enemy_index, DamageResolver.weapon_flags(def))
	var per_hit: float = maxf(1.0, hit - armor)
	var rate: float = float(ArsenalSystem.sps_milli(world, def)) / 1000.0
	if def.spin_up_ticks > 0:
		rate *= SPIN_UP_SHARE
	if def.charge_ticks > 0 and rate > 0.0:
		rate = 1.0 / (1.0 / rate + float(def.charge_ticks) / float(SimWorld.TICK_RATE))
	return per_hit * hits_per_shot(def) * rate * uptime(world, slot, def, rate)


## How many hits one shot lands on a single target.
static func hits_per_shot(def: WeaponDef) -> float:
	match def.kind:
		WeaponDef.Kind.CONE:
			return float(maxi(1, def.pellets)) * CONE_HIT_SHARE
		WeaponDef.Kind.MISSILES:
			return float(maxi(1, def.salvo))
		_:
			return 1.0


## The share of time the weapon fires: magazine time over magazine plus reload, or time to the heat cap over that plus
## the vent. 1.0 for a weapon with neither.
static func uptime(world: SimWorld, slot: int, def: WeaponDef, rate: float) -> float:
	if rate <= 0.0:
		return 0.0
	var fire_s: float = 0.0
	var pause_s: float = 0.0
	if def.is_heat():
		var shots: float = ceilf(float(ArsenalSystem.heat_cap_of(world, slot)) / float(maxi(1, def.heat_per_shot)))
		fire_s = shots / rate
		pause_s = float(ArsenalSystem.vent_ticks_of(world, def)) / float(SimWorld.TICK_RATE)
	elif def.magazine > 0:
		fire_s = float(ArsenalSystem.magazine_size_of(world, slot)) / rate
		pause_s = float(ArsenalSystem.reload_ticks_of(world, def)) / float(SimWorld.TICK_RATE)
	else:
		return 1.0
	return fire_s / maxf(fire_s + pause_s, 0.001)
