class_name AreaDamage
extends RefCounted
## Area hits (VARIETY_SPEC 9.5 rule 1, 13.2): victims come from SpatialHash.query and are processed in id order; every
## hit goes through DamageResolver.hit_ex with F_AREA. Pushes AREA_BLAST(kind, radius in cm, x, z). Never recursion:
## a death caused here queues its own blast through DeathHooks and HazardSystem.
# TODO(V2-C)


## Damages every living enemy within `radius` of (x, z): full `damage` at the centre, `damage * edge_frac` at the edge.
## `flags` are DamageResolver.F_*; `source` is a DamageSource.Id. Returns the number of enemies hit.
static func blast(
	_world: SimWorld, _x: float, _z: float, _radius: float, _damage: float, _edge_frac: float, _flags: int, _source: int
) -> int:
	return 0
