class_name FlowField
extends RefCounted
## Dijkstra flow field toward the approach circle (ARCH 6.6): 8-connected, no corner cutting, goal = every free
## cell whose center lies inside `approach_radius` of the core. `cost` is meters to the nearest goal cell (INF when
## blocked or unreachable); `dir_x/dir_z` is the unit step toward the cheapest neighbor (inside the goal it points
## at the core). Built once per SimWorld; never mutated by the sim.

## Obstacles are grown by this much for pathing so paths keep clear of props.
const INFLATE_M: float = 0.5
const SQRT2: float = 1.4142135623730951
## Neighbor order is part of the tie-break: E, W, S, N, SE, SW, NE, NW (S = +Z = screen down).
const NB_DX: PackedInt32Array = [1, -1, 0, 0, 1, -1, 1, -1]
const NB_DZ: PackedInt32Array = [0, 0, 1, -1, 1, 1, -1, -1]

var grid: ArenaGrid
var cost: PackedFloat32Array = PackedFloat32Array()  ## meters to the approach circle; INF when unreachable
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()

var _arena: ArenaDef


static func build(arena: ArenaDef) -> FlowField:
	var f: FlowField = FlowField.new()
	f._arena = arena
	var g: ArenaGrid = ArenaGrid.build(arena, INFLATE_M)
	f.grid = g
	var n: int = g.cols * g.rows
	f.cost.resize(n)
	f.cost.fill(INF)
	f.dir_x.resize(n)
	f.dir_z.resize(n)
	var dist: PackedFloat64Array = PackedFloat64Array()
	dist.resize(n)
	dist.fill(INF)
	var heap_k: PackedFloat64Array = PackedFloat64Array()
	var heap_v: PackedInt32Array = PackedInt32Array()
	var r2: float = arena.approach_radius * arena.approach_radius
	for c: int in n:
		if g.blocked[c] == 1:
			continue
		var p: Vector2 = g.cell_center(c)
		var dx: float = p.x - arena.core_x
		var dz: float = p.y - arena.core_z
		if dx * dx + dz * dz <= r2:
			dist[c] = 0.0
			_heap_push(heap_k, heap_v, 0.0, c)
	while not heap_v.is_empty():
		var key: float = heap_k[0]
		var cell: int = heap_v[0]
		_heap_pop(heap_k, heap_v)
		if key > dist[cell]:
			continue
		var cz: int = floori(float(cell) / float(g.cols))
		var cx: int = cell - cz * g.cols
		for d: int in 8:
			if not _can_step(g, cx, cz, d):
				continue
			var nc: int = (cz + NB_DZ[d]) * g.cols + cx + NB_DX[d]
			var nd: float = key + (1.0 if d < 4 else SQRT2) * g.cell_m
			if nd < dist[nc]:
				dist[nc] = nd
				_heap_push(heap_k, heap_v, nd, nc)
	for c: int in n:
		f.cost[c] = dist[c]
	f._build_dirs(dist)
	return f


## Blended direction at a position (unit length, or zero where nothing is reachable).
func sample_dir(x: float, z: float) -> Vector2:
	var s: Vector3 = sample_flow(x, z)
	return Vector2(s.x, s.y)


## Meters to the approach circle at a position (bilinear between cell centers; INF in blocked or unreachable cells).
func sample_cost(x: float, z: float) -> float:
	return sample_flow(x, z).z


## Direction and cost in one pass: Vector3(dir_x, dir_z, cost). The movement hot path uses this.
func sample_flow(x: float, z: float) -> Vector3:
	var g: ArenaGrid = grid
	var gx: float = (x - g.origin_x) / g.cell_m - 0.5
	var gz: float = (z - g.origin_z) / g.cell_m - 0.5
	var x0: int = floori(gx)
	var z0: int = floori(gz)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var xa: int = clampi(x0, 0, g.cols - 1)
	var xb: int = clampi(x0 + 1, 0, g.cols - 1)
	var za: int = clampi(z0, 0, g.rows - 1) * g.cols
	var zb: int = clampi(z0 + 1, 0, g.rows - 1) * g.cols
	var c00: int = za + xa
	var c10: int = za + xb
	var c01: int = zb + xa
	var c11: int = zb + xb
	var w00: float = (1.0 - fx) * (1.0 - fz)
	var w10: float = fx * (1.0 - fz)
	var w01: float = (1.0 - fx) * fz
	var w11: float = fx * fz
	var sx: float = dir_x[c00] * w00 + dir_x[c10] * w10 + dir_x[c01] * w01 + dir_x[c11] * w11
	var sz: float = dir_z[c00] * w00 + dir_z[c10] * w10 + dir_z[c01] * w01 + dir_z[c11] * w11
	var len2: float = sx * sx + sz * sz
	var nearest: int = -1
	if len2 < 0.00000001:
		nearest = g.cell_of(x, z)
		sx = dir_x[nearest]
		sz = dir_z[nearest]
	else:
		var inv: float = 1.0 / sqrt(len2)
		sx *= inv
		sz *= inv
	var k00: float = cost[c00]
	var k10: float = cost[c10]
	var k01: float = cost[c01]
	var k11: float = cost[c11]
	var k: float
	if is_inf(k00) or is_inf(k10) or is_inf(k01) or is_inf(k11):
		if nearest < 0:
			nearest = g.cell_of(x, z)
		k = cost[nearest]
	else:
		k = k00 * w00 + k10 * w10 + k01 * w01 + k11 * w11
	return Vector3(sx, sz, k)


## Number of distinct grid cells under the spawn-region segments that are blocked or cannot reach the goal.
## Must be 0 (the content validator checks it).
func unreachable_spawn_cells(arena: ArenaDef) -> int:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(grid.cols * grid.rows)
	var bad: int = 0
	for r: SpawnRegionDef in arena.spawn_regions:
		var length: float = Vector2(r.x1 - r.x0, r.z1 - r.z0).length()
		var steps: int = maxi(1, ceili(length / (grid.cell_m * 0.5)))
		for s: int in steps + 1:
			var t: float = float(s) / float(steps)
			var c: int = grid.cell_of(r.x0 + (r.x1 - r.x0) * t, r.z0 + (r.z1 - r.z0) * t)
			if seen[c] == 1:
				continue
			seen[c] = 1
			if is_inf(cost[c]):
				bad += 1
	return bad


## Debug dump for reports: one text row per grid row (top = most negative Z).
## '#' blocked, '?' unreachable, 'C' core cell, 'S' spawn-region cell, 'o' goal cell (inside the approach circle),
## otherwise an arrow for the step direction ('>' +X, 'v' +Z i.e. screen down, '<' -X, '^' -Z, '\' and '/' diagonals).
func to_ascii() -> String:
	var g: ArenaGrid = grid
	var marks: PackedByteArray = PackedByteArray()
	marks.resize(g.cols * g.rows)
	var core_cell: int = -1
	if _arena != null:
		core_cell = g.cell_of(_arena.core_x, _arena.core_z)
		for r: SpawnRegionDef in _arena.spawn_regions:
			var length: float = Vector2(r.x1 - r.x0, r.z1 - r.z0).length()
			var steps: int = maxi(1, ceili(length / (g.cell_m * 0.5)))
			for s: int in steps + 1:
				var t: float = float(s) / float(steps)
				marks[g.cell_of(r.x0 + (r.x1 - r.x0) * t, r.z0 + (r.z1 - r.z0) * t)] = 1
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		(
			"flow field %dx%d cell=%.2f origin=(%.1f, %.1f)  # blocked  ? unreachable  C core  S spawn  o goal"
			% [g.cols, g.rows, g.cell_m, g.origin_x, g.origin_z]
		)
	)
	for cz: int in g.rows:
		var row: String = ""
		for cx: int in g.cols:
			var c: int = cz * g.cols + cx
			row += _glyph(c, c == core_cell, marks[c] == 1)
		lines.append(row)
	return "\n".join(lines)


func _glyph(c: int, is_core: bool, is_spawn: bool) -> String:
	if grid.blocked[c] == 1:
		return "#"
	if is_core:
		return "C"
	if is_spawn:
		return "S"
	if is_inf(cost[c]):
		return "?"
	if cost[c] == 0.0:
		return "o"
	var dx: float = dir_x[c]
	var dz: float = dir_z[c]
	var ax: float = absf(dx)
	var az: float = absf(dz)
	if ax > 2.4 * az:
		return ">" if dx > 0.0 else "<"
	if az > 2.4 * ax:
		return "v" if dz > 0.0 else "^"
	return "\\" if dx * dz > 0.0 else "/"


func _build_dirs(dist: PackedFloat64Array) -> void:
	var g: ArenaGrid = grid
	for cell: int in g.cols * g.rows:
		if g.blocked[cell] == 1 or is_inf(dist[cell]):
			continue
		var cz: int = floori(float(cell) / float(g.cols))
		var cx: int = cell - cz * g.cols
		if dist[cell] == 0.0:
			var p: Vector2 = g.cell_center(cell)
			var to_core: Vector2 = Vector2(_arena.core_x - p.x, _arena.core_z - p.y)
			if to_core.length_squared() > 0.000001:
				to_core = to_core.normalized()
				dir_x[cell] = to_core.x
				dir_z[cell] = to_core.y
			continue
		var best: float = INF
		var best_d: int = -1
		for d: int in 8:
			if not _can_step(g, cx, cz, d):
				continue
			var nc: int = (cz + NB_DZ[d]) * g.cols + cx + NB_DX[d]
			var through: float = dist[nc] + (1.0 if d < 4 else SQRT2) * g.cell_m
			if through < best:
				best = through
				best_d = d
		if best_d >= 0:
			var step: Vector2 = Vector2(float(NB_DX[best_d]), float(NB_DZ[best_d])).normalized()
			dir_x[cell] = step.x
			dir_z[cell] = step.y


## A step from (cx, cz) in direction `d` stays in the grid, enters a free cell, and does not cut a blocked corner.
static func _can_step(g: ArenaGrid, cx: int, cz: int, d: int) -> bool:
	var nx: int = cx + NB_DX[d]
	var nz: int = cz + NB_DZ[d]
	if nx < 0 or nz < 0 or nx >= g.cols or nz >= g.rows:
		return false
	if g.blocked[nz * g.cols + nx] == 1:
		return false
	if d >= 4 and (g.blocked[cz * g.cols + nx] == 1 or g.blocked[nz * g.cols + cx] == 1):
		return false
	return true


static func _heap_less(k1: float, v1: int, k2: float, v2: int) -> bool:
	return k1 < k2 or (k1 == k2 and v1 < v2)


static func _heap_push(hk: PackedFloat64Array, hv: PackedInt32Array, key: float, val: int) -> void:
	hk.append(key)
	hv.append(val)
	var i: int = hk.size() - 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if not _heap_less(key, val, hk[p], hv[p]):
			break
		hk[i] = hk[p]
		hv[i] = hv[p]
		i = p
	hk[i] = key
	hv[i] = val


static func _heap_pop(hk: PackedFloat64Array, hv: PackedInt32Array) -> void:
	var last: int = hk.size() - 1
	var key: float = hk[last]
	var val: int = hv[last]
	hk.resize(last)
	hv.resize(last)
	if last == 0:
		return
	var i: int = 0
	while true:
		var l: int = 2 * i + 1
		if l >= last:
			break
		var r: int = l + 1
		var c: int = l
		if r < last and _heap_less(hk[r], hv[r], hk[l], hv[l]):
			c = r
		if not _heap_less(hk[c], hv[c], key, val):
			break
		hk[i] = hk[c]
		hv[i] = hv[c]
		i = c
	hk[i] = key
	hv[i] = val
