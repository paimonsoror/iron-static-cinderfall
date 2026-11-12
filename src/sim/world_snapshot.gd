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
## Numbers that a JSON writer would not give back bit for bit travel as text (the engine's writer rounds the last digit
## of some doubles and drops the sign of -0.0, either of which would change the state hash):
##  - 64-bit integers (RNG states, the event hash): decimal strings;
##  - a float that is not a small whole number: "~" plus the 16 hex digits of its IEEE bits;
##  - the packed arrays of the frozen classes: one string per array, "f:", "i:" or "b:" plus the hex of its bytes
##    (also what keeps a capture cheap: no per-element work in script for the large stores).
## The variety state classes come through their own `to_dict` (SnapUtil: plain arrays); their floats are sealed one
## by one afterwards.

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
## Sections that hold a field dump of one object (the key is the property of SimWorld).
const DUMPED: PackedStringArray = ["enemies", "turrets", "warden", "abilities", "combat", "stats"]
## Sections of the variety state classes, which bring their own to_dict and from_dict.
const VARIETY: PackedStringArray = ["mods", "arsenal", "draft", "salvage", "ext", "hazards", "events_state", "boss"]
const DICT_SECTIONS: PackedStringArray = ["world", "nav", "slots", "phase_state", "events", "plan"]
const FLOAT_MARK: String = "~"
const PACK_FLOATS: String = "f:"
const PACK_INTS: String = "i:"
const PACK_BYTES: String = "b:"
const WHOLE_LIMIT: float = 9007199254740992.0  ## 2^53: whole floats below it survive JSON as they are
const SUPPORTED: Array[int] = [
	TYPE_INT, TYPE_BOOL, TYPE_FLOAT, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_BYTE_ARRAY,
]


static func capture(world: SimWorld) -> Dictionary:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(8)
	var doc: Dictionary = {"version": VERSION}
	doc["world"] = _dump(world, WORLD_FIELDS, buf)
	for key: String in DUMPED:
		var part: Object = world.get(key)
		doc[key] = _dump(part, fields_of(part), buf)
	doc["nav"] = _dump(world.nav, NAV_FIELDS, buf)
	doc["slots"] = _dump(world.nav.slots, SLOT_FIELDS, buf) if world.nav.slots != null else {}
	var phase_doc: Dictionary = _dump(world.phase_state, fields_of(world.phase_state), buf)
	phase_doc["seen_command_ids"] = world.phase_state.seen_command_ids.keys()
	doc["phase_state"] = phase_doc
	doc["rng"] = _rng_rows(world.rng)
	doc["events"] = {
		"hash": str(world.events.event_hash), "total": world.events.total, "tick": world.events.current_tick,
	}
	doc["plan"] = _seal(world.plan.to_dict(), buf) if world.plan != null else {}
	for key: String in VARIETY:
		var state: Object = world.get(key)
		doc[key] = _seal(state.call("to_dict"), buf)
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
	_load(world, WORLD_FIELDS, world_doc)
	for key: String in DUMPED:
		var part: Object = world.get(key)
		var part_doc: Dictionary = doc[key]
		_load(part, fields_of(part), part_doc)
	var nav_doc: Dictionary = doc["nav"]
	_load(world.nav, NAV_FIELDS, nav_doc)
	var slot_doc: Dictionary = doc["slots"]
	if world.nav.slots != null:
		_load(world.nav.slots, SLOT_FIELDS, slot_doc)
	var phase_doc: Dictionary = doc["phase_state"]
	_load(world.phase_state, fields_of(world.phase_state), phase_doc)
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
	var plan_doc: Dictionary = _open(doc["plan"])
	world.plan = null if plan_doc.is_empty() else RunPlan.from_dict(plan_doc)
	for key: String in VARIETY:
		var state: Object = world.get(key)
		var part_doc: Dictionary = _open(doc[key])
		state.call("from_dict", part_doc)
	world.command_queue.clear()
	return true


## The script variables of `o` that can be saved (numbers, flags and packed arrays), in declaration order. Used for the
## classes whose every such variable is per-run state (the frozen stores, CombatState, PhaseState, RunStats), so a
## field added to one of them later is captured without a change here.
static func fields_of(o: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in o.get_property_list():
		var usage: int = p["usage"]
		var type: int = p["type"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and SUPPORTED.has(type):
			var field: String = p["name"]
			out.append(field)
	return out


## `fields` of `o` as JSON-safe values that come back bit for bit (see the header).
static func _dump(o: Object, fields: PackedStringArray, buf: PackedByteArray) -> Dictionary:
	var out: Dictionary = {}
	for f: String in fields:
		var v: Variant = o.get(f)
		match typeof(v):
			TYPE_FLOAT:
				out[f] = _seal(v, buf)
			TYPE_PACKED_FLOAT64_ARRAY:
				var fa: PackedFloat64Array = v
				out[f] = PACK_FLOATS + fa.to_byte_array().hex_encode()
			TYPE_PACKED_INT32_ARRAY:
				var ia: PackedInt32Array = v
				out[f] = PACK_INTS + ia.to_byte_array().hex_encode()
			TYPE_PACKED_BYTE_ARRAY:
				var ba: PackedByteArray = v
				out[f] = PACK_BYTES + ba.hex_encode()
			_:
				out[f] = v
	return out


## Sets every field of `fields` that `d` holds (the reverse of `_dump`); a missing key keeps the current value.
static func _load(o: Object, fields: PackedStringArray, d: Dictionary) -> void:
	for f: String in fields:
		if not d.has(f):
			continue
		var src: Variant = d[f]
		match typeof(o.get(f)):
			TYPE_INT:
				o.set(f, roundi(SnapUtil.num(src)))
			TYPE_BOOL:
				o.set(f, typeof(src) == TYPE_BOOL and src == true)
			TYPE_FLOAT:
				o.set(f, SnapUtil.num(_open(src)))
			TYPE_PACKED_FLOAT64_ARRAY:
				o.set(f, _packed(src, PACK_FLOATS).to_float64_array())
			TYPE_PACKED_INT32_ARRAY:
				o.set(f, _packed(src, PACK_INTS).to_int32_array())
			TYPE_PACKED_BYTE_ARRAY:
				o.set(f, _packed(src, PACK_BYTES))


## The bytes of a packed array saved by `_dump`; empty for anything else.
static func _packed(v: Variant, mark: String) -> PackedByteArray:
	if typeof(v) != TYPE_STRING:
		return PackedByteArray()
	var s: String = v
	if not s.begins_with(mark):
		return PackedByteArray()
	return s.substr(mark.length()).hex_decode()


## A copy of `v` in which every float that JSON could damage is text (see the header). Whole floats stay numbers. An
## array that starts with an integer is taken to hold integers only (true of everything `to_dict` gives) and is not
## walked.
static func _seal(v: Variant, buf: PackedByteArray) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			buf.encode_double(0, f)
			if f == floorf(f) and absf(f) < WHOLE_LIMIT and (f != 0.0 or buf.decode_s64(0) == 0):
				return f
			return FLOAT_MARK + buf.hex_encode()
		TYPE_ARRAY:
			var list: Array = v
			if list.is_empty() or typeof(list[0]) == TYPE_INT:
				return list
			var out: Array = []
			out.resize(list.size())
			for i: int in list.size():
				out[i] = _seal(list[i], buf)
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var copy: Dictionary = {}
			for key: Variant in d:
				copy[key] = _seal(d[key], buf)
			return copy
	return v


## The reverse of `_seal`.
static func _open(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			var s: String = v
			if s.length() == 17 and s.begins_with(FLOAT_MARK) and s.substr(1).is_valid_hex_number():
				return s.substr(1).hex_decode().decode_double(0)
			return s
		TYPE_ARRAY:
			var list: Array = v
			var out: Array = []
			out.resize(list.size())
			for i: int in list.size():
				out[i] = _open(list[i])
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var copy: Dictionary = {}
			for key: Variant in d:
				copy[key] = _open(d[key])
			return copy
	return v


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
