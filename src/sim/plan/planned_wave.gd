class_name PlannedWave
extends RefCounted
## One wave of the run plan (VARIETY_SPEC 9.3): 1 option (the opener, a boss wave, a legacy wave) or 2.

var index: int = 0  ## 1-based wave number
var act: int = 1
var is_boss: bool = false
var options: Array[RouteOption] = []
var events: Array[PlannedEvent] = []


func hash_into(h: StateHasher) -> void:
	h.put_int(index)
	h.put_int(act)
	h.put_int(1 if is_boss else 0)
	h.put_int(options.size())
	for o: RouteOption in options:
		o.hash_into(h)
	h.put_int(events.size())
	for e: PlannedEvent in events:
		e.hash_into(h)


func to_dict() -> Dictionary:
	var option_rows: Array = []
	for o: RouteOption in options:
		option_rows.append(o.to_dict())
	var event_rows: Array = []
	for e: PlannedEvent in events:
		event_rows.append(e.to_dict())
	return {"index": index, "act": act, "is_boss": is_boss, "options": option_rows, "events": event_rows}


static func from_dict(d: Dictionary) -> PlannedWave:
	var w: PlannedWave = PlannedWave.new()
	w.index = roundi(SnapUtil.num(d.get("index", 0)))
	w.act = roundi(SnapUtil.num(d.get("act", 1)))
	w.is_boss = d.get("is_boss", false) == true
	var option_rows: Array = d.get("options", [])
	for row_v: Variant in option_rows:
		var row: Dictionary = row_v
		w.options.append(RouteOption.from_dict(row))
	var event_rows: Array = d.get("events", [])
	for row_v: Variant in event_rows:
		var row: Dictionary = row_v
		w.events.append(PlannedEvent.from_dict(row))
	return w
