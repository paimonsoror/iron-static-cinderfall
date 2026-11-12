class_name PlannedElite
extends RefCounted
## One scheduled body that enters as an elite (VARIETY_SPEC 9.3).

var group: int = 0  ## index into RouteOption.groups
var ordinal: int = 0  ## which body of the group
var affix_mask: int = 0  ## bit i = AffixDef index i


func hash_into(h: StateHasher) -> void:
	h.put_int(group)
	h.put_int(ordinal)
	h.put_int(affix_mask)


func to_dict() -> Dictionary:
	return {"group": group, "ordinal": ordinal, "affix_mask": affix_mask}


static func from_dict(d: Dictionary) -> PlannedElite:
	var e: PlannedElite = PlannedElite.new()
	e.group = roundi(SnapUtil.num(d.get("group", 0)))
	e.ordinal = roundi(SnapUtil.num(d.get("ordinal", 0)))
	e.affix_mask = roundi(SnapUtil.num(d.get("affix_mask", 0)))
	return e
