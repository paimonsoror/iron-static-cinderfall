class_name ScorecardRecord
extends RefCounted
## One finished run as the scorecard sees it: a plain Dictionary that survives a trip through JSON (the card can run in
## several processes and collect their lines). Keys, all optional when read (a missing key reads as 0, "" or empty):
##   policy (name), variant ("" main run, "standard" or "hot" forced route, "other_pool" the S15 twin), pool ("base"|"full"),
##   seed, result ("victory"|"defeat"|"unfinished"), clean (false when it stalled or broke an invariant), ticks,
##   combat_s, waves (completed), wave_total, death_wave, death_act, boss_death (fell in a boss wave), core (final
##   fraction), act_end_core[] (per act, -1 = not finished), core_loss[] (per wave, fraction of the core), peak_bodied[]
##   and peak_minis[] (per wave), max_blasts, signature, primary (weapon id), held[] and offered[] (directive ids),
##   weapons[] (ids carried), data.

const VICTORY: String = "victory"
const DEFEAT: String = "defeat"
const UNFINISHED: String = "unfinished"


## The record of `report` on `content`. `pool` and `variant` say how the card ran it.
static func of(report: HarnessReport, content: ContentSet, pool: String, variant: String) -> Dictionary:
	var rec: Dictionary = {
		"policy": PolicyBot.name_of(report.policy), "variant": variant, "pool": pool, "seed": report.run_seed,
		"result": result_name(report), "clean": report.violations.is_empty() and not report.stalled,
		"ticks": report.ticks, "combat_s": float(report.combat_ticks) / float(SimWorld.TICK_RATE),
		"waves": report.waves_completed, "wave_total": report.wave_total, "death_wave": report.death_wave,
		"death_act": report.death_act, "boss_death": _fell_in_boss_wave(report), "core": report.core_fraction(),
		"max_blasts": report.max_blasts, "signature": report.signature, "data": report.data,
	}
	rec["act_end_core"] = Array(report.act_end_core)
	var loss: Array[float] = []
	for w: int in report.wave_total:
		loss.append(report.core_lost[w] / maxf(report.core_max_hp, 1.0) if w < report.core_lost.size() else 0.0)
	rec["core_loss"] = loss
	rec["peak_bodied"] = Array(report.peak_bodied.slice(1))
	rec["peak_minis"] = Array(report.peak_minis.slice(1))
	rec["primary"] = _weapon_id(content, report.primary_weapon)
	var held: Array[String] = []
	for index: int in report.held.size():
		if report.held[index] > 0 and index < content.directives.size():
			held.append(String(content.directives[index].id))
	rec["held"] = held
	var offered: Array[String] = []
	for index: int in report.offered:
		if index < content.directives.size():
			offered.append(String(content.directives[index].id))
	rec["offered"] = offered
	var carried: Array[String] = []
	for index: int in report.weapons_carried:
		carried.append(_weapon_id(content, index))
	rec["weapons"] = carried
	return rec


static func result_name(report: HarnessReport) -> String:
	if report.timed_out:
		return UNFINISHED
	return VICTORY if report.is_victory() else DEFEAT


# --- reading (JSON turns every number into a float, so every reader converts) ---


static func num(rec: Dictionary, key: String, fallback: float = 0.0) -> float:
	return _number(rec.get(key, fallback), fallback)


static func whole(rec: Dictionary, key: String) -> int:
	return roundi(num(rec, key))


static func text(rec: Dictionary, key: String) -> String:
	var v: Variant = rec.get(key, "")
	if v is String or v is StringName:
		var s: String = v
		return s
	return ""


static func flag(rec: Dictionary, key: String, fallback: bool = false) -> bool:
	var v: Variant = rec.get(key, fallback)
	if v is bool:
		var b: bool = v
		return b
	return fallback


static func floats(rec: Dictionary, key: String) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var v: Variant = rec.get(key, [])
	if v is Array:
		var items: Array = v
		for item: Variant in items:
			out.append(_number(item, 0.0))
	return out


static func strings(rec: Dictionary, key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var v: Variant = rec.get(key, [])
	if v is Array:
		var items: Array = v
		for item: Variant in items:
			var s: String = item
			out.append(s)
	return out


## A JSON number (int or float) as a float; `fallback` for anything else.
static func _number(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		var n: float = v
		return n
	return fallback


static func is_win(rec: Dictionary) -> bool:
	return text(rec, "result") == VICTORY


static func is_loss(rec: Dictionary) -> bool:
	return text(rec, "result") == DEFEAT


# --- selecting ---


## The records of `policy` with `variant` ("" = the main runs).
static func select(runs: Array[Dictionary], policy: String, variant: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in runs:
		if text(rec, "policy") == policy and text(rec, "variant") == variant:
			out.append(rec)
	return out


## The main runs of every policy (variant "").
static func main_runs(runs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in runs:
		if text(rec, "variant") == "":
			out.append(rec)
	return out


static func wins_of(runs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in runs:
		if is_win(rec):
			out.append(rec)
	return out


static func losses_of(runs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in runs:
		if is_loss(rec):
			out.append(rec)
	return out


## Fraction of `runs` that won (0 for none).
static func win_rate(runs: Array[Dictionary]) -> float:
	return ScorecardStats.rate(wins_of(runs).size(), runs.size())


## One JSON line for a record and back; a line that is not a record reads as an empty Dictionary.
static func to_line(rec: Dictionary) -> String:
	return JSON.stringify(rec)


static func from_line(line: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(line)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func _weapon_id(content: ContentSet, index: int) -> String:
	return String(content.weapons[index].id) if index >= 0 and index < content.weapons.size() else ""


static func _fell_in_boss_wave(report: HarnessReport) -> bool:
	if report.death_wave <= 0 or report.world == null or report.world.plan == null:
		return false
	var planned: PlannedWave = report.world.plan.wave(report.death_wave)
	return planned != null and planned.is_boss
