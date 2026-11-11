class_name NavGeometry
extends RefCounted
## Obstacle geometry for the movement system: push a point out of props and test a straight line against them.
## Boxes rotate by `rot_deg` as ObstacleDef.contains does: world = (lx*cos - lz*sin, lx*sin + lz*cos).
## Every test grows the obstacle by a clearance (a circle by radius, a box by a square margin), matching
## `ObstacleDef.contains(x, z, inflate)`.

const EPS: float = 0.000001


## True when the point is inside any obstacle grown by `inflate`.
static func inside_any(obstacles: Array[ObstacleDef], px: float, pz: float, inflate: float) -> bool:
	for o: ObstacleDef in obstacles:
		if o.contains(px, pz, inflate):
			return true
	return false


## Moves the point out of every obstacle grown by `clearance` (at most three passes), along the cheapest axis for a
## box and radially for a circle, so a mover slides along a face. Unchanged when it is already outside.
## Returns a Vector2, i.e. single precision; the simulation uses `push_out_into`.
static func push_out(obstacles: Array[ObstacleDef], px: float, pz: float, clearance: float) -> Vector2:
	var out: PackedFloat64Array = PackedFloat64Array([px, pz])
	push_out_into(obstacles, px, pz, clearance, out)
	return Vector2(out[0], out[1])


## Double-precision form of `push_out`: writes the result into out[0] (x) and out[1] (z).
static func push_out_into(
	obstacles: Array[ObstacleDef], px: float, pz: float, clearance: float, out: PackedFloat64Array
) -> void:
	var x: float = px
	var z: float = pz
	for _pass: int in 3:
		var moved: bool = false
		for o: ObstacleDef in obstacles:
			if not o.contains(x, z, clearance):
				continue
			moved = true
			var dx: float = x - o.x
			var dz: float = z - o.z
			if o.shape == ObstacleDef.Shape.CIRCLE:
				var d: float = sqrt(dx * dx + dz * dz)
				var r: float = o.radius + clearance + EPS
				if d < 0.000000001:
					x = o.x + r
				else:
					x = o.x + dx / d * r
					z = o.z + dz / d * r
			else:
				var a: float = deg_to_rad(o.rot_deg)
				var c: float = cos(a)
				var s: float = sin(a)
				var lx: float = dx * c + dz * s
				var lz: float = -dx * s + dz * c
				var hx: float = o.size_x * 0.5 + clearance
				var hz: float = o.size_z * 0.5 + clearance
				if hx - absf(lx) < hz - absf(lz):
					lx = (hx + EPS) * (-1.0 if lx < 0.0 else 1.0)
				else:
					lz = (hz + EPS) * (-1.0 if lz < 0.0 else 1.0)
				x = o.x + lx * c - lz * s
				z = o.z + lx * s + lz * c
		if not moved:
			break
	out[0] = x
	out[1] = z


## True when the segment (x0, z0)-(x1, z1) touches no obstacle grown by `clearance`.
static func segment_clear(
	obstacles: Array[ObstacleDef], x0: float, z0: float, x1: float, z1: float, clearance: float
) -> bool:
	for o: ObstacleDef in obstacles:
		if o.shape == ObstacleDef.Shape.CIRCLE:
			var r: float = o.radius + clearance
			if _segment_point_d2(x0, z0, x1, z1, o.x, o.z) <= r * r:
				return false
			continue
		var reach: float = (o.size_x + o.size_z) * 0.5 + clearance * 1.5
		if _segment_point_d2(x0, z0, x1, z1, o.x, o.z) > reach * reach:
			continue
		var a: float = deg_to_rad(o.rot_deg)
		var c: float = cos(a)
		var s: float = sin(a)
		var ax: float = x0 - o.x
		var az: float = z0 - o.z
		var bx: float = x1 - o.x
		var bz: float = z1 - o.z
		var hx: float = o.size_x * 0.5 + clearance
		var hz: float = o.size_z * 0.5 + clearance
		if _segment_hits_box(ax * c + az * s, -ax * s + az * c, bx * c + bz * s, -bx * s + bz * c, hx, hz):
			return false
	return true


static func _segment_point_d2(x0: float, z0: float, x1: float, z1: float, px: float, pz: float) -> float:
	var vx: float = x1 - x0
	var vz: float = z1 - z0
	var len2: float = vx * vx + vz * vz
	var t: float = 0.0
	if len2 > 0.000000001:
		t = clampf(((px - x0) * vx + (pz - z0) * vz) / len2, 0.0, 1.0)
	var dx: float = x0 + vx * t - px
	var dz: float = z0 + vz * t - pz
	return dx * dx + dz * dz


## Slab test of a segment against the box [-hx, hx] x [-hz, hz] (local coordinates).
static func _segment_hits_box(
	lx0: float, lz0: float, lx1: float, lz1: float, hx: float, hz: float
) -> bool:
	var t_lo: float = 0.0
	var t_hi: float = 1.0
	var dx: float = lx1 - lx0
	if absf(dx) < 0.000000000001:
		if absf(lx0) > hx:
			return false
	else:
		var u: float = (-hx - lx0) / dx
		var v: float = (hx - lx0) / dx
		t_lo = maxf(t_lo, minf(u, v))
		t_hi = minf(t_hi, maxf(u, v))
		if t_lo > t_hi:
			return false
	var dz: float = lz1 - lz0
	if absf(dz) < 0.000000000001:
		if absf(lz0) > hz:
			return false
	else:
		var u2: float = (-hz - lz0) / dz
		var v2: float = (hz - lz0) / dz
		t_lo = maxf(t_lo, minf(u2, v2))
		t_hi = minf(t_hi, maxf(u2, v2))
		if t_lo > t_hi:
			return false
	return true
