class_name FireLine
extends RefCounted
## Firing kind L (VARIETY_SPEC 3.3): a `charge_ticks` wind-up during which the line is fixed on the target's position,
## then every enemy within area_m / 2 of the segment is hit, sorted by distance.
# TODO(V4-W)


static func fire(_world: SimWorld, _slot: int, _def: WeaponDef, _source: int) -> bool:
	return false
