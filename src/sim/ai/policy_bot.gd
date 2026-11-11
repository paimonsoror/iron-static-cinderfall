class_name PolicyBot
extends RefCounted
## Scripted player for headless runs. TODO(W2-D).

@warning_ignore_start("unused_parameter")

enum Policy { NONE, GREEDY }

var policy: int = Policy.NONE


func _init(policy_value: int) -> void:
	policy = policy_value


## Submits commands. Deterministic.
func act(world: SimWorld) -> void:
	# TODO(W2-D)
	pass
