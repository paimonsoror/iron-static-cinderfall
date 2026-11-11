class_name SpatialHash
extends RefCounted
## Uniform grid hash of enemy positions: fixed 1 m cells over +-20 m (positions beyond clamp into the edge cells,
## which stays correct because every hit is distance-tested), cell contents as linked lists through store indices.
## `rebuild` records cell membership; `query` reads the store's live positions, so rebuild once per tick before
## querying (membership is then at most a tick's movement stale).

const CELL_M: float = 1.0
const ORIGIN: float = -20.0
const COLS: int = 40
const ROWS: int = 40

var _store: EnemyStore
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()


func rebuild(store: EnemyStore) -> void:
	_store = store
	if _head.is_empty():
		_head.resize(COLS * ROWS)
	_head.fill(-1)
	if _next.size() < store.capacity:
		_next.resize(store.capacity)
	var alive: PackedByteArray = store.alive
	var xs: PackedFloat64Array = store.x
	var zs: PackedFloat64Array = store.z
	for i: int in store.high_water:
		if alive[i] == 0:
			continue
		var cx: int = int((xs[i] - ORIGIN) / CELL_M)
		var cz: int = int((zs[i] - ORIGIN) / CELL_M)
		if cx < 0:
			cx = 0
		elif cx >= COLS:
			cx = COLS - 1
		if cz < 0:
			cz = 0
		elif cz >= ROWS:
			cz = ROWS - 1
		var c: int = cz * COLS + cx
		_next[i] = _head[c]
		_head[c] = i


## Movement variant of `rebuild`: skips enemies in state `skip_state` (attackers do not take part in separation)
## and keeps enemies with a radius above `heavy_radius` out of the cells, listing their store indices in `heavy`
## instead (so a boss does not widen every neighbor search). `radii` is indexed by enemy type. Returns the largest
## radius among the enemies that went into the cells (0 when none did).
func rebuild_movers(store: EnemyStore, skip_state: int, radii: PackedFloat64Array, heavy_radius: float, heavy: PackedInt32Array) -> float:
	_store = store
	if _head.is_empty():
		_head.resize(COLS * ROWS)
	_head.fill(-1)
	heavy.clear()
	if _next.size() < store.capacity:
		_next.resize(store.capacity)
	var alive: PackedByteArray = store.alive
	var states: PackedByteArray = store.state
	var types: PackedByteArray = store.type
	var xs: PackedFloat64Array = store.x
	var zs: PackedFloat64Array = store.z
	var r_max: float = 0.0
	for i: int in store.high_water:
		if alive[i] == 0 or states[i] == skip_state:
			continue
		var r: float = radii[types[i]]
		if r > heavy_radius:
			heavy.append(i)
			continue
		if r > r_max:
			r_max = r
		var cx: int = int((xs[i] - ORIGIN) / CELL_M)
		var cz: int = int((zs[i] - ORIGIN) / CELL_M)
		if cx < 0:
			cx = 0
		elif cx >= COLS:
			cx = COLS - 1
		if cz < 0:
			cz = 0
		elif cz >= ROWS:
			cz = ROWS - 1
		var c: int = cz * COLS + cx
		_next[i] = _head[c]
		_head[c] = i
	return r_max


## Fills `out` with the store indices of enemies whose center is within `radius` of (x, z), sorted by enemy id.
## `out` is cleared first. Returns the count.
func query(x: float, z: float, radius: float, out: PackedInt32Array) -> int:
	var n: int = gather(x, z, radius, out)
	var ids: PackedInt32Array = _store.id if _store != null else PackedInt32Array()
	for a: int in range(1, n):
		var cur: int = out[a]
		var cur_id: int = ids[cur]
		var b: int = a - 1
		while b >= 0 and ids[out[b]] > cur_id:
			out[b + 1] = out[b]
			b -= 1
		out[b + 1] = cur
	return n


## Same hits as `query`, in cell order (deterministic, not sorted by id). Cheaper; the movement system uses it.
func gather(x: float, z: float, radius: float, out: PackedInt32Array) -> int:
	out.clear()
	if _store == null:
		return 0
	var r2: float = radius * radius
	var cx0: int = clampi(floori((x - radius - ORIGIN) / CELL_M), 0, COLS - 1)
	var cx1: int = clampi(floori((x + radius - ORIGIN) / CELL_M), 0, COLS - 1)
	var cz0: int = clampi(floori((z - radius - ORIGIN) / CELL_M), 0, ROWS - 1)
	var cz1: int = clampi(floori((z + radius - ORIGIN) / CELL_M), 0, ROWS - 1)
	var xs: PackedFloat64Array = _store.x
	var zs: PackedFloat64Array = _store.z
	var cz: int = cz0
	while cz <= cz1:
		var cx: int = cx0
		while cx <= cx1:
			var p: int = _head[cz * COLS + cx]
			while p >= 0:
				var dx: float = xs[p] - x
				var dz: float = zs[p] - z
				if dx * dx + dz * dz <= r2:
					out.append(p)
				p = _next[p]
			cx += 1
		cz += 1
	return out.size()
