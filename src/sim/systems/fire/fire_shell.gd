class_name FireShell
extends RefCounted
## Firing kind S (VARIETY_SPEC 3.3): the target point is the centre of the densest cluster in range; the hit lands
## `flight_ticks` later as a delayed area hit (HazardSystem.queue_hit) and leaves a pool.
# TODO(V4-W)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
