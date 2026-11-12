class_name FireMissiles
extends RefCounted
## Firing kind M (VARIETY_SPEC 3.3): `salvo` delayed hits, one per chosen target (Targeting.pick_many), landing
## `flight_ticks` later at the target's position at launch, with a small splash.
# TODO(V4-W)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
