class_name FireCone
extends RefCounted
## Firing kind C (VARIETY_SPEC 3.3): pellets go to the enemies inside range and the cone around the aim line, nearest
## first, at most 3 per enemy while other targets remain; knockback moves light enemies along the shot direction.
# TODO(V4-W)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
