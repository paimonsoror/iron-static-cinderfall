class_name RewardDef
extends RefCounted
## A route reward (data/run.json `route_rewards[]`, CONTENT 1.2).

var id: StringName
var index: int
var name_key: String
var weight_standard: float = 0.0
var weight_hot: float = 0.0
var ops: Array[OpDef] = []
