class_name AudioBlastMerge
extends RefCounted
## "A big blast sample replaces 4 or more simultaneous small ones" (VARIETY_SPEC 10.5). Pure: no engine calls.
## The router `add`s every small blast of a frame and `take`s once per frame; four or more become one big blast,
## fewer stay small blasts (at most MAX_SMALL, the per-frame start cap of AudioVoiceGate).

const BIG_AT: int = 4
const MAX_SMALL: int = 3
const SMALL: StringName = &"blast_small"
const BIG: StringName = &"blast_big"

var pending: int = 0


func add() -> void:
	pending += 1


## The sounds to start for the blasts collected since the last call, then forget them.
func take() -> Array[StringName]:
	var sounds: Array[StringName] = []
	if pending >= BIG_AT:
		sounds.append(BIG)
	else:
		for i: int in mini(pending, MAX_SMALL):
			sounds.append(SMALL)
	pending = 0
	return sounds


func clear() -> void:
	pending = 0
