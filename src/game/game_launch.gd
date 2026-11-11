class_name GameLaunch
extends RefCounted
## What the debug arguments (ARCH 11) change about how a run starts, and how seeds and run ids are made. Pure helpers
## for Game, unit-testable without a scene tree.


## --autoplay or --scenario=hold<N>: skip the boot screen and the menus and deploy at once.
static func wants_autostart(args: DebugArgs) -> bool:
	return args.autoplay != "" or args.scenario_n > 0


## --scenario=hold<N> makes the core invulnerable and holds N enemies alive; --autoplay=<policy> attaches the bot
## (anything other than "greedy" is the do-nothing policy). Neither changes the content or the rules.
static func configure(config: SimConfig, run: RunController, args: DebugArgs, seed_value: int) -> void:
	if args.scenario_n > 0:
		config.debug_invulnerable_core = true
		run.scenario = GameHoldScenario.new(args.scenario_n, seed_value)
	if args.autoplay != "":
		var greedy: bool = args.autoplay == "greedy"
		run.bot = PolicyBot.new(PolicyBot.Policy.GREEDY if greedy else PolicyBot.Policy.NONE)


## An explicit seed (>= 0) wins, then a fixed --seed, else a time-based one.
static func pick_seed(run_seed: int, args: DebugArgs) -> int:
	if run_seed >= 0:
		return run_seed
	if args.has_seed:
		return args.run_seed
	return (Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system())) & 0x7FFFFFFF


## "<unix>-<seed>" (ARCH 7.4). An id this session already used, or one already rewarded (same second, same fixed
## seed), gets a counter so that no two runs share an id and a reward can never be mistaken for a repeat.
static func make_run_id(seed_value: int, used: Dictionary[String, bool], awarded: PackedStringArray) -> String:
	var base: String = "%d-%d" % [int(Time.get_unix_time_from_system()), seed_value]
	var candidate: String = base
	var n: int = 1
	while used.has(candidate) or awarded.has(candidate):
		n += 1
		candidate = "%s-%d" % [base, n]
	used[candidate] = true
	return candidate
