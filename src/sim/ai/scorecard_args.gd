class_name ScorecardArgs
extends RefCounted
## Command-line options of tools/scorecard_run.gd (the part after `--`):
##   --runs N        seeds to play (default 30, the gate; the full card is 200)
##   --seed S        first seed; run k uses S + k (default 1)
##   --pool P        base | full: the pool of the main runs (default base)
##   --shard I --shards K   play only the jobs at positions I, I+K, ... (default 0 of 1)
##   --out FILE      write one JSON record per finished run to FILE (a shard of a parallel card)
##   --report A,B    do not play: read the records of these files and print the card
##   --data DIR      read the content from DIR instead of res://data
## An unknown flag or a bad value sets `error`.

const USAGE: String = (
	"usage: --runs N --seed S --pool base|full --shard I --shards K --out FILE --report FILE,FILE --data DIR"
)

var runs: int = 30
var first_seed: int = 1
var pool: String = "base"
var shard: int = 0
var shards: int = 1
var out_file: String = ""
var report_files: PackedStringArray = PackedStringArray()
var data_dir: String = "res://data"
var error: String = ""


static func parse(args: PackedStringArray) -> ScorecardArgs:
	var a: ScorecardArgs = ScorecardArgs.new()
	var i: int = 0
	while i < args.size() and a.error.is_empty():
		var flag: String = args[i]
		if i + 1 >= args.size():
			a.error = "flag %s needs a value" % flag
			break
		var value: String = args[i + 1]
		i += 2
		match flag:
			"--runs":
				a.runs = _int(a, flag, value, 1)
			"--seed":
				a.first_seed = _int(a, flag, value, -2147483648)
			"--pool":
				if ScorecardPlan.POOLS.has(value):
					a.pool = value
				else:
					a.error = "--pool must be base or full (got %s)" % value
			"--shard":
				a.shard = _int(a, flag, value, 0)
			"--shards":
				a.shards = _int(a, flag, value, 1)
			"--out":
				a.out_file = value
			"--report":
				a.report_files = PackedStringArray(value.split(",", false))
			"--data":
				a.data_dir = value
			_:
				a.error = "unknown flag %s" % flag
	if a.error.is_empty() and a.shard >= a.shards:
		a.error = "--shard %d must be below --shards %d" % [a.shard, a.shards]
	return a


static func _int(a: ScorecardArgs, flag: String, value: String, minimum: int) -> int:
	if value.is_valid_int() and value.to_int() >= minimum:
		return value.to_int()
	a.error = "%s must be an integer >= %d (got %s)" % [flag, minimum, value]
	return minimum
