class_name CommandLog
extends RefCounted
## Applied commands in order, each with the tick it was applied at. Enough to replay a run.

var entries: Array[SimCommand] = []


func to_dicts() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for c: SimCommand in entries:
		rows.append({"tick": c.tick, "id": c.command_id, "kind": c.kind, "arg": c.arg})
	return rows


static func from_dicts(rows: Array) -> CommandLog:
	var out: CommandLog = CommandLog.new()
	for r: Variant in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = r
		var c: SimCommand = SimCommand.new()
		c.tick = _int_of(row.get("tick", -1))
		c.command_id = _int_of(row.get("id", 0))
		c.kind = _int_of(row.get("kind", 0))
		c.arg = _int_of(row.get("arg", 0))
		out.entries.append(c)
	return out


## JSON gives floats for numbers; accept both.
static func _int_of(v: Variant) -> int:
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		return roundi(f)
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i
	return 0
