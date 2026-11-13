class_name ScorecardSeedRows
extends RefCounted
## S1 to S3: do seeds matter? All three read the `balanced` runs (the competent player) over different seeds.

const S1_MIN_STDEV: float = 0.12
const S2_MIN_STDEV_S: float = 45.0
const S3_MAX_MEDIAN_JACCARD: float = 0.35
const POLICY: String = "balanced"
const QUESTION: String = "Do seeds matter?"


static func rows(runs: Array[Dictionary]) -> Array[Dictionary]:
	var balanced: Array[Dictionary] = ScorecardRecord.select(runs, POLICY)
	return [_core_spread(balanced), _duration_spread(balanced), _build_overlap(balanced)]


## S1: standard deviation over seeds of the core fraction when act I ended (0 for a run that fell in act I).
static func _core_spread(balanced: Array[Dictionary]) -> Dictionary:
	var target: String = "stdev >= %.2f" % S1_MIN_STDEV
	if balanced.size() < 2:
		return Scorecard.missing("S1", QUESTION, target, "needs 2 balanced runs")
	var core: PackedFloat64Array = PackedFloat64Array()
	for rec: Dictionary in balanced:
		var ends: PackedFloat64Array = ScorecardRecord.floats(rec, "act_end_core")
		core.append(maxf(0.0, ends[0]) if not ends.is_empty() else 0.0)
	var spread: float = ScorecardStats.stdev(core)
	var measured: String = "stdev %.3f (mean %.2f, min %.2f, max %.2f, %d runs)" % [
		spread, ScorecardStats.mean(core), ScorecardStats.min_of(core), ScorecardStats.max_of(core), core.size(),
	]
	return Scorecard.row("S1", QUESTION, spread, measured, target, Scorecard.pass_or_warn(spread >= S1_MIN_STDEV))


## S2: standard deviation of the combat time among the wins.
static func _duration_spread(balanced: Array[Dictionary]) -> Dictionary:
	var target: String = "stdev >= %.0f s" % S2_MIN_STDEV_S
	var seconds: PackedFloat64Array = PackedFloat64Array()
	for rec: Dictionary in ScorecardRecord.wins_of(balanced):
		seconds.append(ScorecardRecord.num(rec, "combat_s"))
	if seconds.size() < 2:
		return Scorecard.missing("S2", QUESTION, target, "needs 2 balanced wins (have %d)" % seconds.size())
	var spread: float = ScorecardStats.stdev(seconds)
	var measured: String = "stdev %.1f s (mean %.0f, min %.0f, max %.0f, %d wins)" % [
		spread, ScorecardStats.mean(seconds), ScorecardStats.min_of(seconds), ScorecardStats.max_of(seconds), seconds.size(),
	]
	return Scorecard.row("S2", QUESTION, spread, measured, target, Scorecard.pass_or_warn(spread >= S2_MIN_STDEV_S))


## S3: median Jaccard similarity of the final directive sets of two runs on different seeds.
static func _build_overlap(balanced: Array[Dictionary]) -> Dictionary:
	var target: String = "median similarity <= %.2f" % S3_MAX_MEDIAN_JACCARD
	if balanced.size() < 2:
		return Scorecard.missing("S3", QUESTION, target, "needs 2 balanced runs")
	var sets: Array[PackedStringArray] = []
	for rec: Dictionary in balanced:
		sets.append(ScorecardRecord.strings(rec, "held"))
	var pairs: PackedFloat64Array = ScorecardStats.pairwise_jaccard(sets)
	var med: float = ScorecardStats.median(pairs)
	var measured: String = "median %.3f over %d pairs (max %.2f)" % [med, pairs.size(), ScorecardStats.max_of(pairs)]
	return Scorecard.row("S3", QUESTION, med, measured, target, Scorecard.pass_or_warn(med <= S3_MAX_MEDIAN_JACCARD))
