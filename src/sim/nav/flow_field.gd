class_name FlowField
extends RefCounted
## Dijkstra flow field toward the approach circle. TODO(W1-A). The stub has no cells.

@warning_ignore_start("unused_parameter")

var grid: ArenaGrid
var cost: PackedFloat32Array = PackedFloat32Array()  ## meters to the approach circle; INF when unreachable
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()


static func build(arena: ArenaDef) -> FlowField:
	# TODO(W1-A)
	var f: FlowField = FlowField.new()
	f.grid = ArenaGrid.new()
	return f


func sample_dir(x: float, z: float) -> Vector2:
	# TODO(W1-A)
	return Vector2.ZERO


func sample_cost(x: float, z: float) -> float:
	# TODO(W1-A)
	return INF


## Must be 0 (the validator checks it). The stub reports 0 because it has no cells.
func unreachable_spawn_cells(arena: ArenaDef) -> int:
	# TODO(W1-A)
	return 0
