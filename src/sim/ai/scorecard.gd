class_name Scorecard
extends RefCounted
## The predictability scorecard (VARIETY_SPEC 14.2): rows S1 to S18 computed from finished runs.
# TODO(V4-T)

enum Verdict { PASS, WARN, FAIL }


## `runs`: one Dictionary per finished run (policy, seed, result, waves, core fraction, combat ticks, signature, ...).
## Returns one Dictionary per scorecard row: { "id": "S1", "value": float, "verdict": Verdict }.
static func evaluate(_runs: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	return rows
