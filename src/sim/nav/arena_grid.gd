class_name ArenaGrid
extends RefCounted
## Blocked-cell grid over the arena (ARCH 6.6). The grid covers the playable bounds plus `margin_cells`
## on every side (spawn regions lie in the margin). Cell index = row * cols + col; a cell is blocked when its
## center lies inside an obstacle grown by `inflate` meters. X = screen right, Z = screen down.

const MIN_CELL_M: float = 0.05
const MAX_CELLS_PER_AXIS: int = 1024

var cols: int = 0
var rows: int = 0
var origin_x: float = 0.0  ## world X of the grid's left edge
var origin_z: float = 0.0  ## world Z of the grid's top edge
var cell_m: float = 1.0
var blocked: PackedByteArray = PackedByteArray()


static func build(arena: ArenaDef, inflate: float) -> ArenaGrid:
	var g: ArenaGrid = ArenaGrid.new()
	g.cell_m = maxf(arena.cell_m, MIN_CELL_M)  ## a bad data file must not make the grid unbounded
	g.origin_x = arena.min_x - float(arena.margin_cells) * g.cell_m
	g.origin_z = arena.min_z - float(arena.margin_cells) * g.cell_m
	g.cols = clampi(ceili((arena.max_x - arena.min_x) / g.cell_m - 0.000001) + 2 * arena.margin_cells, 1, MAX_CELLS_PER_AXIS)
	g.rows = clampi(ceili((arena.max_z - arena.min_z) / g.cell_m - 0.000001) + 2 * arena.margin_cells, 1, MAX_CELLS_PER_AXIS)
	g.blocked.resize(g.cols * g.rows)
	for cell: int in g.cols * g.rows:
		var c: Vector2 = g.cell_center(cell)
		for o: ObstacleDef in arena.obstacles:
			if o.contains(c.x, c.y, inflate):
				g.blocked[cell] = 1
				break
	return g


## Cell index of a position, clamped to the grid.
func cell_of(x: float, z: float) -> int:
	var cx: int = clampi(floori((x - origin_x) / cell_m), 0, cols - 1)
	var cz: int = clampi(floori((z - origin_z) / cell_m), 0, rows - 1)
	return cz * cols + cx


## World (x, z) of a cell center. `cell` must be a valid index.
func cell_center(cell: int) -> Vector2:
	var cz: int = floori(float(cell) / float(cols))
	var cx: int = cell - cz * cols
	return Vector2(origin_x + (float(cx) + 0.5) * cell_m, origin_z + (float(cz) + 0.5) * cell_m)


## World X of the right edge of the grid.
func max_x() -> float:
	return origin_x + float(cols) * cell_m


## World Z of the bottom edge of the grid.
func max_z() -> float:
	return origin_z + float(rows) * cell_m
