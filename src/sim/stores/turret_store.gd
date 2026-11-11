class_name TurretStore
extends RefCounted
## Exactly 2 pads. Index = pad index.

var active: PackedByteArray = PackedByteArray()
var x: PackedFloat64Array = PackedFloat64Array()
var z: PackedFloat64Array = PackedFloat64Array()
var fire_acc_milli: PackedInt32Array = PackedInt32Array()
var target_id: PackedInt32Array = PackedInt32Array()
var lock_ticks_left: PackedInt32Array = PackedInt32Array()
var aim_x: PackedFloat64Array = PackedFloat64Array()
var aim_z: PackedFloat64Array = PackedFloat64Array()


func _init(pad_count: int = 2) -> void:
	active.resize(pad_count)
	x.resize(pad_count)
	z.resize(pad_count)
	fire_acc_milli.resize(pad_count)
	target_id.resize(pad_count)
	lock_ticks_left.resize(pad_count)
	aim_x.resize(pad_count)
	aim_z.resize(pad_count)


func active_count() -> int:
	var n: int = 0
	for a: int in active:
		n += a
	return n


func hash_into(h: StateHasher) -> void:
	h.put_bytes(active)
	h.put_floats(x)
	h.put_floats(z)
	h.put_ints(fire_acc_milli)
	h.put_ints(target_id)
	h.put_ints(lock_ticks_left)
	h.put_floats(aim_x)
	h.put_floats(aim_z)
