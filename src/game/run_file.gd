class_name RunFile
extends RefCounted
## The document of `user://run_v1.json` (ARCH 7.5, VARIETY_SPEC 2.8 and 13.3): how it is built from a live run, how it
## is judged at launch and how a SimConfig comes back out of it. Pure helpers; `Save.save_run` does the disk work.
##
##   { "schema_version": 1, "build": "0.1.0", "content_hash": "<12 chars>", "run_id": "<unix>-<seed>", "seed": 48211,
##     "kit": "k_standard", "unlocked": ["u_w_lmg"], "daily": false,
##     "boundary": { "wave": 2, "tick": 4810, "state_hash": "<sha256>", "state": { WorldSnapshot.capture } },
##     "log": [ commands applied up to boundary.tick ], "tail": [ commands applied after it ], "resume_tick": 5120 }
##
## Additions to the schema of the spec, both optional for a reader:
##  - `log`: the commands before the boundary. The fallback of 2.8 (a full replay from tick 0) needs the whole log, and
##    the tail alone starts at the boundary.
##  - `debug`: the debug switches of the SimConfig when one is set (--scenario, tests), so such a run resumes too.
## `boundary.wave` is the number of waves cleared at the boundary (0 = the snapshot of the start of the run).
## `resume_tick` is there only when the file was written by a pause; without it the run resumes after the last
## command of the tail.

const SCHEMA_VERSION: int = 1

enum Verdict {
	NONE,  ## no run file
	RESUMABLE,  ## this build and this content wrote it
	STALE,  ## another build, other content or a damaged document: the run is closed and paid as a defeat
}


static func build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version"))


## Everything of the document that does not change during the run.
static func header(config: SimConfig, run_id: String) -> Dictionary:
	var content: ContentSet = config.content
	var kit_id: String = Profile.DEFAULT_KIT
	if config.kit_index >= 0 and config.kit_index < content.kits.size():
		kit_id = String(content.kits[config.kit_index].id)
	var doc: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"build": build_version(),
		"content_hash": ContentFingerprint.of(content),
		"run_id": run_id,
		"seed": config.run_seed,
		"kit": kit_id,
		"unlocked": Array(config.unlocked),
		"daily": config.daily,
	}
	if config.debug_invulnerable_core or config.debug_damage_mult != 1.0 or config.debug_start_scrap != 0:
		doc["debug"] = {
			"invulnerable": config.debug_invulnerable_core, "damage_mult": config.debug_damage_mult,
			"start_scrap": config.debug_start_scrap,
		}
	return doc


## The snapshot of `world` as the `boundary` object.
static func boundary(world: SimWorld) -> Dictionary:
	return {
		"wave": world.waves_completed, "tick": world.tick, "state_hash": world.state_hash(),
		"state": WorldSnapshot.capture(world),
	}


## The whole document. `rows` is the command log so far (CommandLog.to_dicts); it is split at the boundary tick.
## `resume_tick` < 0 leaves the key out.
static func compose(head: Dictionary, boundary_doc: Dictionary, rows: Array[Dictionary], resume_tick: int) -> Dictionary:
	var doc: Dictionary = head.duplicate()
	var at: int = whole(boundary_doc.get("tick"), 0)
	var before: Array = []
	var after: Array = []
	for row: Dictionary in rows:
		if whole(row.get("tick"), 0) <= at:
			before.append(row)
		else:
			after.append(row)
	doc["boundary"] = boundary_doc
	doc["log"] = before
	doc["tail"] = after
	if resume_tick >= 0:
		doc["resume_tick"] = maxi(resume_tick, at)
	return doc


## What to do with the run file found at launch.
static func check(doc: Dictionary, content: ContentSet) -> int:
	if doc.is_empty():
		return Verdict.NONE
	if whole(doc.get("schema_version"), -1) != SCHEMA_VERSION or text(doc.get("build")) != build_version():
		return Verdict.STALE
	if text(doc.get("content_hash")) != ContentFingerprint.of(content):
		return Verdict.STALE
	var b: Variant = doc.get("boundary")
	if typeof(b) != TYPE_DICTIONARY or whole(doc.get("seed"), -1) < 0 or id_of(doc).is_empty():
		return Verdict.STALE
	var boundary_doc: Dictionary = b
	if typeof(boundary_doc.get("state")) != TYPE_DICTIONARY or text(boundary_doc.get("state_hash")).is_empty():
		return Verdict.STALE
	return Verdict.RESUMABLE


## The SimConfig the run was started with. An unknown kit id is the standard kit.
static func config_from(doc: Dictionary, content: ContentSet) -> SimConfig:
	var config: SimConfig = SimConfig.create(content, whole(doc.get("seed"), 0))
	config.kit_index = maxi(0, content.kit_index(StringName(text(doc.get("kit")))))
	var unlocked: PackedStringArray = PackedStringArray()
	var list: Variant = doc.get("unlocked")
	if typeof(list) == TYPE_ARRAY:
		var rows: Array = list
		for item: Variant in rows:
			if typeof(item) == TYPE_STRING:
				var unlock_id: String = item
				unlocked.append(unlock_id)
	unlocked.sort()
	config.unlocked = unlocked
	var daily: Variant = doc.get("daily")
	config.daily = typeof(daily) == TYPE_BOOL and daily == true
	var debug: Variant = doc.get("debug")
	if typeof(debug) == TYPE_DICTIONARY:
		var d: Dictionary = debug
		var invulnerable: Variant = d.get("invulnerable")
		config.debug_invulnerable_core = typeof(invulnerable) == TYPE_BOOL and invulnerable == true
		config.debug_damage_mult = SnapUtil.num(d.get("damage_mult", 1.0))
		config.debug_start_scrap = whole(d.get("start_scrap"), 0)
	return config


static func id_of(doc: Dictionary) -> String:
	var id: String = text(doc.get("run_id"))
	return id if id.length() <= Profile.MAX_ID_LENGTH else ""


## The `boundary` object, or {} when the document has none.
static func boundary_of(doc: Dictionary) -> Dictionary:
	var b: Variant = doc.get("boundary")
	if typeof(b) != TYPE_DICTIONARY:
		return {}
	var boundary_doc: Dictionary = b
	return boundary_doc


## The rows of `log` or `tail` as a CommandLog (empty when the key is missing).
static func commands(doc: Dictionary, key: String) -> CommandLog:
	var rows: Variant = doc.get(key)
	if typeof(rows) != TYPE_ARRAY:
		return CommandLog.new()
	var list: Array = rows
	return CommandLog.from_dicts(list)


## Waves cleared at the boundary (0 when the document has none).
static func waves_cleared(doc: Dictionary) -> int:
	return maxi(0, whole(boundary_of(doc).get("wave"), 0))


## The wave the menu names in RESUME RUN (WAVE n): the one after the last cleared wave.
static func resume_wave(doc: Dictionary) -> int:
	return waves_cleared(doc) + 1


## The tick a resume stops at: `resume_tick`, or the last command of the tail, never before the boundary.
static func target_tick(doc: Dictionary) -> int:
	var at: int = maxi(0, whole(boundary_of(doc).get("tick"), 0))
	if doc.has("resume_tick"):
		return maxi(at, whole(doc.get("resume_tick"), at))
	var tail: Variant = doc.get("tail")
	if typeof(tail) == TYPE_ARRAY:
		var rows: Array = tail
		for row_v: Variant in rows:
			if typeof(row_v) == TYPE_DICTIONARY:
				var row: Dictionary = row_v
				at = maxi(at, whole(row.get("tick"), 0))
	return at


## The Recovered Data of a run that cannot be resumed: a defeat at the last saved wave (VARIETY_SPEC 2.8).
static func closing_reward(doc: Dictionary, content: ContentSet) -> int:
	var wave_count: int = content.run.waves.size() if content.run != null else content.waves.size()
	var waves: int = mini(waves_cleared(doc), maxi(content.waves.size(), wave_count))
	return Formulas.data_reward(RunResult.Id.DEFEAT, waves, 0.0, content.mission)


## A whole number from a JSON value (numbers arrive as float), else `fallback`.
static func whole(v: Variant, fallback: int) -> int:
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f) and f == floorf(f):
			return int(f)
	return fallback


static func text(v: Variant) -> String:
	if typeof(v) == TYPE_STRING:
		var s: String = v
		return s
	return ""
