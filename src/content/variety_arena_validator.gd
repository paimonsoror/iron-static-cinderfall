class_name VarietyArenaValidator
extends RefCounted
## The arena rules of the variety content (VARIETY_SPEC 13.1, arena.json schema 2): drop, drum and breach points are
## free cells that reach the core; standoff points are free and every ring keeps at least one; rail lines cross no
## turret pad, no core and no Warden. `field` is the built FlowField (resolved by the caller; the content layer may
## not name sim classes), or null to skip the reachability part.

const ARENA: String = "arena.json"
const POINT_CLEAR_M: float = 0.3  ## a point must be at least this far from every obstacle


static func validate(e: PackedStringArray, c: ContentSet, field: Object) -> void:
	var a: ArenaDef = c.arena
	_points(e, a, field, "breach_points", a.breach_points)
	_points(e, a, field, "drop_points", a.drop_points)
	_points(e, a, field, "drum_points", a.drum_points)
	if a.drop_points.is_empty():
		_bad(e, "$.drop_points", "at least one drop point is required")
	for i: int in a.standoff_points.size():
		var p: Vector2 = a.standoff_points[i]
		if not ArenaBuilder.point_is_free(a, p.x, p.y, 0.0):
			_bad(e, "$.standoff", "standoff point %d (%s, %s) is blocked or outside the bounds" % [i, snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	for ring: int in a.standoff_radii.size():
		if not a.standoff_ring.has(ring):
			_bad(e, "$.standoff.radii[%d]" % ring, "no free standoff point is left on this ring")
		if not a.standoff_radii[ring] > a.approach_radius:
			_bad(e, "$.standoff.radii[%d]" % ring, "must be > approach_radius (standoff points never overlap the attack slots)")
	for d: EnemyDef in c.enemies:
		if d.standoff_m > 0.0 and not _has_radius(a, d.standoff_m):
			_bad(e, "$.standoff.radii", "no ring at %s m (needed by '%s')" % [snappedf(d.standoff_m, 0.01), String(d.id)])
	for i: int in a.rail_z.size():
		var p: String = "$.rail_lines[%d]" % i
		var z: float = a.rail_z[i]
		var half: float = a.rail_half_width[i]
		if not half > 0.0:
			_bad(e, p + ".half_width", "must be > 0")
		if z - half < a.min_z or z + half > a.max_z:
			_bad(e, p + ".z", "the lane leaves the bounds")
		if absf(a.core_z - z) <= half + a.core_radius:
			_bad(e, p, "the lane crosses the core")
		if absf(a.warden_z - z) <= half:
			_bad(e, p, "the lane crosses the Warden")
		for pad: int in a.turret_pads.size():
			if absf(a.turret_pads[pad].y - z) <= half:
				_bad(e, p, "the lane crosses turret pad %d" % pad)


static func _bad(e: PackedStringArray, path: String, problem: String) -> void:
	e.append("%s: %s: %s" % [ARENA, path, problem])


static func _has_radius(a: ArenaDef, radius: float) -> bool:
	for r: float in a.standoff_radii:
		if absf(r - radius) < 0.001:
			return true
	return false


static func _points(e: PackedStringArray, a: ArenaDef, field: Object, key: String, points: PackedVector2Array) -> void:
	var can_sample: bool = field != null and field.has_method("sample_cost")
	for i: int in points.size():
		var p: Vector2 = points[i]
		var path: String = "$.%s[%d]" % [key, i]
		if not ArenaBuilder.point_is_free(a, p.x, p.y, POINT_CLEAR_M):
			_bad(e, path, "(%s, %s) is outside the bounds or inside an obstacle" % [snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		elif can_sample:
			var cost_v: Variant = field.call("sample_cost", p.x, p.y)
			var cost: float = cost_v
			if not is_finite(cost):
				_bad(e, path, "(%s, %s) cannot reach the core in the flow field" % [snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
