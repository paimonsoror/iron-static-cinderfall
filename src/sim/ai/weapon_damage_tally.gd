class_name WeaponDamageTally
extends RefCounted
## Enemy hp removed per weapon (VARIETY_SPEC 14.2 S11 "primary weapon = most damage dealt"). The sim keeps damage per
## source, not per weapon, so the harness feeds each tick's drained events here: damage dealt by the Warden belongs to
## the weapon in the active slot, damage of the off-hand to the weapon of the first holstered slot. Read-only on the
## world; it needs no random stream.

## Hp removed per index of ContentSet.weapons.
var damage: PackedFloat64Array = PackedFloat64Array()


## Adds the ENEMY_DAMAGED events of one step. Call it right after the step, with the events that step produced.
func feed(world: SimWorld, events: Array[SimEvent]) -> void:
	if damage.size() < world.content.weapons.size():
		damage.resize(world.content.weapons.size())
	for e: SimEvent in events:
		if e.kind != SimEventKind.Id.ENEMY_DAMAGED:
			continue
		if e.a < 0:
			continue
		var weapon_index: int = _weapon_of(world, e.b)
		if weapon_index >= 0:
			damage[weapon_index] += e.f


## The weapon that fired a hit of `source` (DamageSource.Id), or -1 for turrets, strikes and hazards.
static func _weapon_of(world: SimWorld, source: int) -> int:
	if source == DamageSource.Id.WARDEN:
		return clampi(world.warden.weapon_index, 0, world.content.weapons.size() - 1)
	if source == DamageSource.Id.WARDEN_OFFHAND:
		var holstered: int = 1 - world.arsenal.active
		var weapon_index: int = world.arsenal.slot_weapon[clampi(holstered, 0, ArsenalState.MAX_SLOTS - 1)]
		return weapon_index if weapon_index >= 0 else 0
	return -1


## Index of the weapon with the most damage, ties to the lower index; -1 when nothing was dealt.
func primary() -> int:
	var best: int = -1
	var best_damage: float = 0.0
	for i: int in damage.size():
		if damage[i] > best_damage:
			best = i
			best_damage = damage[i]
	return best
