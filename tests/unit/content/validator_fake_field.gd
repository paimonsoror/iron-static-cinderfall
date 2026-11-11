class_name ValidatorFakeField
extends RefCounted
## Test double for FlowField (cost array plus unreachable_spawn_cells) so the validator's reachability rule can be
## tested before the real Dijkstra field exists.

var cost: PackedFloat32Array = PackedFloat32Array()
var unreachable: int = 0
var asked: int = 0


static func with_cells(cell_count: int, unreachable_cells: int) -> ValidatorFakeField:
	var f: ValidatorFakeField = ValidatorFakeField.new()
	f.cost.resize(cell_count)
	f.unreachable = unreachable_cells
	return f


func unreachable_spawn_cells(_arena: ArenaDef) -> int:
	asked += 1
	return unreachable
