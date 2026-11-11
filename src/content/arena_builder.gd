class_name ArenaBuilder
extends RefCounted
## Maps arena.json to ArenaDef and computes the 64 attack-slot positions (ARCH 5.2).
## Slot angle 0 points along +X; positive angles turn toward -Z (screen up).
## Slot k of a ring with n slots sits at arc_start + (k + 0.5) * (arc_end - arc_start) / n.


static func build(r: JsonRead, d: Dictionary) -> ArenaDef:
	var a: ArenaDef = ArenaDef.new()
	a.id = StringName(r.text(d, "id", "$"))
	var bounds: Dictionary = r.dict(d, "bounds", "$")
	a.min_x = r.num(bounds, "min_x", "$.bounds")
	a.max_x = r.num(bounds, "max_x", "$.bounds")
	a.min_z = r.num(bounds, "min_z", "$.bounds")
	a.max_z = r.num(bounds, "max_z", "$.bounds")
	var grid: Dictionary = r.dict(d, "grid", "$")
	a.cell_m = r.num(grid, "cell_m", "$.grid")
	a.margin_cells = r.integer(grid, "margin_cells", "$.grid")
	var core: Dictionary = r.dict(d, "core", "$")
	a.core_x = r.num(core, "x", "$.core")
	a.core_z = r.num(core, "z", "$.core")
	a.core_radius = r.num(core, "radius", "$.core")
	var warden: Dictionary = r.dict(d, "warden", "$")
	a.warden_x = r.num(warden, "x", "$.warden")
	a.warden_z = r.num(warden, "z", "$.warden")
	var pads: Array = r.list(d, "turret_pads", "$")
	for i: int in pads.size():
		if typeof(pads[i]) != TYPE_DICTIONARY:
			r.fail("$.turret_pads[%d]" % i, "not an object")
			continue
		var p: Dictionary = pads[i]
		var pp: String = "$.turret_pads[%d]" % i
		a.turret_pads.append(Vector2(r.num(p, "x", pp), r.num(p, "z", pp)))
	a.approach_radius = r.num(d, "approach_radius", "$")
	_slots(a, r, r.dict(d, "slots", "$"))
	_regions(a, r, r.dict(d, "spawn_regions", "$"))
	_obstacles(a, r, r.list(d, "obstacles", "$"))
	var cam: Dictionary = r.dict(d, "camera", "$")
	a.pitch_down_deg = r.num(cam, "pitch_down_deg", "$.camera")
	a.yaw_deg = r.num(cam, "yaw_deg", "$.camera")
	a.frame_margin_m = r.num(cam, "frame_margin_m", "$.camera")
	a.decor_yaw_deg = r.num(cam, "decor_yaw_deg", "$.camera")
	return a


static func _slots(a: ArenaDef, r: JsonRead, s: Dictionary) -> void:
	var arc_start: float = r.num(s, "arc_start_deg", "$.slots")
	var arc_end: float = r.num(s, "arc_end_deg", "$.slots")
	var radii: Array = r.list(s, "ring_radii", "$.slots")
	var counts: Array = r.list(s, "ring_counts", "$.slots")
	if radii.size() != counts.size():
		r.fail("$.slots", "ring_radii and ring_counts differ in length")
		return
	for ring: int in radii.size():
		var radius: float = r.as_num(radii[ring], "$.slots.ring_radii[%d]" % ring)
		var n: int = roundi(r.as_num(counts[ring], "$.slots.ring_counts[%d]" % ring))
		for k: int in n:
			var deg: float = arc_start + (float(k) + 0.5) * (arc_end - arc_start) / float(n)
			var rad: float = deg_to_rad(deg)
			a.slot_positions.append(Vector2(a.core_x + radius * cos(rad), a.core_z - radius * sin(rad)))
			a.slot_ring.append(ring)


static func _regions(a: ArenaDef, r: JsonRead, regions: Dictionary) -> void:
	for k: Variant in regions.keys():
		var key: String = str(k)
		var path: String = "$.spawn_regions." + key
		var rd: Dictionary = r.dict(regions, key, "$.spawn_regions")
		var sr: SpawnRegionDef = SpawnRegionDef.new()
		sr.id = StringName(key)
		sr.x0 = r.num(rd, "x0", path)
		sr.z0 = r.num(rd, "z0", path)
		sr.x1 = r.num(rd, "x1", path)
		sr.z1 = r.num(rd, "z1", path)
		a.spawn_regions.append(sr)


static func _obstacles(a: ArenaDef, r: JsonRead, rows: Array) -> void:
	for i: int in rows.size():
		var path: String = "$.obstacles[%d]" % i
		if typeof(rows[i]) != TYPE_DICTIONARY:
			r.fail(path, "not an object")
			continue
		var od: Dictionary = rows[i]
		var o: ObstacleDef = ObstacleDef.new()
		o.id = StringName(r.text(od, "id", path))
		var shape: String = r.text(od, "shape", path)
		o.x = r.num(od, "x", path)
		o.z = r.num(od, "z", path)
		match shape:
			"circle":
				o.shape = ObstacleDef.Shape.CIRCLE
				o.radius = r.num(od, "radius", path)
			"box":
				o.shape = ObstacleDef.Shape.BOX
				o.size_x = r.num(od, "size_x", path)
				o.size_z = r.num(od, "size_z", path)
				o.rot_deg = r.num(od, "rot_deg", path)
			_:
				r.fail(path + ".shape", "unknown shape '%s'" % shape)
		o.visual = StringName(r.text(od, "visual", path))
		a.obstacles.append(o)
