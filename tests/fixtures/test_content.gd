class_name TestContent
extends RefCounted
## Frozen content for unit tests (WORK_PLAN rule 5). Never assert on values from res://data/ in a unit test.
##   baseline()  tests/fixtures/data_baseline/: a copy of the handoff data, never tuned. The legacy 5-wave content:
##               4 enemies, 2 weapons, the shop, no run plan. Every test written before the variety milestone uses it.
##   variety()   tests/fixtures/data_variety/: a frozen copy of the variety slice data (VARIETY_SPEC 13.9), refreshed
##               only by an explicit task (V3-I, V5-C). Every test of the variety milestone uses it.

const BASELINE_DIR: String = "res://tests/fixtures/data_baseline"
const VARIETY_DIR: String = "res://tests/fixtures/data_variety"


## A fresh ContentSet from the frozen baseline. Fails loudly (null) if the fixture does not load.
static func baseline() -> ContentSet:
	var r: ContentLoadResult = ContentLoader.load_from_dir(BASELINE_DIR)
	if not r.errors.is_empty():
		push_error("TestContent.baseline failed: " + "; ".join(r.errors))
		return null
	return r.content


## A SimWorld on the baseline content.
static func world(run_seed: int = 1) -> SimWorld:
	return SimWorld.new(SimConfig.create(baseline(), run_seed))


## A fresh ContentSet from the frozen variety fixture. Fails loudly (null) if the fixture does not load.
static func variety() -> ContentSet:
	var r: ContentLoadResult = ContentLoader.load_from_dir(VARIETY_DIR)
	if not r.errors.is_empty():
		push_error("TestContent.variety failed: " + "; ".join(r.errors))
		return null
	return r.content


## A SimWorld on the variety content (base pool, standard kit).
static func variety_world(run_seed: int = 1) -> SimWorld:
	return SimWorld.new(SimConfig.create(variety(), run_seed))
