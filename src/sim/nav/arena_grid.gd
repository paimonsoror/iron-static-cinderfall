class_name ArenaGrid
extends RefCounted
## Blocked-cell grid over the arena. TODO(W1-A): build from ArenaDef obstacles.

@warning_ignore_start("unused_parameter")

var cols: int = 0
var rows: int = 0
var origin_x: float = 0.0
var origin_z: float = 0.0
var cell_m: float = 1.0
var blocked: PackedByteArray = PackedByteArray()


static func build(arena: ArenaDef, inflate: float) -> ArenaGrid:
	# TODO(W1-A)
	return ArenaGrid.new()


## Cell index of a position, clamped to the grid.
func cell_of(x: float, z: float) -> int:
	# TODO(W1-A)
	return -1


func cell_center(cell: int) -> Vector2:
	# TODO(W1-A)
	return Vector2.ZERO
