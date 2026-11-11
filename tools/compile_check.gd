extends SceneTree
## Compile gate used by tools/compile_gate.py: loads every script and scene passed after `--` so that parse
## errors and warnings-as-errors are reported (autoloads are registered in this mode, unlike --check-only).
## Usage: godot --headless --path . -s res://tools/compile_check.gd -- res://a.gd res://b.tscn


func _initialize() -> void:
	# Autoloads are added to the tree after _init, so compile on the first frame.
	process_frame.connect(_compile_all, CONNECT_ONE_SHOT)


func _compile_all() -> void:
	var failed: int = 0
	var checked: int = 0
	for path: String in OS.get_cmdline_user_args():
		checked += 1
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if res == null:
			failed += 1
			print("COMPILE FAIL: ", path)
	print("COMPILE SUMMARY: checked=", checked, " failed=", failed)
	quit(1 if failed > 0 else 0)
