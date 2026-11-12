class_name AffixDef
extends RefCounted
## An elite affix (data/enemies.json `affixes[]`, CONTENT 4.3). The index is the bit of the affix mask.

var id: StringName
var index: int
var name_key: String
var ops: Array[OpDef] = []
