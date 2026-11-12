class_name LookActorsGrit
extends RefCounted
## Weathering baked into the vertex colours of an actor mesh (W3-D), at build time and once per mesh: dirt blotches that
## darken the plates, grime that climbs from the ground, warm oil stains, random paint chips (the edge-wear mask in the
## vertex alpha, which the enemy shader turns into bare dark metal on the plates and bright metal on the frame), and the
## red light spill of the optic on the plates around it. No extra draw call and no per-frame cost. Deterministic: a hash
## noise of the vertex position and a seed, nothing random.


## Smooth value noise in 0..1.
static func vnoise(p: Vector3, seed_i: int) -> float:
	var ix: int = floori(p.x)
	var iy: int = floori(p.y)
	var iz: int = floori(p.z)
	var f: Vector3 = Vector3(p.x - float(ix), p.y - float(iy), p.z - float(iz))
	var u: Vector3 = Vector3(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y), f.z * f.z * (3.0 - 2.0 * f.z))
	var c000: float = _lattice(ix, iy, iz, seed_i)
	var c100: float = _lattice(ix + 1, iy, iz, seed_i)
	var c010: float = _lattice(ix, iy + 1, iz, seed_i)
	var c110: float = _lattice(ix + 1, iy + 1, iz, seed_i)
	var c001: float = _lattice(ix, iy, iz + 1, seed_i)
	var c101: float = _lattice(ix + 1, iy, iz + 1, seed_i)
	var c011: float = _lattice(ix, iy + 1, iz + 1, seed_i)
	var c111: float = _lattice(ix + 1, iy + 1, iz + 1, seed_i)
	var x00: float = lerpf(c000, c100, u.x)
	var x10: float = lerpf(c010, c110, u.x)
	var x01: float = lerpf(c001, c101, u.x)
	var x11: float = lerpf(c011, c111, u.x)
	return lerpf(lerpf(x00, x10, u.y), lerpf(x01, x11, u.y), u.z)


## Dirt, ground grime, stains and chips on every surface except those in `skip` (the emissive ones). `height` is the
## height of the actor in meters (grime fades out over its lower 45 percent). `plate_dirt` and `frame_dirt` are 0..1.
static func bake(
	mb: MeshBuilder, seed_i: int, height: float, plate_dirt: float, frame_dirt: float, skip: Array[StringName] = []
) -> void:
	mb.use_colors = true
	var noise_at: Dictionary = {}  # Vector3i (0.5 mm) -> Vector2(dirt, chip): a position is shared by 3 to 6 vertices
	for mat_id: StringName in mb.surface_ids():
		if skip.has(mat_id):
			continue
		var plate: bool = mat_id == &"ceramic"
		var amount: float = plate_dirt if plate else frame_dirt
		var s: MeshBuilder.Surf = mb.surface_of(mat_id)
		for i: int in s.verts.size():
			var p: Vector3 = s.verts[i]
			var key: Vector3i = Vector3i(roundi(p.x * 2000.0), roundi(p.y * 2000.0), roundi(p.z * 2000.0))
			var nz: Vector2
			if noise_at.has(key):
				nz = noise_at[key]
			else:
				var n1: float = vnoise(p * 6.5, seed_i)
				var n2: float = _lattice(floori(p.x * 17.0), floori(p.y * 17.0), floori(p.z * 17.0), seed_i + 1)
				nz = Vector2(smoothstep(0.4, 0.8, n1 * 0.8 + n2 * 0.2), n2)
				noise_at[key] = nz
			var low: float = 1.0 - smoothstep(0.0, height * 0.45, p.y)
			var k: float = 1.0 - amount * (0.5 * nz.x + 0.32 * low)
			var stain: float = nz.x * amount if plate else 0.0
			var c: Color = s.cols[i]
			var chip: float = smoothstep(0.76, 0.9, nz.y) * (0.5 if plate else 0.4)  # soft stains: a vertex chip spreads over its triangles
			s.cols[i] = Color(c.r * k, c.g * k * (1.0 - 0.1 * stain), c.b * k * (1.0 - 0.28 * stain), maxf(c.a, chip))


## Red light spill of the optic on the plates around it: tints the vertices within `radius` of `centre` toward red (green
## and blue down), so the plates read as lit by the optic on every tier (the colour is in the mesh).
static func spill(mb: MeshBuilder, centre: Vector3, radius: float, strength: float, skip: Array[StringName] = []) -> void:
	mb.use_colors = true
	for mat_id: StringName in mb.surface_ids():
		if skip.has(mat_id):
			continue
		var s: MeshBuilder.Surf = mb.surface_of(mat_id)
		for i: int in s.verts.size():
			var near: float = 1.0 - smoothstep(0.0, radius, s.verts[i].distance_to(centre))
			if near <= 0.0:
				continue
			var c: Color = s.cols[i]
			var k: float = strength * near
			s.cols[i] = Color(c.r, c.g * (1.0 - 0.62 * k), c.b * (1.0 - 0.7 * k), c.a)


static func _lattice(x: int, y: int, z: int, seed_i: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed_i * 2654435761)
	n = (n ^ (n >> 15)) & 0x7FFFFFFF
	n = (n * 1103515245 + 12345) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) & 0x7FFFFFFF
	return float(n & 0xFFFF) / 65535.0
