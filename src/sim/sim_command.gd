class_name SimCommand
extends RefCounted
## The only external input to the sim.

## Append only (VARIETY_SPEC 13.2). `arg` per kind: PURCHASE upgrade index, ABILITY ability index, SKIP_INTERMISSION 0,
## PICK_DIRECTIVE slot, SKIP_DRAFT 0, REROLL 0, BUY_OUT slot, PATCH_CORE 0, PICK_ROUTE option,
## SALVAGE choice * 16 + action (action 0..2 = take in that slot, 8 = level up, 9 = scrap), SWAP_WEAPON slot,
## CALL_EVENT event index.
enum Kind {
	PURCHASE, ABILITY, SKIP_INTERMISSION,
	PICK_DIRECTIVE, SKIP_DRAFT, REROLL, BUY_OUT, PATCH_CORE, PICK_ROUTE, SALVAGE, SWAP_WEAPON, CALL_EVENT,
}

var command_id: int  ## unique per run, > 0
var kind: int
var arg: int  ## see Kind
var tick: int = -1  ## filled in by SimWorld when applied


static func purchase(command_id_value: int, upgrade_index: int) -> SimCommand:
	return _make(command_id_value, Kind.PURCHASE, upgrade_index)


static func ability(command_id_value: int, ability_index: int) -> SimCommand:
	return _make(command_id_value, Kind.ABILITY, ability_index)


static func skip(command_id_value: int) -> SimCommand:
	return _make(command_id_value, Kind.SKIP_INTERMISSION, 0)


static func pick_directive(command_id_value: int, slot: int) -> SimCommand:
	return _make(command_id_value, Kind.PICK_DIRECTIVE, slot)


static func skip_draft(command_id_value: int) -> SimCommand:
	return _make(command_id_value, Kind.SKIP_DRAFT, 0)


static func reroll(command_id_value: int) -> SimCommand:
	return _make(command_id_value, Kind.REROLL, 0)


static func buy_out(command_id_value: int, slot: int) -> SimCommand:
	return _make(command_id_value, Kind.BUY_OUT, slot)


static func patch_core(command_id_value: int) -> SimCommand:
	return _make(command_id_value, Kind.PATCH_CORE, 0)


static func pick_route(command_id_value: int, option: int) -> SimCommand:
	return _make(command_id_value, Kind.PICK_ROUTE, option)


## `choice` = which weapon of the crate (0 for a normal crate); `action` = 0..2 take in that slot, 8 level up, 9 scrap.
static func salvage(command_id_value: int, choice: int, action: int) -> SimCommand:
	return _make(command_id_value, Kind.SALVAGE, choice * 16 + action)


static func swap_weapon(command_id_value: int, slot: int) -> SimCommand:
	return _make(command_id_value, Kind.SWAP_WEAPON, slot)


static func call_event(command_id_value: int, event_index: int) -> SimCommand:
	return _make(command_id_value, Kind.CALL_EVENT, event_index)


static func _make(command_id_value: int, kind_value: int, arg_value: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.command_id = command_id_value
	c.kind = kind_value
	c.arg = arg_value
	return c
