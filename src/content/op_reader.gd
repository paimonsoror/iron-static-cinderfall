class_name OpReader
extends RefCounted
## JSON helpers shared by the variety loaders: the `ops[]` grammar (OpDef), optional typed fields, number dictionaries,
## point lists and name-to-enum lookups. Every problem goes to the JsonRead as "<file>: <json path>: <problem>".


## The `ops[]` list under `key` (required, may be empty). Names are checked by ContentValidator, shapes here.
static func ops(r: JsonRead, d: Dictionary, key: String, path: String) -> Array[OpDef]:
	var out: Array[OpDef] = []
	var items: Array = r.list(d, key, path)
	for i: int in items.size():
		var p: String = "%s.%s[%d]" % [path, key, i]
		if typeof(items[i]) != TYPE_DICTIONARY:
			r.fail(p, "not an object")
			continue
		var od: Dictionary = items[i]
		var op: OpDef = OpDef.new()
		if od.has("stat"):
			r.check_keys(od, PackedStringArray(["stat", "add", "mul"]), p)
			op.target = StringName(r.text(od, "stat", p))
			if od.has("add") == od.has("mul"):
				r.fail(p, "a stat op needs exactly one of add or mul")
			elif od.has("add"):
				op.kind = OpDef.Kind.ADD
				op.value = r.num(od, "add", p)
			else:
				op.kind = OpDef.Kind.MUL
				op.value = r.num(od, "mul", p)
		elif od.has("flag"):
			r.check_keys(od, PackedStringArray(["flag"]), p)
			op.kind = OpDef.Kind.FLAG
			op.target = StringName(r.text(od, "flag", p))
			op.value = 1.0
		elif od.has("grant"):
			r.check_keys(od, PackedStringArray(["grant", "n", "id", "per_act"]), p)
			op.kind = OpDef.Kind.GRANT
			op.target = StringName(r.text(od, "grant", p))
			op.value = r.num(od, "n", p)
			op.per_act = r.num_or(od, "per_act", p, 0.0)
			op.arg = StringName(r.text_or(od, "id", p, ""))
		else:
			r.fail(p, "an op needs one of stat, flag or grant")
		out.append(op)
	return out


## The objects of the array under `key`; a row that is not an object is reported and skipped.
static func rows(r: JsonRead, d: Dictionary, key: String, path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = r.list(d, key, path)
	for i: int in list.size():
		if typeof(list[i]) != TYPE_DICTIONARY:
			r.fail("%s.%s[%d]" % [path, key, i], "not an object")
			continue
		var row: Dictionary = list[i]
		out.append(row)
	return out


static func int_or(r: JsonRead, d: Dictionary, key: String, path: String, fallback: int) -> int:
	if not d.has(key):
		return fallback
	return r.integer(d, key, path)


static func flag_or(r: JsonRead, d: Dictionary, key: String, path: String, fallback: bool) -> bool:
	if not d.has(key):
		return fallback
	return r.flag(d, key, path)


static func ticks(seconds: float) -> int:
	return roundi(seconds * float(ContentLoader.TICK_RATE))


## Index of the text under `key` in `names`; reports an unknown name and returns 0.
static func enum_index(r: JsonRead, d: Dictionary, key: String, path: String, allowed: PackedStringArray) -> int:
	var before: int = r.errors.size()
	var text: String = r.text(d, key, path)
	if r.errors.size() > before:
		return 0
	var i: int = allowed.find(text)
	if i < 0:
		r.fail(path + "." + key, "unknown value '%s' (expected one of: %s)" % [text, ", ".join(allowed)])
		return 0
	return i


## Ids.ENEMIES index of the enemy id under `key`; reports an unknown id and returns -1.
static func enemy(r: JsonRead, d: Dictionary, key: String, path: String) -> int:
	var before: int = r.errors.size()
	var text: String = r.text(d, key, path)
	if r.errors.size() > before:
		return -1
	var i: int = Ids.enemy_index(StringName(text))
	if i < 0:
		r.fail(path + "." + key, "unknown enemy id '%s'" % text)
	return i


## Exactly `count` numbers under `key` (any length when count < 0).
static func floats(r: JsonRead, d: Dictionary, key: String, path: String, count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var list: Array = r.list(d, key, path)
	if count >= 0 and list.size() != count and d.has(key):
		r.fail(path + "." + key, "expected %d numbers, got %d" % [count, list.size()])
	for i: int in list.size():
		out.append(r.as_num(list[i], "%s.%s[%d]" % [path, key, i]))
	return out


static func ints(r: JsonRead, d: Dictionary, key: String, path: String, count: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for f: float in floats(r, d, key, path, count):
		out.append(roundi(f))
	return out


static func names(r: JsonRead, d: Dictionary, key: String, path: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var list: Array = r.list(d, key, path)
	for i: int in list.size():
		if typeof(list[i]) != TYPE_STRING:
			r.fail("%s.%s[%d]" % [path, key, i], "not a string")
			continue
		out.append(StringName(str(list[i])))
	return out


## An optional object of numbers: a number stays, true/false become 1/0, an enemy id becomes its index.
static func num_dict(r: JsonRead, d: Dictionary, key: String, path: String) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	if not d.has(key):
		return out
	var src: Dictionary = r.dict(d, key, path)
	for k: Variant in src.keys():
		var ks: String = str(k)
		var v: Variant = src[k]
		var p: String = "%s.%s.%s" % [path, key, ks]
		match typeof(v):
			TYPE_BOOL:
				var b: bool = v
				out[StringName(ks)] = 1.0 if b else 0.0
			TYPE_STRING:
				var idx: int = Ids.enemy_index(StringName(str(v)))
				if idx < 0:
					r.fail(p, "unknown enemy id '%s'" % str(v))
				out[StringName(ks)] = float(idx)
			_:
				out[StringName(ks)] = r.as_num(v, p)
	return out


## An array of { "x": n, "z": n } objects (optional: missing = empty).
static func points(r: JsonRead, d: Dictionary, key: String, path: String) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if not d.has(key):
		return out
	var list: Array[Dictionary] = rows(r, d, key, path)
	for i: int in list.size():
		var p: String = "%s.%s[%d]" % [path, key, i]
		out.append(Vector2(r.num(list[i], "x", p), r.num(list[i], "z", p)))
	return out
