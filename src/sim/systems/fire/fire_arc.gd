class_name FireArc
extends RefCounted
## Firing kind A (VARIETY_SPEC 3.3): the target takes full damage, then up to `chains` jumps, each to the nearest
## not-yet-hit enemy within `chain_range_m` of the last (lowest id on ties), each jump x `chain_falloff`. Pushes
## CHAIN_ARC per jump.
# TODO(V2-C)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
