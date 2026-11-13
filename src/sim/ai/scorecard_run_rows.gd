class_name ScorecardRunRows
extends RefCounted
## S14 to S18: routes, the meta pool, the length of a run, the chaos budget and the fairness rule for the greedy player.

const S14_BAND: Vector2 = Vector2(0.25, 0.65)
const S15_MAX_DIFFERENCE: float = 0.05
const S16_BAND_S: Vector2 = Vector2(780.0, 1020.0)
const S17_TOLERANCE: float = 0.20
const S18_MAX_LOSS: float = 0.60


static func rows(runs: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	return [routes(runs), pools(runs), length(runs), chaos(runs, context), fairness(runs, context)]


## S14: `balanced` forced to the standard route every time against the hot route every time: both win 25% to 65%, and the
## hot runs bank more Data.
static func routes(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Do routes matter?"
	var target: String = "both %s; hot banks more Data" % ScorecardRateRows.band_text(S14_BAND)
	var standard: Array[Dictionary] = ScorecardRecord.select(runs, "balanced", "standard")
	var hot: Array[Dictionary] = ScorecardRecord.select(runs, "balanced", "hot")
	if standard.is_empty() or hot.is_empty():
		return Scorecard.missing("S14", question, target, "the forced-route runs were not played")
	var standard_rate: float = ScorecardRecord.win_rate(standard)
	var hot_rate: float = ScorecardRecord.win_rate(hot)
	var standard_data: float = _mean_of(standard, "data")
	var hot_data: float = _mean_of(hot, "data")
	var measured: String = "standard %s, %.0f Data; hot %s, %.0f Data" % [
		ScorecardStats.percent(standard_rate), standard_data, ScorecardStats.percent(hot_rate), hot_data,
	]
	var ok: bool = ScorecardRateRows.in_band(standard_rate, S14_BAND) and ScorecardRateRows.in_band(hot_rate, S14_BAND)
	return Scorecard.row("S14", question, hot_data - standard_data, measured, target, Scorecard.pass_or_warn(ok and hot_data > standard_data))


## S15: `balanced` wins the same share of the same seeds with the base pool and with the full pool (within 5 points).
static func pools(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Does the meta pool keep builds reachable?"
	var target: String = "win rates differ by at most %.0f points" % (100.0 * S15_MAX_DIFFERENCE)
	var by_pool: Dictionary[String, Array] = {"base": [], "full": []}
	for rec: Dictionary in ScorecardRecord.select(runs, "balanced") + ScorecardRecord.select(runs, "balanced", "other_pool"):
		var group: Array = by_pool.get(ScorecardRecord.text(rec, "pool"), [])
		group.append(rec)
	var base: Array[Dictionary] = _typed(by_pool["base"])
	var full: Array[Dictionary] = _typed(by_pool["full"])
	if base.is_empty() or full.is_empty():
		return Scorecard.missing("S15", question, target, "needs balanced runs in both pools")
	var gap: float = ScorecardRecord.win_rate(full) - ScorecardRecord.win_rate(base)
	var measured: String = "base %s, full %s (%+.1f points)" % [
		ScorecardStats.percent(ScorecardRecord.win_rate(base)), ScorecardStats.percent(ScorecardRecord.win_rate(full)), 100.0 * gap,
	]
	return Scorecard.row("S15", question, gap, measured, target, Scorecard.pass_or_warn(absf(gap) <= S15_MAX_DIFFERENCE))


## S16: the combat time of a `balanced` win (median) is 780 to 1,020 s.
static func length(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Is the run the right length?"
	var target: String = "combat time of wins %.0f to %.0f s" % [S16_BAND_S.x, S16_BAND_S.y]
	var seconds: PackedFloat64Array = PackedFloat64Array()
	for rec: Dictionary in ScorecardRecord.wins_of(ScorecardRecord.select(runs, "balanced")):
		seconds.append(ScorecardRecord.num(rec, "combat_s"))
	if seconds.is_empty():
		return Scorecard.missing("S16", question, target, "balanced won no run")
	var med: float = ScorecardStats.median(seconds)
	var measured: String = "median %.0f s (mean %.0f, min %.0f, max %.0f, %d wins)" % [
		med, ScorecardStats.mean(seconds), ScorecardStats.min_of(seconds), ScorecardStats.max_of(seconds), seconds.size(),
	]
	return Scorecard.row("S16", question, med, measured, target, Scorecard.pass_or_warn(med >= S16_BAND_S.x and med <= S16_BAND_S.y))


## S17: the chaos budget. A cap exceeded by any run is a structural break (FAIL). The median peak of bodied enemies and of
## minis per wave of the `balanced` runs that reached the wave should sit within 20% of the table of the data (WARN).
static func chaos(runs: Array[Dictionary], context: Dictionary) -> Dictionary:
	var question: String = "Is the chaos budget respected?"
	var target: String = "caps held; median peaks within %.0f%% of the wave table" % (100.0 * S17_TOLERANCE)
	var cap_bodied: int = ScorecardRecord.whole(context, "cap_bodied")
	var cap_minis: int = ScorecardRecord.whole(context, "cap_minis")
	var cap_blasts: int = ScorecardRecord.whole(context, "cap_blasts")
	var top_bodied: int = 0
	var top_minis: int = 0
	var top_blasts: int = 0
	for rec: Dictionary in runs:
		top_bodied = maxi(top_bodied, roundi(ScorecardStats.max_of(ScorecardRecord.floats(rec, "peak_bodied"))))
		top_minis = maxi(top_minis, roundi(ScorecardStats.max_of(ScorecardRecord.floats(rec, "peak_minis"))))
		top_blasts = maxi(top_blasts, ScorecardRecord.whole(rec, "max_blasts"))
	var broken: bool = (cap_bodied > 0 and top_bodied > cap_bodied) or (cap_minis > 0 and top_minis > cap_minis)
	broken = broken or (cap_blasts > 0 and top_blasts > cap_blasts)
	var detail: PackedStringArray = PackedStringArray()
	var off: int = _peak_rows(ScorecardRecord.select(runs, "balanced"), context, detail)
	var measured: String = "highest bodied %d (cap %d), minis %d (cap %d), blasts per tick %d (cap %d); %d wave peaks outside the table" % [
		top_bodied, cap_bodied, top_minis, cap_minis, top_blasts, cap_blasts, off,
	]
	var verdict: int = Scorecard.Verdict.FAIL if broken else Scorecard.pass_or_warn(off == 0)
	return Scorecard.row("S17", question, float(off), measured, target, verdict, detail)


## S18: the greedy player never loses more than 60% of the core in one wave of act I. The worst wave over the runs.
static func fairness(runs: Array[Dictionary], context: Dictionary) -> Dictionary:
	var question: String = "Fairness rule 7.3.8"
	var target: String = "greedy: largest core loss in one act I wave at most %s" % ScorecardStats.percent(S18_MAX_LOSS)
	var greedy: Array[Dictionary] = ScorecardRecord.select(runs, "greedy")
	if greedy.is_empty():
		return Scorecard.missing("S18", question, target, "no greedy runs")
	var act_one_waves: int = maxi(1, ScorecardRecord.whole(context, "act1_waves"))
	var worst: float = 0.0
	var worst_wave: int = 0
	for rec: Dictionary in greedy:
		var loss: PackedFloat64Array = ScorecardRecord.floats(rec, "core_loss")
		for w: int in mini(act_one_waves, loss.size()):
			if loss[w] > worst:
				worst = loss[w]
				worst_wave = w + 1
	var measured: String = "%s in wave %d (%d greedy runs)" % [ScorecardStats.percent(worst), worst_wave, greedy.size()]
	return Scorecard.row("S18", question, worst, measured, target, Scorecard.pass_or_warn(worst <= S18_MAX_LOSS))


## Appends one detail line per wave and returns how many median peaks (bodied or minis) fall outside the table.
static func _peak_rows(balanced: Array[Dictionary], context: Dictionary, detail: PackedStringArray) -> int:
	var want_bodied: PackedFloat64Array = ScorecardRecord.floats(context, "wave_bodied")
	var want_minis: PackedFloat64Array = ScorecardRecord.floats(context, "wave_minis")
	var off: int = 0
	for w: int in want_bodied.size():
		var bodied: PackedFloat64Array = PackedFloat64Array()
		var minis: PackedFloat64Array = PackedFloat64Array()
		for rec: Dictionary in balanced:
			if not _reached(rec, w + 1):
				continue
			var pb: PackedFloat64Array = ScorecardRecord.floats(rec, "peak_bodied")
			var pm: PackedFloat64Array = ScorecardRecord.floats(rec, "peak_minis")
			bodied.append(pb[w] if w < pb.size() else 0.0)
			minis.append(pm[w] if w < pm.size() else 0.0)
		if bodied.is_empty():
			continue
		var median_bodied: float = ScorecardStats.median(bodied)
		var median_minis: float = ScorecardStats.median(minis)
		var inside: bool = _within(median_bodied, want_bodied[w]) and _within(median_minis, want_minis[w] if w < want_minis.size() else 0.0)
		off += 0 if inside else 1
		detail.append("wave %d: bodied median %.1f (table %.0f), minis median %.1f (table %.0f), %d runs reached it%s" % [
			w + 1, median_bodied, want_bodied[w], median_minis, want_minis[w] if w < want_minis.size() else 0.0, bodied.size(),
			"" if inside else "  OUTSIDE",
		])
	return off


## Within 20% of `want`, or within one enemy for a table value too small for a percentage to mean anything.
static func _within(value: float, want: float) -> bool:
	return absf(value - want) <= maxf(1.0, S17_TOLERANCE * want)


## The run played wave `wave_number`: it won, or it fell in that wave or a later one.
static func _reached(rec: Dictionary, wave_number: int) -> bool:
	return ScorecardRecord.is_win(rec) or ScorecardRecord.whole(rec, "death_wave") >= wave_number


static func _mean_of(group: Array[Dictionary], key: String) -> float:
	var values: PackedFloat64Array = PackedFloat64Array()
	for rec: Dictionary in group:
		values.append(ScorecardRecord.num(rec, key))
	return ScorecardStats.mean(values)


static func _typed(group: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in group:
		var rec: Dictionary = item
		out.append(rec)
	return out
