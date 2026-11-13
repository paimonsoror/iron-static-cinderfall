class_name ScorecardBuildRows
extends RefCounted
## S11 to S13: how many different builds win, and whether one weapon or one directive carries them. Every row reads the
## main runs (variant "") of the policies named in its description.

const S11_MIN_SIGNATURES: int = 8
const S11_MIN_SHARE: float = 0.04
const S11_MAX_SHARE: float = 0.25
const S12_MAX_SHARE: float = 0.30
const S12_MIN_SHARE: float = 0.03
const S13_MAX_SWING: float = 0.15
## Fewest runs in each of the two groups of S13 (held, offered and not picked) for a directive to count.
const S13_MIN_GROUP: int = 6
const S13_POLICIES: PackedStringArray = ["random", "balanced"]


static func rows(runs: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var wins: Array[Dictionary] = ScorecardRecord.wins_of(ScorecardRecord.main_runs(runs))
	return [_signatures(wins), _weapons(wins, context), _directives(runs)]


## S11: build signatures among the wins: at least 8 with 4% or more of the wins each, none above 25%.
static func _signatures(wins: Array[Dictionary]) -> Dictionary:
	var question: String = "How many winning builds?"
	var target: String = ">= %d signatures with %s or more of the wins, none above %s" % [
		S11_MIN_SIGNATURES, ScorecardStats.percent(S11_MIN_SHARE), ScorecardStats.percent(S11_MAX_SHARE),
	]
	if wins.is_empty():
		return Scorecard.missing("S11", question, target, "no wins")
	var names: PackedStringArray = PackedStringArray()
	for rec: Dictionary in wins:
		names.append(ScorecardRecord.text(rec, "signature"))
	var counts: Dictionary[String, int] = ScorecardStats.tally(names)
	var common: int = 0
	var top_share: float = 0.0
	var top_name: String = ""
	for signature: String in counts:
		var share: float = ScorecardStats.rate(counts[signature], wins.size())
		common += 1 if share >= S11_MIN_SHARE else 0
		if share > top_share:
			top_share = share
			top_name = signature
	var measured: String = "%d signatures in %d wins, %d with >= %s; top %s %s" % [
		counts.size(), wins.size(), common, ScorecardStats.percent(S11_MIN_SHARE), top_name, ScorecardStats.percent(top_share),
	]
	var ok: bool = common >= S11_MIN_SIGNATURES and top_share <= S11_MAX_SHARE
	return Scorecard.row("S11", question, float(common), measured, target, Scorecard.pass_or_warn(ok), _share_lines(counts, wins.size()))


## S12: share of the wins by primary weapon: none above 30%, every weapon of the pool at least 3%.
static func _weapons(wins: Array[Dictionary], context: Dictionary) -> Dictionary:
	var question: String = "Is a weapon dominant?"
	var target: String = "none above %s; every weapon >= %s" % [ScorecardStats.percent(S12_MAX_SHARE), ScorecardStats.percent(S12_MIN_SHARE)]
	if wins.is_empty():
		return Scorecard.missing("S12", question, target, "no wins")
	var names: PackedStringArray = PackedStringArray()
	for rec: Dictionary in wins:
		names.append(ScorecardRecord.text(rec, "primary"))
	var counts: Dictionary[String, int] = ScorecardStats.tally(names)
	var roster: PackedStringArray = ScorecardRecord.strings(context, "roster")
	var top_share: float = 0.0
	for weapon: String in counts:
		top_share = maxf(top_share, ScorecardStats.rate(counts[weapon], wins.size()))
	var missing: PackedStringArray = PackedStringArray()
	for weapon: String in roster:
		var n: int = counts.get(weapon, 0)
		if ScorecardStats.rate(n, wins.size()) < S12_MIN_SHARE:
			missing.append(weapon)
	var measured: String = "top share %s; below %s: %s" % [
		ScorecardStats.percent(top_share), ScorecardStats.percent(S12_MIN_SHARE), ", ".join(missing) if not missing.is_empty() else "none",
	]
	var ok: bool = top_share <= S12_MAX_SHARE and missing.is_empty()
	return Scorecard.row("S12", question, top_share, measured, target, Scorecard.pass_or_warn(ok), _share_lines(counts, wins.size()))


## S13: for each directive, the win rate of the runs that held it minus the win rate of the runs that were offered it and
## did not take it (`random` and `balanced` pooled); none beyond +/-15 points. Directives with fewer than 6 runs in
## either group are left out and counted.
static func _directives(runs: Array[Dictionary]) -> Dictionary:
	var question: String = "Is a directive dominant?"
	var target: String = "held minus offered-not-picked within +/-%.0f points" % (100.0 * S13_MAX_SWING)
	var pooled: Array[Dictionary] = []
	for policy: String in S13_POLICIES:
		pooled.append_array(ScorecardRecord.select(runs, policy))
	var ids: PackedStringArray = PackedStringArray()
	for rec: Dictionary in pooled:
		for id: String in ScorecardRecord.strings(rec, "held") + ScorecardRecord.strings(rec, "offered"):
			if not ids.has(id):
				ids.append(id)
	ids.sort()
	var detail: PackedStringArray = PackedStringArray()
	var worst_swing: float = 0.0
	var worst_id: String = ""
	var counted: int = 0
	for id: String in ids:
		var held: Array[Dictionary] = []
		var passed: Array[Dictionary] = []
		for rec: Dictionary in pooled:
			if ScorecardRecord.strings(rec, "held").has(id):
				held.append(rec)
			elif ScorecardRecord.strings(rec, "offered").has(id):
				passed.append(rec)
		if held.size() < S13_MIN_GROUP or passed.size() < S13_MIN_GROUP:
			continue
		counted += 1
		var swing: float = ScorecardRecord.win_rate(held) - ScorecardRecord.win_rate(passed)
		detail.append("%s held %d (%s) vs passed %d (%s): %+.0f points" % [
			id, held.size(), ScorecardStats.percent(ScorecardRecord.win_rate(held)), passed.size(),
			ScorecardStats.percent(ScorecardRecord.win_rate(passed)), 100.0 * swing,
		])
		if absf(swing) > absf(worst_swing):
			worst_swing = swing
			worst_id = id
	if counted == 0:
		return Scorecard.missing("S13", question, target, "no directive has %d runs held and %d passed" % [S13_MIN_GROUP, S13_MIN_GROUP])
	var measured: String = "%d of %d directives counted; largest swing %+.0f points (%s)" % [counted, ids.size(), 100.0 * worst_swing, worst_id]
	return Scorecard.row("S13", question, worst_swing, measured, target, Scorecard.pass_or_warn(absf(worst_swing) <= S13_MAX_SWING), detail)


## "name count (share)" lines, the most frequent first (equal counts by name).
static func _share_lines(counts: Dictionary[String, int], total: int) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: String in counts:
		keys.append(key)
	for i: int in range(1, keys.size()):
		var j: int = i
		while j > 0 and _comes_first(counts, keys[j], keys[j - 1]):
			var held: String = keys[j]
			keys[j] = keys[j - 1]
			keys[j - 1] = held
			j -= 1
	var out: PackedStringArray = PackedStringArray()
	for key: String in keys:
		out.append("%s %d (%s)" % [key, counts[key], ScorecardStats.percent(ScorecardStats.rate(counts[key], total))])
	return out


static func _comes_first(counts: Dictionary[String, int], a: String, b: String) -> bool:
	return counts[a] > counts[b] or (counts[a] == counts[b] and a < b)
