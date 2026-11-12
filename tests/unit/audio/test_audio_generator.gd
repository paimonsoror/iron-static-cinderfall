extends GdUnitTestSuite
## The generator script: deterministic (two runs identical) and in sync with the committed files.

const SCRIPT: String = "res://tools/audio_gen/gen.py"


## Runs `gen.py <args>` with Python 3.12 in isolated mode (`py -3.12 -I`; `python3.12 -I` where there is no launcher).
## Returns {code, last_line, output}; code -1 means no interpreter could be started.
func _run_generator(args: Array[String]) -> Dictionary:
	var script: String = ProjectSettings.globalize_path(SCRIPT)
	var launchers: Array = [["py", "-3.12", "-I"], ["python3.12", "-I"], ["python3", "-I"], ["python", "-I"]]
	for launcher: Array in launchers:
		var parts: Array[String] = []
		for item: Variant in launcher:
			parts.append(str(item))
		var exe: String = parts.pop_front()
		parts.append(script)
		parts.append_array(args)
		var output: Array = []
		var code: int = OS.execute(exe, PackedStringArray(parts), output, true)
		if code == -1:
			continue
		var text: String = ""
		for chunk: Variant in output:
			text += str(chunk)
		text = text.strip_edges()
		var lines: PackedStringArray = text.split("\n")
		return {"code": code, "last_line": lines[lines.size() - 1].strip_edges(), "output": text}
	return {"code": -1, "last_line": "", "output": "no Python interpreter could be started"}


func test_two_generator_runs_are_byte_identical_and_match_the_committed_files() -> void:
	var result: Dictionary = _run_generator(["--check"])
	var code: int = result["code"]
	var output: String = result["output"]
	var last_line: String = result["last_line"]
	assert_int(code).override_failure_message(output).is_equal(0)
	assert_str(last_line).starts_with("AUDIO CHECK OK")
	# 29 legacy + 14 variety sounds + the 2 beds: the generator and the catalog know the same files
	assert_str(last_line).contains("(%d files" % (AudioCatalog.all_ids().size() + 2))


func test_the_generator_report_finds_no_problem_in_the_committed_files() -> void:
	var result: Dictionary = _run_generator(["--report"])
	var code: int = result["code"]
	var output: String = result["output"]
	var last_line: String = result["last_line"]
	assert_int(code).override_failure_message(output).is_equal(0)
	assert_str(last_line).contains("problems=0")
