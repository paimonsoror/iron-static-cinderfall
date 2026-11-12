class_name PlannedEvent
extends RefCounted
## One world event of a planned wave (VARIETY_SPEC 9.3).

var event_index: int = -1  ## EventDef index
var start_offset: int = 0  ## ticks after the wave starts when the WARNING begins


func hash_into(h: StateHasher) -> void:
	h.put_int(event_index)
	h.put_int(start_offset)


func to_dict() -> Dictionary:
	return {"event_index": event_index, "start_offset": start_offset}


static func from_dict(d: Dictionary) -> PlannedEvent:
	var e: PlannedEvent = PlannedEvent.new()
	e.event_index = roundi(SnapUtil.num(d.get("event_index", -1)))
	e.start_offset = roundi(SnapUtil.num(d.get("start_offset", 0)))
	return e
