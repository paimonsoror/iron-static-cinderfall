class_name WardenState
extends RefCounted

var x: float
var z: float
var weapon_index: int = 0
var magazine: int
var reload_ticks_left: int = 0
var fire_acc_milli: int = 0
var target_id: int = 0  ## 0 = none
var lock_ticks_left: int = 0
var aim_x: float  ## last aim point (view uses it for yaw)
var aim_z: float
var shots_fired: int = 0


func hash_into(h: StateHasher) -> void:
	h.put_float(x)
	h.put_float(z)
	h.put_int(weapon_index)
	h.put_int(magazine)
	h.put_int(reload_ticks_left)
	h.put_int(fire_acc_milli)
	h.put_int(target_id)
	h.put_int(lock_ticks_left)
	h.put_float(aim_x)
	h.put_float(aim_z)
	h.put_int(shots_fired)
