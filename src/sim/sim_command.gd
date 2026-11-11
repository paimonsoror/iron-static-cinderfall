class_name SimCommand
extends RefCounted
## The only external input to the sim.

enum Kind { PURCHASE, ABILITY, SKIP_INTERMISSION }

var command_id: int  ## unique per run, > 0
var kind: int
var arg: int  ## upgrade index or ability index; 0 for SKIP
var tick: int = -1  ## filled in by SimWorld when applied


static func purchase(command_id_value: int, upgrade_index: int) -> SimCommand:
	return _make(command_id_value, Kind.PURCHASE, upgrade_index)


static func ability(command_id_value: int, ability_index: int) -> SimCommand:
	return _make(command_id_value, Kind.ABILITY, ability_index)


static func skip(command_id_value: int) -> SimCommand:
	return _make(command_id_value, Kind.SKIP_INTERMISSION, 0)


static func _make(command_id_value: int, kind_value: int, arg_value: int) -> SimCommand:
	var c: SimCommand = SimCommand.new()
	c.command_id = command_id_value
	c.kind = kind_value
	c.arg = arg_value
	return c
