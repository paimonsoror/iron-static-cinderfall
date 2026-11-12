class_name WorldSnapshot
extends RefCounted
## The boundary snapshot of resume (VARIETY_SPEC 2.8 option D, 13.3 `boundary.state`): the state of a world as a
## JSON-safe Dictionary, and its way back. `SimWorld.state_hash()` after `restore` equals the hash before `capture`.
##
## The capture is complete: every hashed field of the world (the scalars, the frozen stores, PhaseState, CombatState,
## the hashed part of NavState, the RNG stream states, the variety state classes and the plan), plus what a run needs
## that is not hashed (RunStats and the event counters, so the summary and the event hash of a resumed run equal those
## of an uninterrupted one). The game takes it at a wave clear, when the stores are almost empty, but nothing here
## depends on that. The static parts of NavState (flow field, zones, per-type tables) are rebuilt by `SimWorld._init`
## and are not saved; the command queue, the command log and the undrained event buffer are not part of it (the run
## file keeps the log next to the snapshot).
##
## 64-bit integers (RNG states, the event hash) are saved as decimal strings: JSON numbers are doubles. Floats need a
## full-precision JSON writer (`JSON.stringify(doc, "", true, true)`), which the run file uses.

const VERSION: int = 2  ## 1 was the V1-S stub (variety states only)

## The hashed, per-run fields of NavState (the rest is static or per-tick scratch).
const NAV_FIELDS: PackedStringArray = [
	"wave_begun", "sched_due", "sched_type", "sched_group", "sched_ordinal", "sched_x", "sched_z", "sched_next",
	"pending", "pending_head", "track_id", "stuck_ref", "stuck_timer", "sep_off", "grace", "recoveries", "c_ttl",
	"c_vx", "c_vz",
]
const SLOT_FIELDS: PackedStringArray = ["_occ"]
const WORLD_FIELDS: PackedStringArray = [
	"tick", "phase", "wave", "waves_completed", "phase_ticks_left", "core_hp", "core_max_hp", "shield_hp", "scrap",
	"upgrade_levels", "next_enemy_id",
]
## Sections that hold a plain field dump of one object (the key is the property of SimWorld).
const DUMPED: PackedStringArray = ["enemies", "turrets", "warden", "abilities", "combat", "stats"]
## Sections of the variety state classes, which bring their own to_dict and from_dict.
const VARIETY: PackedStringArray = ["mods", "arsenal", "draft", "salvage", "ext", "hazards", "events_state", "boss"]
const DICT_SECTIONS: PackedStringArray = ["world", "nav", "slots", "phase_state", "events", "plan"]
const SUPPORTED: Array[int] = [
	TYPE_INT, TYPE_BOOL, TYPE_FLOAT, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_BYTE_ARRAY,
]


static func capture(world: SimWorld) -> Dictionary:
	var doc: Dictionary = {"version": VERSION}
	doc["world"] = SnapUtil.to_dict(world, WORLD_FIELDS)
	for key: String in DUMPED:
		var part: Object = world.get(key)
		doc[key] = SnapUtil.to_dict(part, fields_of(part))
	doc["nav"] = SnapUtil.to_dict(world.nav, NAV_FIELDS)
	doc["slots"] = SnapUtil.to_dict(world.nav.slots, SLOT_FIELDS) if world.nav.slots != null else {}
	var phase_doc: Dictionary = SnapUtil.to_dict(world.phase_state, fields_of(world.phase_state))
	phase_doc["seen_command_ids"] = world.phase_state.seen_command_ids.keys()
	doc["phase_state"] = phase_doc
	doc["rng"] = _rng_rows(world.rng)
	doc["events"] = {
		"hash": str(world.events.event_hash), "total": world.events.total, "tick": world.events.current_tick,
	}
	doc["plan"] = world.plan.to_dict() if world.plan != null else {}
	for key: String in VARIETY:
		var state: Object = world.get(key)
		var part_doc: Variant = state.call("to_dict")
		doc[key] = part_doc
	return doc


## Applies `doc` to a fresh world built from the same SimConfig. True when every section was there and was applied;
## the caller still compares `state_hash()` with the hash saved next to the snapshot (a damaged number passes here).
## On false the world may be half written and must be thrown away.
static func restore(world: SimWorld, doc: Dictionary) -> bool:
	if roundi(SnapUtil.num(doc.get("version", 0))) != VERSION:
		return false
	for key: String in DICT_SECTIONS + DUMPED + VARIETY:
		if typeof(doc.get(key)) != TYPE_DICTIONARY:
			return false
	if typeof(doc.get("rng")) != TYPE_ARRAY:
		return false
	var world_doc: Dictionary = doc["world"]
	SnapUtil.from_dict(world, WORLD_FIELDS, world_doc)
	for key: String in DUMPED:
		var part: Object = world.get(key)
		var part_doc: Dictionary = doc[key]
		SnapUtil.from_dict(part, fields_of(part), part_doc)
	var nav_doc: Dictionary = doc["nav"]
	SnapUtil.from_dict(world.nav, NAV_FIELDS, nav_doc)
	var slot_doc: Dictionary = doc["slots"]
	if world.nav.slots != null:
		SnapUtil.from_dict(world.nav.slots, SLOT_FIELDS, slot_doc)
	var phase_doc: Dictionary = doc["phase_state"]
	SnapUtil.from_dict(world.phase_state, fields_of(world.phase_state), phase_doc)
	world.phase_state.seen_command_ids.clear()
	for command_id: int in SnapUtil.ints(phase_doc.get("seen_command_ids", [])):
		world.phase_state.seen_command_ids[command_id] = true
	var rng_rows: Array = doc["rng"]
	if not _restore_rng(world, rng_rows):
		return false
	var events_doc: Dictionary = doc["events"]
	world.events.event_hash = _int64(events_doc.get("hash", "0"))
	world.events.total = roundi(SnapUtil.num(events_doc.get("total", 0)))
	world.events.current_tick = roundi(SnapUtil.num(events_doc.get("tick", 0)))
	var plan_doc: Dictionary = doc["plan"]
	world.plan = null if plan_doc.is_empty() else RunPlan.from_dict(plan_doc)
	for key: String in VARIETY:
		var state: Object = world.get(key)
		var part_doc: Dictionary = doc[key]
		state.call("from_dict", part_doc)
	world.command_queue.clear()
	return true


## The script variables of `o` that SnapUtil can save (numbers, flags and packed arrays), in declaration order. Used
## for the classes whose every such variable is per-run state (the frozen stores, CombatState, PhaseState, RunStats),
## so a field added to one of them later is captured without a change here.
static func fields_of(o: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in o.get_property_list():
		var usage: int = p["usage"]
		var type: int = p["type"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and SUPPORTED.has(type):
			var field: String = p["name"]
			out.append(field)
	return out


## One row per stream, sorted by name: [name, state as a decimal string].
static func _rng_rows(rng: SimRng) -> Array:
	var names: Array = rng._streams.keys()
	names.sort()
	var rows: Array = []
	for n: StringName in names:
		rows.append([String(n), str(rng._streams[n].state)])
	return rows


## A fresh SimRng with exactly the saved streams (a stream is seeded from its name, then gets its saved state).
static func _restore_rng(world: SimWorld, rows: Array) -> bool:
	var rng: SimRng = SimRng.new(world.config.run_seed)
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_ARRAY:
			return false
		var row: Array = row_v
		if row.size() != 2 or typeof(row[0]) != TYPE_STRING:
			return false
		var stream_name: String = row[0]
		rng.stream(StringName(stream_name)).state = _int64(row[1])
	world.rng = rng
	return true


static func _int64(v: Variant) -> int:
	if typeof(v) == TYPE_STRING:
		var s: String = v
		return s.to_int() if s.is_valid_int() else 0
	return roundi(SnapUtil.num(v))
