extends SceneTree
## Headless whole-run sim runner. Run through tools\sim_run.ps1.
## Usage: godot --headless --path . -s res://tools/sim_run.gd -- [--runs N] [--seed S] [--max-ticks T]
##   [--policy none|greedy|random|hoarder|spammer|turret_rush|balanced|risk|both]
##   [--damage-mult F] [--start-scrap N] [--data DIR]
## --max-ticks defaults to 60,000 on the legacy content and to 108,000 on a generated run (SimHarness).
## stdout (deterministic, byte-identical across executions): one "RUN ..." line per run and policy -- result, ticks,
## seconds, waves, core, peak alive per wave, Scrap earned and spent, purchases, abilities, the death wave (0 unless
## the core fell), the build signature (primary weapon by damage dealt + the two tags with most stacks), state_hash,
## event_hash -- "SIM VIOLATION ..." for every broken invariant (HarnessChecker), and last
## "SIM SUMMARY: runs=N victories=V defeats=D".
## Wall-clock numbers are on a "TIMING" line (the wrapper sends it to stderr). Exit 0 when every run finished clean,
## 1 when a run hit the tick limit, stalled on a choice nobody answered or broke an invariant, 2 on bad arguments or
## unreadable content.


func _initialize() -> void:
	var args: HarnessArgs = HarnessArgs.parse(OS.get_cmdline_user_args(), "greedy", true)
	if not args.error.is_empty():
		print("SIM ERROR: %s" % args.error)
		print(HarnessArgs.USAGE_SIM)
		quit(2)
		return
	var loaded: ContentLoadResult = ContentLoader.load_from_dir(args.data_dir)
	var problems: PackedStringArray = loaded.errors
	if problems.is_empty():
		problems = ContentValidator.validate(loaded.content)
	if not problems.is_empty():
		for p: String in problems:
			print("SIM ERROR: content: %s" % p)
		quit(2)
		return
	var limit: int = args.max_ticks if args.max_ticks_given else SimHarness.default_max_ticks(loaded.content)
	var runs: int = 0
	var victories: int = 0
	var defeats: int = 0
	var unfinished: int = 0
	var violations: int = 0
	var total_ticks: int = 0
	var t0: int = Time.get_ticks_usec()
	for policy: int in args.policies():
		for k: int in args.runs:
			var run_seed: int = args.first_seed + k
			var cfg: SimConfig = SimHarness.config_for(loaded.content, run_seed, args.damage_mult, args.start_scrap)
			var r: HarnessReport = SimHarness.run(cfg, policy, limit)
			runs += 1
			total_ticks += r.ticks
			victories += 1 if r.result == RunResult.Id.VICTORY else 0
			defeats += 1 if r.result == RunResult.Id.DEFEAT else 0
			unfinished += 1 if r.timed_out else 0
			violations += r.violations.size()
			print(_run_line(r))
			for v: String in r.violations:
				print("SIM VIOLATION seed=%d policy=%s %s" % [r.run_seed, HarnessArgs.policy_name(policy), v])
			if r.stalled:
				print("SIM ERROR: seed=%d policy=%s stalled awaiting choice %d (the bot left it open)" % [r.run_seed, HarnessArgs.policy_name(policy), r.stalled_on])
	var wall: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	var sim_s: float = float(total_ticks) / float(SimWorld.TICK_RATE)
	print(
		(
			"TIMING wall=%.2fs sim=%.1fs speedup=%.0fx ms_per_tick=%.3f"
			% [wall, sim_s, sim_s / maxf(wall, 0.000001), 1000.0 * wall / maxf(float(total_ticks), 1.0)]
		)
	)
	if unfinished > 0:
		print("SIM ERROR: %d run(s) hit the tick limit %d without finishing" % [unfinished, limit])
	if violations > 0:
		print("SIM ERROR: %d invariant violation(s)" % violations)
	print("SIM SUMMARY: runs=%d victories=%d defeats=%d" % [runs, victories, defeats])
	quit(1 if (unfinished > 0 or violations > 0) else 0)


func _run_line(r: HarnessReport) -> String:
	var peaks: PackedStringArray = PackedStringArray()
	for n: int in r.peak_alive:
		peaks.append(str(n))
	return (
		(
			"RUN seed=%d policy=%s result=%s ticks=%d seconds=%.1f waves=%d core=%d/%d peak=%s"
			+ " scrap_earned=%d scrap_spent=%d purchases=%d abilities=emp:%d,shield:%d,overdrive:%d"
			+ " max_queue=%d stuck=%d boss_s=%.1f"
			+ " death_wave=%d signature=%s"
			+ " state_hash=%s event_hash=%d"
		)
		% [
			r.run_seed,
			HarnessArgs.policy_name(r.policy),
			r.result_name(),
			r.ticks,
			r.seconds(),
			r.waves_completed,
			floori(r.core_hp),
			floori(r.core_max_hp),
			",".join(peaks),
			r.scrap_earned,
			r.scrap_spent,
			r.purchases,
			r.abilities_used[Ids.AB_EMP],
			r.abilities_used[Ids.AB_SHIELD],
			r.abilities_used[Ids.AB_OVERDRIVE],
			r.max_pending,
			r.stuck_recoveries,
			r.boss_seconds(),
			r.death_wave,
			r.signature,
			r.state_hash,
			r.event_hash,
		]
	)
