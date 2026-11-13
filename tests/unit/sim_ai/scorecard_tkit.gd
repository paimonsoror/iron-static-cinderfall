class_name ScorecardTKit
extends RefCounted
## Synthetic finished runs for the scorecard suites of V4-T: ScorecardRecord dictionaries written by hand, so every row can
## be pushed over its boundary without playing a run.


## One record. `extra` overrides any key.
static func run(policy: String, won: bool, run_seed: int = 1, extra: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = {
		"policy": policy, "variant": "", "pool": "base", "seed": run_seed, "result": "victory" if won else "defeat",
		"clean": true, "ticks": 60000, "combat_s": 900.0, "waves": 15 if won else 4, "wave_total": 15,
		"death_wave": 0 if won else 5, "death_act": 0 if won else 1, "boss_death": false, "core": 0.5,
		"act_end_core": [0.6, 0.5, 0.4], "core_loss": [0.1, 0.1, 0.1, 0.1, 0.1], "peak_bodied": [], "peak_minis": [],
		"max_blasts": 0, "signature": "pistol+bullet+blast", "primary": "pistol", "held": [], "offered": [],
		"weapons": ["pistol"], "data": 100,
	}
	for key: String in extra:
		rec[key] = extra[key]
	return rec


## `wins` winning and `losses` losing runs of `policy` on seeds 1, 2, 3, ... (wins first); `extra` goes into every one.
static func batch(policy: String, wins: int, losses: int, extra: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in wins + losses:
		out.append(run(policy, k < wins, k + 1, extra))
	return out


static func row(rows: Array[Dictionary], id: String) -> Dictionary:
	for r: Dictionary in rows:
		if r["id"] == id:
			return r
	return {}


static func verdict(rows: Array[Dictionary], id: String) -> int:
	var r: Dictionary = row(rows, id)
	var v: int = r["verdict"] if r.has("verdict") else -1
	return v


## The context of a three-act, 15-wave content with the peak table of CONTENT 1.1 (waves 1 to 5 only, to keep it short).
static func context() -> Dictionary:
	return {
		"acts": 3, "act1_waves": 5, "wave_bodied": [10, 16, 24, 30, 26], "wave_minis": [0, 8, 12, 16, 16],
		"cap_bodied": 50, "cap_minis": 40, "cap_blasts": 8, "roster": ["pistol", "smg", "arc_projector"],
	}


## Typed readers for the untyped rows and jobs (a Variant cannot go straight into String(), float() or int()).
static func text(d: Dictionary, key: String) -> String:
	var v: Variant = d[key]
	var s: String = v
	return s


static func number(d: Dictionary, key: String) -> float:
	var v: Variant = d[key]
	var n: float = v
	return n


static func whole(d: Dictionary, key: String) -> int:
	var v: Variant = d[key]
	var n: int = v
	return n
