class_name WaveDef
extends RefCounted

var index: int
var peak_target: int
var groups: Array[SpawnGroupDef] = []


func total_count() -> int:
	var total: int = 0
	for g: SpawnGroupDef in groups:
		total += g.count
	return total
