class_name BalanceTargets
extends RefCounted
## GDD 8.4 as rows: what a set of seeded runs measured against what the design asks for.
##
## PASS    the measured value is inside the target band.
## WARN    a measured value (duration, a peak, core integrity, a win rate) is outside its band: the gap is reported
##         with its number, nothing is hidden.
## FAIL    a structural rule is broken: a run that buys nothing wins, the greedy bot wins fewer than half its runs,
##         or a run did not finish or broke a sim invariant.
## The tool exits 0 on PASS and WARN, 1 on FAIL. Each row is {id, measured, target, status}.

enum Status { PASS, WARN, FAIL }

## GDD 8.4: peak alive per wave, each within +/-20%.
const PEAK_TARGETS: Array[int] = [10, 18, 28, 40, 50]
const PEAK_TOLERANCE: float = 0.20
## GDD 8.4: first-win run length in seconds.
const DURATION_MIN_S: float = 270.0
const DURATION_MAX_S: float = 360.0
## GDD 8.4: a bot that buys nothing is defeated in wave 3 or 4.
const NONE_DEATH_WAVES: Array[int] = [3, 4]
## GDD 8.4: the greedy bot wins with 30% to 80% core integrity left.
const CORE_MIN: float = 0.30
const CORE_MAX: float = 0.80
## Share of greedy runs that must win for the "greedy wins" row to pass / not fail.
const WIN_RATE_PASS: float = 0.90
const WIN_RATE_FAIL_BELOW: float = 0.50


const STATUS_NAMES: PackedStringArray = ["PASS", "WARN", "FAIL"]


static func status_name(status: int) -> String:
	return STATUS_NAMES[clampi(status, 0, 2)]


## The rows for `none_runs` (policy NONE) and `greedy_runs` (policy GREEDY) played on the same seeds.
static func evaluate(none_runs: Array[HarnessReport], greedy_runs: Array[HarnessReport]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(_integrity_row(none_runs, greedy_runs))
	rows.append(_none_row(none_runs))
	rows.append(_win_rate_row(greedy_runs))
	rows.append(_core_row(greedy_runs))
	rows.append(_duration_row(greedy_runs))
	for w: int in 5:
		rows.append(_peak_row(greedy_runs, w))
	return rows


static func worst(rows: Array[Dictionary]) -> int:
	var out: int = Status.PASS
	for row: Dictionary in rows:
		var s: int = row["status"]
		out = maxi(out, s)
	return out


static func count(rows: Array[Dictionary], status: int) -> int:
	var n: int = 0
	for row: Dictionary in rows:
		var s: int = row["status"]
		if s == status:
			n += 1
	return n


static func median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var mid: int = sorted.size() >> 1
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return 0.5 * (sorted[mid - 1] + sorted[mid])


static func min_of(values: PackedFloat64Array) -> float:
	var out: float = INF
	for v: float in values:
		out = minf(out, v)
	return 0.0 if values.is_empty() else out


static func max_of(values: PackedFloat64Array) -> float:
	var out: float = -INF
	for v: float in values:
		out = maxf(out, v)
	return 0.0 if values.is_empty() else out


static func mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


static func _row(id: String, measured: String, target: String, status: int) -> Dictionary:
	return {"id": id, "measured": measured, "target": target, "status": status}


static func _integrity_row(none_runs: Array[HarnessReport], greedy_runs: Array[HarnessReport]) -> Dictionary:
	var bad: int = 0
	var unfinished: int = 0
	for r: HarnessReport in none_runs + greedy_runs:
		bad += r.violations.size()
		unfinished += 1 if r.timed_out else 0
	var runs: int = none_runs.size() + greedy_runs.size()
	var status: int = Status.PASS if (bad == 0 and unfinished == 0) else Status.FAIL
	return _row("integrity", "%d runs, %d unfinished, %d violations" % [runs, unfinished, bad], "0 unfinished, 0 violations", status)


static func _none_row(runs: Array[HarnessReport]) -> Dictionary:
	var wins: int = 0
	var in_band: int = 0
	var waves: PackedFloat64Array = PackedFloat64Array()
	for r: HarnessReport in runs:
		wins += 1 if r.is_victory() else 0
		if r.result == RunResult.Id.DEFEAT:
			waves.append(float(r.wave_reached))
			in_band += 1 if NONE_DEATH_WAVES.has(r.wave_reached) else 0
	var status: int = Status.PASS
	if wins > 0:
		status = Status.FAIL
	elif in_band < runs.size():
		status = Status.WARN
	var text: String = "%d/%d lose in wave 3 or 4 (median death wave %.1f, %d wins)" % [in_band, runs.size(), median(waves), wins]
	return _row("none_loses", text, "every run is defeated in wave 3 or 4", status)


static func _win_rate_row(runs: Array[HarnessReport]) -> Dictionary:
	var wins: int = 0
	for r: HarnessReport in runs:
		wins += 1 if r.is_victory() else 0
	var rate: float = float(wins) / maxf(float(runs.size()), 1.0)
	var status: int = Status.PASS
	if rate < WIN_RATE_FAIL_BELOW:
		status = Status.FAIL
	elif rate < WIN_RATE_PASS:
		status = Status.WARN
	return _row("greedy_wins", "%d/%d victories (%.0f%%)" % [wins, runs.size(), 100.0 * rate], ">= %.0f%% victories" % (100.0 * WIN_RATE_PASS), status)


static func _core_row(runs: Array[HarnessReport]) -> Dictionary:
	var left: PackedFloat64Array = PackedFloat64Array()
	for r: HarnessReport in runs:
		if r.is_victory():
			left.append(100.0 * r.core_fraction())
	var target: String = "%.0f%% to %.0f%% core left" % [100.0 * CORE_MIN, 100.0 * CORE_MAX]
	if left.is_empty():
		return _row("greedy_core", "no victories", target, Status.WARN)
	var avg: float = mean(left)
	var low: float = min_of(left)
	var high: float = max_of(left)
	var status: int = Status.PASS if (avg >= 100.0 * CORE_MIN and avg <= 100.0 * CORE_MAX) else Status.WARN
	return _row("greedy_core", "mean %.0f%% (min %.0f%%, max %.0f%%)" % [avg, low, high], target, status)


static func _duration_row(runs: Array[HarnessReport]) -> Dictionary:
	var secs: PackedFloat64Array = PackedFloat64Array()
	for r: HarnessReport in runs:
		if r.is_victory():
			secs.append(r.seconds())
	var target: String = "%.0f to %.0f s" % [DURATION_MIN_S, DURATION_MAX_S]
	if secs.is_empty():
		return _row("duration", "no victories", target, Status.WARN)
	var avg: float = mean(secs)
	var low: float = min_of(secs)
	var high: float = max_of(secs)
	var status: int = Status.PASS if (avg >= DURATION_MIN_S and avg <= DURATION_MAX_S) else Status.WARN
	return _row("duration", "mean %.0f s (min %.0f, max %.0f)" % [avg, low, high], target, status)


static func _peak_row(runs: Array[HarnessReport], wave_index: int) -> Dictionary:
	var target: int = PEAK_TARGETS[wave_index]
	var peaks: PackedFloat64Array = PackedFloat64Array()
	for r: HarnessReport in runs:
		peaks.append(float(r.peak_alive[wave_index]))
	var med: float = median(peaks)
	var low: float = float(target) * (1.0 - PEAK_TOLERANCE)
	var high: float = float(target) * (1.0 + PEAK_TOLERANCE)
	var status: int = Status.PASS if (med >= low and med <= high) else Status.WARN
	var text: String = "median %.1f" % med
	var band: String = "%d (%.1f to %.1f)" % [target, low, high]
	return _row("peak_wave_%d" % (wave_index + 1), text, band, status)
