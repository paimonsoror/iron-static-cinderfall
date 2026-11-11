class_name AbilityState
extends RefCounted
## Indexed by Ids.AB_*.

var cooldown_left: PackedInt32Array = PackedInt32Array([0, 0, 0])
var active_left: PackedInt32Array = PackedInt32Array([0, 0, 0])


func is_active(ability_index: int) -> bool:
	return active_left[ability_index] > 0


## cooldown_left == 0 and not active.
func is_ready(ability_index: int) -> bool:
	return cooldown_left[ability_index] == 0 and active_left[ability_index] == 0


func hash_into(h: StateHasher) -> void:
	h.put_ints(cooldown_left)
	h.put_ints(active_left)
