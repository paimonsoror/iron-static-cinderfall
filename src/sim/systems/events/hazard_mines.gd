class_name HazardMines
extends RefCounted
## Mines on the ground (the `mine_layer` directive drops them; numbers in `hazards.mine` of events.json). A mine waits at
## (m_x, m_z) for the turret pad `m_owner`; the first living enemy that comes within `trigger_m` of it sets it off: the
## mine is gone and a K_MINE blast (radius_m, damage, armor applies) lands on the next tick. HazardSystem.step calls
## `step` every tick. A breach is covered too: a borer that emerges on a mine sets it off like any other enemy.


## Lays a mine for pad `pad` at (x, z). False when the pad already has `per_owner` mines on the field.
static func place(world: SimWorld, x: float, z: float, pad: int) -> bool:
	var h: HazardState = world.hazards
	var mine_cap: int = roundi(HazardDrums.hazard_num(world, &"mine", &"per_owner", 3.0))
	var laid: int = 0
	for m: int in h.m_owner:
		if m == pad:
			laid += 1
	if laid >= mine_cap:
		return false
	h.m_x.append(x)
	h.m_z.append(z)
	h.m_owner.append(pad)
	return true


## Mines waiting now.
static func count(world: SimWorld) -> int:
	return world.hazards.m_x.size()


## Sets off every mine with a living enemy inside its trigger distance (oldest mine first).
static func step(world: SimWorld) -> void:
	var h: HazardState = world.hazards
	if h.m_x.is_empty():
		return
	var trigger: float = HazardDrums.hazard_num(world, &"mine", &"trigger_m", 0.9)
	var radius: float = HazardDrums.hazard_num(world, &"mine", &"radius_m", 2.0)
	var damage: float = HazardDrums.hazard_num(world, &"mine", &"damage", 90.0)
	var near: PackedInt32Array = PackedInt32Array()
	var at: int = 0
	while at < h.m_x.size():
		if AreaDamage.query(world, h.m_x[at], h.m_z[at], trigger, near) == 0:
			at += 1
			continue
		var x: float = h.m_x[at]
		var z: float = h.m_z[at]
		var pad: int = h.m_owner[at]
		h.m_x.remove_at(at)
		h.m_z.remove_at(at)
		h.m_owner.remove_at(at)
		var _seq: int = HazardSystem.queue_blast(
			world, world.tick + 1, HazardState.K_MINE, x, z, radius, damage, 1.0, DamageResolver.F_AREA,
			DamageSource.Id.TURRET_0 + clampi(pad, 0, 1), 0.0, -1
		)
