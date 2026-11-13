class_name FireBeam
extends RefCounted
## Firing kind B (VARIETY_SPEC 3.3): one hit per shot on the locked target (the cadence of the cutting torch, 10 a second,
## is one every 6 ticks); no magazine, the weapon runs on heat. The damage ramps with the hits in a row on one target:
## `damage` + `ramp_per_hit` x hits, at most `ramp_cap` (all before the weapon level multiplier). A new target, a vent, a
## swap and a pause with no target start the ramp again (ArsenalSystem clears `beam_target` and `beam_hits` for the last
## three). The hit is a direct hit, so `armor_ignore`, the shot hooks and the damage level all apply.

const HITS_CAP: int = 10000  ## the ramp has long saturated; keeps the hashed counter small


static func fire(world: SimWorld, slot: int, def: WeaponDef, source: int) -> bool:
	var w: WardenState = world.warden
	var target: int = world.enemies.index_of(w.target_id)
	if target < 0:
		return false
	var a: ArsenalState = world.arsenal
	if a.beam_target != w.target_id:
		a.beam_target = w.target_id
		a.beam_hits = 0
	world.events.push(SimEventKind.Id.SHOT_FIRED, source, w.target_id)
	var ramped: float = minf(def.ramp_cap, def.damage + def.ramp_per_hit * float(a.beam_hits))
	var scale: float = ramped / def.damage if def.damage > 0.0 else 1.0
	DamageResolver.warden_hit(world, target, def, a.slot_level[slot], scale, 0, source)
	a.beam_hits = mini(HITS_CAP, a.beam_hits + 1)
	return true
