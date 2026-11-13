class_name Scorecard
extends RefCounted
## The predictability scorecard (VARIETY_SPEC 14.2, GDD 8.4): rows S1 to S18 computed from finished runs, plus an
## `integrity` row in front (a run that did not finish or broke an invariant is a structural break, as in balance_run).
##
## PASS    the measured value is inside the target.
## WARN    a measured value is outside its target: the number is printed, nothing is hidden. A row that has too few runs
##         to be computed (a specialist that was not played, no wins to take a duration of) warns too.
## FAIL    a structural break: a run that did not finish, stalled or broke an invariant; `none` winning; `balanced` winning
##         none of at least 10 runs; `balanced` defeated before wave 3; a cap of the chaos budget exceeded.
## The tool exits 0 on PASS and WARN and 1 on FAIL.
##
## `runs`: ScorecardRecord dictionaries. `context`: what the content says (ScorecardPlan.context). The rows come back as
## { id, question, value (the main number), measured, target (texts), verdict (Verdict), detail (PackedStringArray) }.
## The row functions live in ScorecardSeedRows (S1-S3), ScorecardRateRows (S4-S10), ScorecardBuildRows (S11-S13) and
## ScorecardRunRows (S14-S18).

enum Verdict { PASS, WARN, FAIL }

const VERDICT_NAMES: PackedStringArray = ["PASS", "WARN", "FAIL"]
## Fewest runs of a kind that a win rate of 0 can be called a structural break on.
const MIN_RUNS_FOR_FAIL: int = 10


static func evaluate(runs: Array[Dictionary], context: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(integrity_row(runs))
	rows.append_array(ScorecardSeedRows.rows(runs))
	rows.append_array(ScorecardRateRows.rows(runs))
	rows.append_array(ScorecardBuildRows.rows(runs, context))
	rows.append_array(ScorecardRunRows.rows(runs, context))
	return rows


static func verdict_name(verdict: int) -> String:
	return VERDICT_NAMES[clampi(verdict, 0, 2)]


## The worst verdict of the rows (PASS for none).
static func worst(rows: Array[Dictionary]) -> int:
	var out: int = Verdict.PASS
	for rw: Dictionary in rows:
		var v: int = rw["verdict"]
		out = maxi(out, v)
	return out


static func count(rows: Array[Dictionary], verdict: int) -> int:
	var n: int = 0
	for rw: Dictionary in rows:
		var v: int = rw["verdict"]
		if v == verdict:
			n += 1
	return n


## The last line of the tool: `SCORECARD: PASS|WARN|FAIL rows=.. pass=.. warn=.. fail=.. runs=..`.
static func summary_line(rows: Array[Dictionary], run_count: int) -> String:
	return (
		"SCORECARD: %s rows=%d pass=%d warn=%d fail=%d runs=%d"
		% [
			verdict_name(worst(rows)), rows.size(), count(rows, Verdict.PASS), count(rows, Verdict.WARN),
			count(rows, Verdict.FAIL), run_count,
		]
	)


## One row. `detail` lines are printed under it by the tool.
static func row(
	id: String, question: String, value: float, measured: String, target: String, verdict: int,
	detail: PackedStringArray = PackedStringArray()
) -> Dictionary:
	return {
		"id": id, "question": question, "value": value, "measured": measured, "target": target, "verdict": verdict,
		"detail": detail,
	}


## PASS when `ok`, else WARN.
static func pass_or_warn(ok: bool) -> int:
	return Verdict.PASS if ok else Verdict.WARN


## The row for a metric that could not be computed for want of runs.
static func missing(id: String, question: String, target: String, what: String) -> Dictionary:
	return row(id, question, 0.0, "not measured: %s" % what, target, Verdict.WARN)


## Row 0: every run finished, none stalled or broke an invariant (a structural break otherwise).
static func integrity_row(runs: Array[Dictionary]) -> Dictionary:
	var unfinished: int = 0
	var unclean: int = 0
	for rec: Dictionary in runs:
		if ScorecardRecord.text(rec, "result") == ScorecardRecord.UNFINISHED:
			unfinished += 1
		if not ScorecardRecord.flag(rec, "clean", true):
			unclean += 1
	var verdict: int = Verdict.PASS if unfinished == 0 and unclean == 0 else Verdict.FAIL
	var measured: String = "%d runs, %d unfinished, %d stalled or broke an invariant" % [runs.size(), unfinished, unclean]
	return row("integrity", "Did every run finish clean?", float(unfinished + unclean), measured, "0 unfinished, 0 unclean", verdict)
