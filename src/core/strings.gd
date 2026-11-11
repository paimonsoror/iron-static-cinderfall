class_name Strings
extends RefCounted
## Player-facing text lookup (ARCH 5.4). A missing key returns "#key#" and is logged once.

static var _missing: Dictionary = {}


static func t(key: String) -> String:
	if Content.db != null and Content.db.strings.has(key):
		return Content.db.strings[key]
	if not _missing.has(key):
		_missing[key] = true
		Log.warn("Strings", "missing key '%s'" % key)
	return "#%s#" % key


## t(key) formatted with `args` (printf style, as in String % Array).
static func tf(key: String, args: Array) -> String:
	var text: String = t(key)
	if args.is_empty():
		return text
	return text % args
