class_name GameLaunch
extends RefCounted
## What the debug arguments (ARCH 11) change about how a run starts, and how seeds and run ids are made. Pure helpers
## for Game, unit-testable without a scene tree.


const SCENARIO_WAVE: String = "wave:"  ## --scenario=wave:<n> (what --wave=<n> means): start at wave n, scripted build
const SCENARIO_BOSS: String = "boss:"  ## --scenario=boss:<id>: start at the boss wave of that boss (or Node 9 variant)


## --autoplay, --scenario=hold<N>, --scenario=wave:<n> or --scenario=boss:<id>: skip the boot screen and the menus and
## deploy at once.
static func wants_autostart(args: DebugArgs) -> bool:
	return args.autoplay != "" or args.scenario_n > 0 or start_wave_of(args) > 1 or boss_of(args) != &""


## The wave of `--scenario=wave:<n>`; 0 when the argument is not that.
static func start_wave_of(args: DebugArgs) -> int:
	var value: String = args.scenario.trim_prefix(SCENARIO_WAVE)
	return value.to_int() if args.scenario.begins_with(SCENARIO_WAVE) and value.is_valid_int() else 0


## The boss id of `--scenario=boss:<id>`; empty when the argument is not that.
static func boss_of(args: DebugArgs) -> StringName:
	return StringName(args.scenario.trim_prefix(SCENARIO_BOSS)) if args.scenario.begins_with(SCENARIO_BOSS) else &""


## The PolicyBot.Policy of `--autoplay=<name>`: a name of PolicyBot.NAMES (none, greedy, random, balanced, ...); an
## unknown name is the do-nothing policy, which still answers every intermission choice (PolicyAnswers).
static func autoplay_policy(policy_name: String) -> int:
	var policy: int = PolicyBot.policy_from_name(policy_name)
	return policy if policy >= 0 else PolicyBot.Policy.NONE


## --scenario=hold<N> makes the core invulnerable and holds N enemies alive; --autoplay=<policy> attaches the bot
## (`autoplay_policy`). Neither changes the content or the rules. --scenario=wave:<n> and --scenario=boss:<id> start the
## run later (DebugStart: a scripted build, the chosen boss).
static func configure(config: SimConfig, run: RunController, args: DebugArgs, seed_value: int) -> void:
	if args.scenario_n > 0:
		config.debug_invulnerable_core = true
		run.scenario = GameHoldScenario.new(args.scenario_n, seed_value)
	config.debug_start_wave = start_wave_of(args)
	config.debug_boss = boss_of(args)
	if args.autoplay != "":
		run.bot = PolicyBot.new(autoplay_policy(args.autoplay))
		run.bot.id_source = run.api.next_command_id  # one id counter for the bot and for the player's HUD taps


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


# --- the Daily Run (VARIETY_SPEC 8.5, decision D8). The sim never reads the clock: the date is read here and only the
# seed derived from it reaches the sim. ---

## The kit of every Daily Run and the prefix of its seed text: the Daily Run is the same for everyone on a given UTC day.
const DAILY_KIT: StringName = &"k_standard"
const DAILY_SEED_PREFIX: String = "daily|"
const SEED_MASK: int = 0x7FFFFFFF  ## run seeds are 31-bit (pick_seed)


## "YYYY-MM-DD" of the UTC day of `unix_time` (-1 = now).
static func utc_date(unix_time: int = -1) -> String:
	var at: int = int(Time.get_unix_time_from_system()) if unix_time < 0 else unix_time
	return Time.get_date_string_from_unix_time(at)


## The seed of the Daily Run of `date` ("YYYY-MM-DD", UTC): the first 31 bits of sha256("daily|" + date). Same date,
## same seed, on every machine; any other date gives a different one. An empty or malformed date gives -1 (no seed).
static func daily_seed(date: String) -> int:
	if not Profile.is_date(date):
		return -1
	var digest: String = (DAILY_SEED_PREFIX + date).sha256_text()
	return digest.substr(0, 8).hex_to_int() & SEED_MASK


## The UTC date a run id was made on ("<unix>-<seed>" or "<unix>-<seed>-<n>", GameLaunch.make_run_id), or "" when the id
## does not start with a unix time. A Daily Run counts for the day it started, not the day it ended.
static func run_date(run_id: String) -> String:
	var head: String = run_id.get_slice("-", 0)
	if head.is_empty() or not head.is_valid_int():
		return ""
	return utc_date(head.to_int())
