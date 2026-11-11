class_name Strings
extends RefCounted
## Player-facing text lookup (ARCH 5.4). A missing key returns "#key#" and is logged once.

static var _reported: Dictionary = {}


static func t(key: String) -> String:
	if Content.db != null and Content.db.strings.has(key):
		return Content.db.strings[key]
	_report_once(key, "missing key '%s'" % key)
	return "#%s#" % key


## t(key) formatted with `args` (printf style, as in String % Array). A text whose placeholder count does not match
## `args` is a data bug: it is logged once and the "#key#" marker is returned instead of raising a script error.
static func tf(key: String, args: Array) -> String:
	var text: String = t(key)
	if args.is_empty():
		return text
	var expected: int = _placeholders(text)
	if expected != args.size():
		_report_once(key, "key '%s' has %d placeholders but got %d arguments" % [key, expected, args.size()])
		return "#%s#" % key
	return text % args


## Number of format placeholders in `text`; "%%" is a literal percent sign.
static func _placeholders(text: String) -> int:
	var count: int = 0
	var i: int = 0
	while i < text.length():
		if text[i] == "%":
			if i + 1 < text.length() and text[i + 1] == "%":
				i += 1
			else:
				count += 1
		i += 1
	return count


static func _report_once(key: String, message: String) -> void:
	var id: String = key + "|" + message
	if not _reported.has(id):
		_reported[id] = true
		Log.warn("Strings", message)
