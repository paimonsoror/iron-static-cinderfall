class_name UnlockDef
extends RefCounted
## An Archive unlock (data/unlocks.json `unlocks[]`, CONTENT 12).

enum Branch { ARMORY, DIRECTIVES, KITS, FIELD }

const BRANCH_NAMES: PackedStringArray = ["armory", "directives", "kits", "field"]

var id: StringName
var index: int
var name_key: String  ## "archive.<id>.name"
var branch: int = Branch.ARMORY
var tier: int = 1
var cost: int = 0
var grants: Array[StringName] = []  ## weapon, directive or kit ids, or a field option name
