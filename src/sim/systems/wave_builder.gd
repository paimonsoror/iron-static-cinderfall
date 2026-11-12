class_name WaveBuilder
extends RefCounted
## Turns a pack and a budget into spawn groups (VARIETY_SPEC 5.3, CONTENT 1.3): count = max(1, roundi(budget * share
## / cost * (0.9 + 0.2 * u))) with u from `stream`, interval = clamp(window * (1 - start) * tempo / count, 0.08, 4.0) s,
## a type below its min_act becomes skitter at the same budget. Used by RunPlanSystem only.
# TODO(V2-A)


## The groups of one route option. `stream` is `plan.wave:<w>:<o>`; the stub returns no groups and draws nothing.
static func build(
	_content: ContentSet, _slot: WaveSlotDef, _pack_index: int, _budget_mult: float, _stream: RandomNumberGenerator
) -> Array[SpawnGroupDef]:
	var out: Array[SpawnGroupDef] = []
	return out
