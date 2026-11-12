class_name TurretTypeDef
extends RefCounted
## A turret type (data/weapons.json `turrets{}`, CONTENT 8; stretch content).

var id: StringName
var index: int
var name_key: String
var damage: float
var sps_milli: int
var range_m: float
var min_range_m: float = 0.0
var params: Dictionary[StringName, float] = {}
