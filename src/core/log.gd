extends Node
## `Log` autoload (ARCH 7.6). Format `[tag] message`; `error` prints with the `ERROR:` prefix so the
## test runner and the smoke test see it.


func info(tag: String, msg: String) -> void:
	print("[%s] %s" % [tag, msg])


func warn(tag: String, msg: String) -> void:
	print("[%s] WARN: %s" % [tag, msg])


func error(tag: String, msg: String) -> void:
	print("ERROR: %s: %s" % [tag, msg])
