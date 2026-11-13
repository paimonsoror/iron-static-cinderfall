class_name ScorecardRateRows
extends RefCounted
## S4 to S10: win rates and where runs are lost. Every row reads the main runs of its policies (variant "").

const S4_BAND: Vector2 = Vector2(0.40, 0.70)
const S5_MAX: float = 0.10
const S7_BAND: Vector2 = Vector2(0.10, 0.40)
const S8_BEFORE_3_MAX: int = 0
const S8_BEFORE_4_MAX_RATE: float = 0.02
const S9_MIN_ACT_SHARE: float = 0.15
const S9_BOSS_BAND: Vector2 = Vector2(0.25, 0.50)
const S10_BAND: Vector2 = Vector2(0.15, 0.65)
const S10_MAX_ABOVE_BALANCED: float = 0.10
const SPECIALISTS: PackedStringArray = ["hoarder", "spammer", "turret_rush", "risk"]


static func rows(runs: Array[Dictionary]) -> Array[Dictionary]:
	return [
		balanced_wins(runs), random_wins(runs), none_loses(runs), greedy_wins(runs), early_deaths(runs),
		losses_everywhere(runs), specialists(runs),
	]


static func in_band(value: float, band: Vector2) -> bool:
	return value >= band.x - 0.000001 and value <= band.y + 0.000001


static func band_text(band: Vector2) -> String:
	return "%s to %s" % [ScorecardStats.percent(band.x), ScorecardStats.percent(band.y)]


static func _rate_text(runs: Array[Dictionary]) -> String:
	return "%d/%d wins (%s)" % [ScorecardRecord.wins_of(runs).size(), runs.size(), ScorecardStats.percent(ScorecardRecord.win_rate(runs))]


## S4: the competent player is challenged. A policy that wins none of 10 or more runs is a structural break.
static func balanced_wins(runs: Array[Dictionary]) -> Dictionary:
	var balanced: Array[Dictionary] = ScorecardRecord.select(runs, "balanced")
	var target: String = "balanced wins %s" % band_text(S4_BAND)
	if balanced.is_empty():
		return Scorecard.missing("S4", "Is a competent player challenged?", target, "no balanced runs")
	var rate: float = ScorecardRecord.win_rate(balanced)
	var verdict: int = Scorecard.pass_or_warn(in_band(rate, S4_BAND))
	if rate == 0.0 and balanced.size() >= Scorecard.MIN_RUNS_FOR_FAIL:
		verdict = Scorecard.Verdict.FAIL
	return Scorecard.row("S4", "Is a competent player challenged?", rate, _rate_text(balanced), target, verdict)


## S5: skill matters, so the random player almost never wins.
static func random_wins(runs: Array[Dictionary]) -> Dictionary:
	var random: Array[Dictionary] = ScorecardRecord.select(runs, "random")
	var target: String = "random wins at most %s" % ScorecardStats.percent(S5_MAX)
	if random.is_empty():
		return Scorecard.missing("S5", "Does skill matter?", target, "no random runs")
	var rate: float = ScorecardRecord.win_rate(random)
	return Scorecard.row("S5", "Does skill matter?", rate, _rate_text(random), target, Scorecard.pass_or_warn(rate <= S5_MAX))


## S6: a player who does nothing always loses, in act I. A win is a structural break.
static func none_loses(runs: Array[Dictionary]) -> Dictionary:
	var none: Array[Dictionary] = ScorecardRecord.select(runs, "none")
	var target: String = "none is always defeated in act I"
	if none.is_empty():
		return Scorecard.missing("S6", "Does skill matter?", target, "no none runs")
	var wins: int = ScorecardRecord.wins_of(none).size()
	var in_act_one: int = 0
	for rec: Dictionary in ScorecardRecord.losses_of(none):
		in_act_one += 1 if ScorecardRecord.whole(rec, "death_act") <= 1 else 0
	var measured: String = "%d/%d defeated in act I (%d wins)" % [in_act_one, none.size(), wins]
	var verdict: int = Scorecard.Verdict.PASS
	if wins > 0:
		verdict = Scorecard.Verdict.FAIL
	elif in_act_one < none.size():
		verdict = Scorecard.Verdict.WARN
	return Scorecard.row("S6", "Does skill matter?", float(wins), measured, target, verdict)


## S7: the old cheapest-first habit no longer wins every run.
static func greedy_wins(runs: Array[Dictionary]) -> Dictionary:
	var greedy: Array[Dictionary] = ScorecardRecord.select(runs, "greedy")
	var target: String = "greedy wins %s" % band_text(S7_BAND)
	if greedy.is_empty():
		return Scorecard.missing("S7", "Does skill matter?", target, "no greedy runs")
	var rate: float = ScorecardRecord.win_rate(greedy)
	return Scorecard.row("S7", "Does skill matter?", rate, _rate_text(greedy), target, Scorecard.pass_or_warn(in_band(rate, S7_BAND)))


## S8: early waves are survivable: no policy other than `none` is defeated before wave 3, and before wave 4 at most 2% of the
## runs. The `balanced` player (the reference) defeated before wave 3 is a structural break (FAIL); any other policy that fell
## early is a number to fix in the waves (WARN, named in the detail lines): `random` is allowed to play badly, but not to meet
## a wave 2 nobody could survive.
static func early_deaths(runs: Array[Dictionary]) -> Dictionary:
	var played: int = 0
	var before_3: int = 0
	var before_4: int = 0
	var reference_before_3: int = 0
	var by_policy: Dictionary[String, PackedInt32Array] = {}  ## policy -> [runs, before wave 3, before wave 4]
	for rec: Dictionary in ScorecardRecord.main_runs(runs):
		var policy: String = ScorecardRecord.text(rec, "policy")
		if policy == "none":
			continue
		played += 1
		var tally: PackedInt32Array = by_policy.get(policy, PackedInt32Array([0, 0, 0]))
		tally[0] += 1
		if ScorecardRecord.is_loss(rec):
			var wave: int = ScorecardRecord.whole(rec, "death_wave")
			before_3 += 1 if wave < 3 else 0
			before_4 += 1 if wave < 4 else 0
			reference_before_3 += 1 if wave < 3 and policy == "balanced" else 0
			tally[1] += 1 if wave < 3 else 0
			tally[2] += 1 if wave < 4 else 0
		by_policy[policy] = tally
	var target: String = "0 defeats before wave 3; before wave 4 at most %s" % ScorecardStats.percent(S8_BEFORE_4_MAX_RATE)
	if played == 0:
		return Scorecard.missing("S8", "Are early waves survivable?", target, "no runs")
	var rate_4: float = ScorecardStats.rate(before_4, played)
	var measured: String = "%d before wave 3, %d before wave 4 (%s) of %d runs" % [before_3, before_4, ScorecardStats.percent(rate_4), played]
	var verdict: int = Scorecard.pass_or_warn(rate_4 <= S8_BEFORE_4_MAX_RATE and before_3 <= S8_BEFORE_3_MAX)
	if reference_before_3 > S8_BEFORE_3_MAX:
		verdict = Scorecard.Verdict.FAIL
	var detail: PackedStringArray = PackedStringArray()
	for policy: String in by_policy:
		var t: PackedInt32Array = by_policy[policy]
		if t[2] > 0:
			detail.append("%s: %d before wave 3, %d before wave 4, of %d runs" % [policy, t[1], t[2], t[0]])
	return Scorecard.row("S8", "Are early waves survivable?", float(before_3), measured, target, verdict, detail)


## S9: the `balanced` losses are spread over the acts (each holds 15% or more) and the boss waves hold 25% to 50%.
static func losses_everywhere(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Is loss possible everywhere?"
	var target: String = "each act >= %s of the losses; boss waves %s" % [ScorecardStats.percent(S9_MIN_ACT_SHARE), band_text(S9_BOSS_BAND)]
	var losses: Array[Dictionary] = ScorecardRecord.losses_of(ScorecardRecord.select(runs, "balanced"))
	if losses.is_empty():
		return Scorecard.missing("S9", question, target, "balanced lost no run")
	var acts: int = 1
	for rec: Dictionary in ScorecardRecord.select(runs, "balanced"):
		acts = maxi(acts, ScorecardRecord.whole(rec, "death_act"))
		acts = maxi(acts, ScorecardRecord.floats(rec, "act_end_core").size())
	var per_act: PackedInt32Array = PackedInt32Array()
	per_act.resize(acts)
	var boss: int = 0
	for rec: Dictionary in losses:
		var act: int = clampi(ScorecardRecord.whole(rec, "death_act"), 1, acts)
		per_act[act - 1] += 1
		boss += 1 if ScorecardRecord.flag(rec, "boss_death") else 0
	var ok: bool = true
	var parts: PackedStringArray = PackedStringArray()
	for a: int in acts:
		var share: float = ScorecardStats.rate(per_act[a], losses.size())
		ok = ok and share >= S9_MIN_ACT_SHARE
		parts.append("act %d %s" % [a + 1, ScorecardStats.percent(share)])
	var boss_share: float = ScorecardStats.rate(boss, losses.size())
	ok = ok and in_band(boss_share, S9_BOSS_BAND)
	var measured: String = "%d losses: %s; boss waves %s" % [losses.size(), ", ".join(parts), ScorecardStats.percent(boss_share)]
	return Scorecard.row("S9", question, boss_share, measured, target, Scorecard.pass_or_warn(ok))


## S10: no specialist is dominant or hopeless: each wins 15% to 65% and none beats `balanced` by more than 10 points.
static func specialists(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Is there a dominant strategy?"
	var target: String = "each %s, none more than %.0f points above balanced" % [band_text(S10_BAND), 100.0 * S10_MAX_ABOVE_BALANCED]
	var balanced: Array[Dictionary] = ScorecardRecord.select(runs, "balanced")
	var base: float = ScorecardRecord.win_rate(balanced)
	var ok: bool = true
	var parts: PackedStringArray = PackedStringArray()
	var best: float = 0.0
	var played: int = 0
	for policy: String in SPECIALISTS:
		var group: Array[Dictionary] = ScorecardRecord.select(runs, policy)
		if group.is_empty():
			parts.append("%s not played" % policy)
			ok = false
			continue
		played += 1
		var rate: float = ScorecardRecord.win_rate(group)
		best = maxf(best, rate)
		ok = ok and in_band(rate, S10_BAND) and rate - base <= S10_MAX_ABOVE_BALANCED + 0.000001
		parts.append("%s %s" % [policy, ScorecardStats.percent(rate)])
	if played == 0:
		return Scorecard.missing("S10", question, target, "no specialist runs")
	var measured: String = "%s (balanced %s)" % [", ".join(parts), ScorecardStats.percent(base)]
	return Scorecard.row("S10", question, best, measured, target, Scorecard.pass_or_warn(ok))
