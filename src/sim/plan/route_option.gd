class_name RouteOption
extends RefCounted
## One of the (at most two) threats offered before a wave (VARIETY_SPEC 2.4, 9.3). What is shown is what spawns:
## `groups` is the existing SpawnGroupDef, so SpawnSystem consumes it unchanged.

var pack_index: int = -1
var modifier_index: int = -1  ## -1 = none
var reward_index: int = -1  ## -1 = none
var hot: bool = false
var groups: Array[SpawnGroupDef] = []
var elites: Array[PlannedElite] = []


func total_count() -> int:
	var total: int = 0
	for g: SpawnGroupDef in groups:
		total += g.count
	return total


func hash_into(h: StateHasher) -> void:
	h.put_int(pack_index)
	h.put_int(modifier_index)
	h.put_int(reward_index)
	h.put_int(1 if hot else 0)
	h.put_int(groups.size())
	for g: SpawnGroupDef in groups:
		h.put_int(g.enemy_index)
		h.put_int(g.count)
		h.put_int(g.start_tick)
		h.put_int(g.interval_ticks)
		h.put_int(String(g.region_id).hash())
	h.put_int(elites.size())
	for e: PlannedElite in elites:
		e.hash_into(h)


func to_dict() -> Dictionary:
	var group_rows: Array = []
	for g: SpawnGroupDef in groups:
		group_rows.append({
			"enemy_index": g.enemy_index, "count": g.count, "start_tick": g.start_tick,
			"interval_ticks": g.interval_ticks, "region_id": String(g.region_id),
		})
	var elite_rows: Array = []
	for e: PlannedElite in elites:
		elite_rows.append(e.to_dict())
	return {
		"pack_index": pack_index, "modifier_index": modifier_index, "reward_index": reward_index, "hot": hot,
		"groups": group_rows, "elites": elite_rows,
	}


static func from_dict(d: Dictionary) -> RouteOption:
	var o: RouteOption = RouteOption.new()
	o.pack_index = roundi(SnapUtil.num(d.get("pack_index", -1)))
	o.modifier_index = roundi(SnapUtil.num(d.get("modifier_index", -1)))
	o.reward_index = roundi(SnapUtil.num(d.get("reward_index", -1)))
	o.hot = d.get("hot", false) == true
	var group_rows: Array = d.get("groups", [])
	for row_v: Variant in group_rows:
		var row: Dictionary = row_v
		var g: SpawnGroupDef = SpawnGroupDef.new()
		g.enemy_index = roundi(SnapUtil.num(row.get("enemy_index", 0)))
		g.count = roundi(SnapUtil.num(row.get("count", 0)))
		g.start_tick = roundi(SnapUtil.num(row.get("start_tick", 0)))
		g.interval_ticks = roundi(SnapUtil.num(row.get("interval_ticks", 1)))
		g.region_id = StringName(str(row.get("region_id", "")))
		o.groups.append(g)
	var elite_rows: Array = d.get("elites", [])
	for row_v: Variant in elite_rows:
		var row: Dictionary = row_v
		o.elites.append(PlannedElite.from_dict(row))
	return o
