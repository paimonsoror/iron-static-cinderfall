class_name ScorecardStats
extends RefCounted
## The small statistics of the scorecard: mean, standard deviation, median, rates, Jaccard similarity. Plain functions of
## numbers; an empty list gives 0, so a caller that needs "no data" checks the size first.


static func mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


## Population standard deviation (the runs are the whole population of the card, not a sample of a larger one).
static func stdev(values: PackedFloat64Array) -> float:
	if values.size() < 2:
		return 0.0
	var m: float = mean(values)
	var total: float = 0.0
	for v: float in values:
		total += (v - m) * (v - m)
	return sqrt(total / float(values.size()))


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


## `part / whole`, 0 when `whole` is 0.
static func rate(part: int, whole: int) -> float:
	return float(part) / float(whole) if whole > 0 else 0.0


## |A and B| / |A or B| of two sets given as lists of names (duplicates count once). Two empty sets are identical (1.0).
static func jaccard(a: PackedStringArray, b: PackedStringArray) -> float:
	var in_a: Dictionary[String, bool] = {}
	for s: String in a:
		in_a[s] = true
	var in_b: Dictionary[String, bool] = {}
	for s: String in b:
		in_b[s] = true
	var both: int = 0
	for s: String in in_a:
		if in_b.has(s):
			both += 1
	var either: int = in_a.size() + in_b.size() - both
	return 1.0 if either == 0 else float(both) / float(either)


## The Jaccard similarity of every pair of the sets, in pair order (i < j).
static func pairwise_jaccard(sets: Array[PackedStringArray]) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for i: int in sets.size():
		for j: int in range(i + 1, sets.size()):
			out.append(jaccard(sets[i], sets[j]))
	return out


## Counts of each distinct string, keys in first-seen order.
static func tally(names: PackedStringArray) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	for s: String in names:
		var before: int = out.get(s, 0)
		out[s] = before + 1
	return out


static func percent(fraction: float) -> String:
	return "%.0f%%" % (100.0 * fraction)
