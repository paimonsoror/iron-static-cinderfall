class_name HarnessArgs
extends RefCounted
## Command-line options shared by tools/sim_run.gd and tools/balance_run.gd (the part after `--`).
##   --runs N          seeds to play (default 20)
##   --seed S          first seed; run k uses S + k (default 1)
##   --policy P        none | greedy | both (sim_run default greedy, balance_run always plays both); sim_run also
##                     takes every other policy by name (random, hoarder, spammer, turret_rush, balanced, risk)
##   --max-ticks T     stop an unfinished run here (default SimHarness.DEFAULT_MAX_TICKS)
##   --damage-mult F   SimConfig.debug_damage_mult (default 1.0)
##   --start-scrap N   SimConfig.debug_start_scrap (default 0)
##   --data DIR        read the content from DIR instead of res://data (an experiment, never the shipped numbers)
## An unknown flag or a bad value sets `error`.

const USAGE: String = (
	"usage: --runs N --seed S --policy none|greedy|both --max-ticks T --damage-mult F --start-scrap N --data DIR"
)
const USAGE_SIM: String = (
	"usage: --runs N --seed S --policy none|greedy|random|hoarder|spammer|turret_rush|balanced|risk|both"
	+ " --max-ticks T --damage-mult F --start-scrap N --data DIR"
)

var runs: int = 20
var first_seed: int = 1
var policy: String = "greedy"
var max_ticks: int = SimHarness.DEFAULT_MAX_TICKS
var max_ticks_given: bool = false  ## --max-ticks was on the command line (sim_run otherwise sizes it to the content)
var damage_mult: float = 1.0
var start_scrap: int = 0
var data_dir: String = "res://data"
var error: String = ""


## `variety_policies` lets `--policy` name any of the eight policies (sim_run); without it only none, greedy and both
## are accepted, as balance_run needs.
static func parse(args: PackedStringArray, default_policy: String = "greedy", variety_policies: bool = false) -> HarnessArgs:
	var a: HarnessArgs = HarnessArgs.new()
	a.policy = default_policy
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
			"--policy":
				if value in ["none", "greedy", "both"] or (variety_policies and PolicyBot.policy_from_name(value) >= 0):
					a.policy = value
				elif variety_policies:
					a.error = "--policy must be one of %s or both (got %s)" % [", ".join(PolicyBot.NAMES), value]
				else:
					a.error = "--policy must be none, greedy or both (got %s)" % value
			"--max-ticks":
				a.max_ticks = _int(a, flag, value, 1)
				a.max_ticks_given = true
			"--damage-mult":
				if value.is_valid_float() and value.to_float() > 0.0:
					a.damage_mult = value.to_float()
				else:
					a.error = "--damage-mult must be a number > 0 (got %s)" % value
			"--start-scrap":
				a.start_scrap = _int(a, flag, value, 0)
			"--data":
				a.data_dir = value
			_:
				a.error = "unknown flag %s" % flag
	return a


## The PolicyBot.Policy values this option plays, in the order they are reported.
func policies() -> Array[int]:
	var out: Array[int] = []
	if policy == "both":
		out.append(PolicyBot.Policy.NONE)
		out.append(PolicyBot.Policy.GREEDY)
	elif PolicyBot.policy_from_name(policy) >= 0:
		out.append(PolicyBot.policy_from_name(policy))
	return out


static func policy_name(policy_value: int) -> String:
	return PolicyBot.name_of(policy_value)


static func _int(a: HarnessArgs, flag: String, value: String, minimum: int) -> int:
	if value.is_valid_int() and value.to_int() >= minimum:
		return value.to_int()
	a.error = "%s must be an integer >= %d (got %s)" % [flag, minimum, value]
	return minimum
