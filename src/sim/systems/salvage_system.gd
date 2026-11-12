class_name SalvageSystem
extends RefCounted
## Crates on the field, the bank and the salvage choice (tick step 14; VARIETY_SPEC 3.4, CONTENT 2 and 7). The only
## writer of SalvageState. Contents are drawn from the stream `crate:<crate_ordinal>` when a crate is secured.
## Pushes CRATE_DROPPED, CRATE_SECURED, CRATE_LOST and SALVAGE_RESOLVED. Called every tick of a live run.
# TODO(V2-C): the stub drops nothing and refuses SALVAGE with NOT_AWAITING.

## Actions of the SALVAGE command: arg = choice * 16 + action.
const ACTION_SLOT_0: int = 0
const ACTION_SLOT_1: int = 1
const ACTION_SLOT_2: int = 2
const ACTION_LEVEL_UP: int = 8
const ACTION_SCRAP: int = 9


static func step(_world: SimWorld) -> void:
	pass


## Lands a crate at drop point `point` (ArenaDef.drop_points). False when a crate is already on the field.
static func drop_crate(_world: SimWorld, _point: int, _boss_crate: bool) -> bool:
	return false


## Opens the next banked crate for the SALVAGE await (fills SalvageState.offer). False when the bank is empty.
static func open_next(_world: SimWorld) -> bool:
	return false


## SALVAGE: `arg` = choice * 16 + action. Returns a Reason.Id.
static func resolve(_world: SimWorld, _command_id: int, _arg: int) -> int:
	return Reason.Id.NOT_AWAITING


## Scrap for scrapping a crate in the current act.
static func scrap_value(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or run.salvage_scrap_by_act.is_empty():
		return 0
	return run.salvage_scrap_by_act[clampi(world.phase_state.act - 1, 0, run.salvage_scrap_by_act.size() - 1)]
