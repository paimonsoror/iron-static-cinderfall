class_name FireHitscan
extends RefCounted
## Firing kind H (VARIETY_SPEC 3.3): as today; optional `pierce` hits the next enemy within 2 m behind the target on
## the shooter-target line. LMG strays use the `aim` stream.
# TODO(V2-C)


## One shot of `def` from weapon slot `slot` at the Warden's current target. True when a shot left the weapon.
static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
