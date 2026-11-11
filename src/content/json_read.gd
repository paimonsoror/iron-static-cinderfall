class_name JsonRead
extends RefCounted
## Typed, error-collecting access to parsed JSON. Every failure becomes one message of the form
## "<file>: <json path>: <problem>" and a neutral default, so a loader can report all problems at once.

var file: String
var errors: PackedStringArray = PackedStringArray()


func _init(file_name: String) -> void:
	file = file_name


func fail(path: String, problem: String) -> void:
	errors.append("%s: %s: %s" % [file, path, problem])


func dict(d: Dictionary, key: String, path: String) -> Dictionary:
	var v: Variant = d.get(key)
	if typeof(v) != TYPE_DICTIONARY:
		fail(path + "." + key, "missing or not an object")
		return {}
	var out: Dictionary = v
	return out


func list(d: Dictionary, key: String, path: String) -> Array:
	var v: Variant = d.get(key)
	if typeof(v) != TYPE_ARRAY:
		fail(path + "." + key, "missing or not an array")
		return []
	var out: Array = v
	return out


func text(d: Dictionary, key: String, path: String) -> String:
	var v: Variant = d.get(key)
	if typeof(v) != TYPE_STRING and typeof(v) != TYPE_STRING_NAME:
		fail(path + "." + key, "missing or not a string")
		return ""
	return str(v)


func flag(d: Dictionary, key: String, path: String) -> bool:
	var v: Variant = d.get(key)
	if typeof(v) != TYPE_BOOL:
		fail(path + "." + key, "missing or not a boolean")
		return false
	var b: bool = v
	return b


## A finite number. JSON numbers arrive as float.
func num(d: Dictionary, key: String, path: String) -> float:
	var v: Variant = d.get(key)
	return as_num(v, path + "." + key)


func as_num(v: Variant, path: String) -> float:
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f):
			return f
		fail(path, "not a finite number")
		return 0.0
	if typeof(v) == TYPE_INT:
		var i: int = v
		return float(i)
	fail(path, "missing or not a number")
	return 0.0


## A number with no fractional part.
func integer(d: Dictionary, key: String, path: String) -> int:
	var f: float = num(d, key, path)
	if absf(f - roundf(f)) > 0.0000001:
		fail(path + "." + key, "expected a whole number, got %s" % f)
	return roundi(f)


func num_or(d: Dictionary, key: String, path: String, fallback: float) -> float:
	if not d.has(key):
		return fallback
	return num(d, key, path)


func text_or(d: Dictionary, key: String, path: String, fallback: String) -> String:
	if not d.has(key):
		return fallback
	return text(d, key, path)


## Reports every key of `d` that is not in `known`.
func check_keys(d: Dictionary, known: PackedStringArray, path: String) -> void:
	for k: Variant in d.keys():
		var ks: String = str(k)
		if not known.has(ks):
			fail(path + "." + ks, "unknown key")
