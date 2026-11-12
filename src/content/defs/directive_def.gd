class_name DirectiveDef
extends RefCounted
## A directive (data/directives.json, CONTENT 3). The index is the position in the file, forever.

enum Category { WEAPON, TURRET, CORE, ABILITY, ECONOMY, CORRUPTED }
enum Rarity { COMMON, RARE, PROTOTYPE, CORRUPTED }

const CATEGORY_NAMES: PackedStringArray = ["weapon", "turret", "core", "ability", "economy", "corrupted"]
const RARITY_NAMES: PackedStringArray = ["common", "rare", "prototype", "corrupted"]
## Keys `requires{}` may carry: turrets (deployed, at least), free_pad (1), weapons (carried, at least),
## weapon_kind (a WeaponDef.Kind that must be carried; the JSON holds the kind name).
const REQUIRE_KEYS: PackedStringArray = ["turrets", "free_pad", "weapons", "weapon_kind"]

var id: StringName
var index: int
var name_key: String  ## "directive.<id>.name"
var desc_key: String  ## "directive.<id>.desc"
var category: int = Category.WEAPON
var rarity: int = Rarity.COMMON
var max_stacks: int = 1  ## JSON `max`
var tags: Array[StringName] = []
var requires: Dictionary[StringName, float] = {}
var ops: Array[OpDef] = []
var hook: StringName = &""  ## the sim hook that implements it, or empty for a pure-data directive
var pool: StringName = &"base"  ## &"base" or the unlock id that adds it
