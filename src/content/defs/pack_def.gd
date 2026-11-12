class_name PackDef
extends RefCounted
## A threat pack: the composition template of a wave (data/run.json `packs[]`, CONTENT 1.3). Groups are parallel
## arrays; WaveBuilder (V2-A) turns them into SpawnGroupDefs.

var id: StringName
var index: int
var name_key: String
var min_act: int = 1
var budget_mult: float = 1.0
var extra_elites: int = 0
var group_enemy: PackedInt32Array = PackedInt32Array()  ## Ids.ENEMIES index
var group_share: PackedFloat32Array = PackedFloat32Array()  ## fraction of the budget; the shares sum to 1
var group_region: Array[StringName] = []  ## a spawn region id of the arena, or &"breach"
var group_start: PackedFloat32Array = PackedFloat32Array()  ## fraction of the wave window
var group_tempo: PackedFloat32Array = PackedFloat32Array()  ## multiplies the even spacing


func group_count() -> int:
	return group_enemy.size()
