extends SceneTree
## Headless run-plan printer. Run through tools\plan_dump.ps1.
## Usage: godot --headless --path . -s res://tools/plan_dump.gd -- [--seed S] [--data DIR]
## Builds the world of seed S on the content in DIR (default res://data) and prints the plan it generated at tick 0:
## the bosses, both options of every wave (pack, modifier, reward, hot flag, groups, elites), the events, the drum
## points. stdout is a pure function of the seed and the data: "PLAN ..." lines and, last, "PLAN SUMMARY: ...".
## "PLAN UNAVAILABLE: <why>" when there is no generated plan to print (the plan is still the legacy stub of the
## scaffold, or the content is the legacy five-wave content); "PLAN ERROR: <why>" for bad arguments or content.
## Exit 0 printed, 1 unavailable, 2 error.

const USAGE: String = "usage: --seed S --data DIR"


func _initialize() -> void:
	var run_seed: int = 1
	var data_dir: String = "res://data"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if i + 1 >= args.size():
			_fail("flag %s needs a value" % args[i])
			return
		match args[i]:
			"--seed":
				if not args[i + 1].is_valid_int():
					_fail("--seed must be an integer (got %s)" % args[i + 1])
					return
				run_seed = args[i + 1].to_int()
			"--data":
				data_dir = args[i + 1]
			_:
				_fail("unknown flag %s" % args[i])
				return
		i += 2
	var loaded: ContentLoadResult = ContentLoader.load_from_dir(data_dir)
	var problems: PackedStringArray = loaded.errors
	if problems.is_empty():
		problems = ContentValidator.validate(loaded.content)
	if not problems.is_empty():
		for p: String in problems:
			print("PLAN ERROR: content: %s" % p)
		quit(2)
		return
	if not loaded.content.is_variety():
		print("PLAN UNAVAILABLE: %s is the legacy five-wave content: it has scripted waves and no generated plan" % data_dir)
		quit(1)
		return
	var world: SimWorld = SimWorld.new(SimConfig.create(loaded.content, run_seed))
	if PlanReport.is_legacy_stub(world.plan):
		print("PLAN UNAVAILABLE: %s" % PlanReport.STUB_MESSAGE)
		quit(1)
		return
	for line: String in PlanReport.lines(world.plan, loaded.content, run_seed):
		print(line)
	quit(0)


func _fail(text: String) -> void:
	print("PLAN ERROR: %s" % text)
	print(USAGE)
	quit(2)
