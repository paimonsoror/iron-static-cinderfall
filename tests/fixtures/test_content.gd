class_name TestContent
extends RefCounted
## Frozen content for unit tests (WORK_PLAN rule 5). Reads tests/fixtures/data_baseline/, which is a copy of the
## handoff data and is never tuned. Never assert on values from res://data/ in a unit test.

const BASELINE_DIR: String = "res://tests/fixtures/data_baseline"


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
