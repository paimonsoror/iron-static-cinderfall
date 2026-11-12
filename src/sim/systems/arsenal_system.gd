class_name ArsenalSystem
extends RefCounted
## Weapon slots, swapping, magazines, heat and the dispatch on WeaponDef.kind to the fire files (VARIETY_SPEC 3).
## The only writer of ArsenalState (SalvageSystem changes slot contents through `give_weapon` and `level_up`).
## WeaponSystem.step delegates here once V2-C lands; WardenState.weapon_index, magazine and reload_ticks_left mirror
## the active slot.
# TODO(V2-C): slots, swap, heat, the arc projector. TODO(V4-W): levels and the other firing kinds.

## Slot states for the HUD (RunApi.weapon_slot "state").
const ST_READY: int = 0
const ST_RELOADING: int = 1
const ST_VENTING: int = 2
const ST_SWAPPING: int = 3
const ST_CHARGING: int = 4
const ST_EMPTY: int = 5


## Slot 0 gets the starting weapon with a full magazine. Called once by SimWorld._init.
static func init_world(world: SimWorld) -> void:
	world.arsenal.slot_magazine[0] = world.content.weapons[0].magazine


static func step(_world: SimWorld) -> void:
	pass


## SWAP_WEAPON: makes `slot` the active slot after swap_ticks. Returns a Reason.Id; pushes WEAPON_SWAPPED.
static func swap(_world: SimWorld, _command_id: int, _slot: int) -> int:
	return Reason.Id.WRONG_STATE


## Puts a weapon into a slot (salvage, kits) at level 1 with a full magazine.
static func give_weapon(_world: SimWorld, _slot: int, _weapon_index: int) -> void:
	pass


static func level_up(_world: SimWorld, _slot: int) -> void:
	pass


## The weapon in `slot`; the pistol for an empty slot.
static func weapon_of(world: SimWorld, slot: int) -> WeaponDef:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_weapon.size() or a.slot_weapon[slot] < 0:
		return world.content.weapons[0]
	return world.content.weapons[a.slot_weapon[slot]]


## ST_* of `slot`.
static func slot_state(world: SimWorld, slot: int) -> int:
	var a: ArsenalState = world.arsenal
	if slot < 0 or slot >= a.slot_count:
		return ST_EMPTY
	return ST_READY
