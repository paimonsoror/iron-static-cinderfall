class_name BossDef
extends RefCounted
## A boss (data/enemies.json `bosses{}`, CONTENT 5). The stats of its body are the EnemyDef at `enemy_index`; `hp`
## here is final (the act tier does not multiply it).

var id: StringName
var enemy_index: int = -1
var name_key: String  ## "boss.<id>.name"
var banner_key: String  ## "boss.<id>.banner"
var pool_act: int = 1  ## the act whose boss pool it belongs to
var hp: float
var behaviour: Dictionary[StringName, float] = {}
var escort_enemy: PackedInt32Array = PackedInt32Array()
var escort_share: PackedFloat32Array = PackedFloat32Array()
var escort_pack: StringName = &""  ## a pack id instead of the two arrays, or empty


func beh(key: StringName, fallback: float = 0.0) -> float:
	return behaviour.get(key, fallback)
