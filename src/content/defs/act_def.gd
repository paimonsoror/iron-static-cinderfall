class_name ActDef
extends RefCounted
## One act of the run (data/run.json `acts[]`, CONTENT 1.1). The plating tier is visible to the player.

var id: StringName
var index: int  ## 0-based position; the act number is index + 1
var name_key: String
var hp_mult: float = 1.0
var core_dmg_mult: float = 1.0
var rarity_weights: PackedFloat32Array = PackedFloat32Array()  ## common, rare, prototype
var corrupted_chance: float = 0.0
var elites_min: int = 0
var elites_max: int = 0
var affixes_min: int = 1
var affixes_max: int = 1
