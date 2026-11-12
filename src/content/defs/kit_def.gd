class_name KitDef
extends RefCounted
## A starting loadout (data/unlocks.json `kits[]`, CONTENT 11). SimConfig.kit_index is the position in the file.

var id: StringName
var index: int
var name_key: String
var cost: int = 0
var ops: Array[OpDef] = []
