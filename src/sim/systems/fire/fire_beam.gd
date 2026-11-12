class_name FireBeam
extends RefCounted
## Firing kind B (VARIETY_SPEC 3.3): a hit every 6 ticks on the locked target; the damage ramps per consecutive hit;
## no magazine (heat).
# TODO(V4-W)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
