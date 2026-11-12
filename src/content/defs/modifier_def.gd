class_name ModifierDef
extends RefCounted
## A wave modifier (data/run.json `modifiers[]`, CONTENT 1.4).

enum List { MILD, HOT }

const LIST_NAMES: PackedStringArray = ["mild", "hot"]

var id: StringName
var index: int
var name_key: String
var list: int = List.MILD
var ops: Array[OpDef] = []
