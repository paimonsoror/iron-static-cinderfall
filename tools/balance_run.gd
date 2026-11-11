extends SceneTree
## Headless balance runner: N seeds x {no purchases, greedy bot} compared with GDD 8.4. Run through
## tools\balance_run.ps1.
## Usage: godot --headless --path . -s res://tools/balance_run.gd -- [--runs N] [--seed S] [--max-ticks T]
##   [--damage-mult F] [--start-scrap N] [--data DIR]
## stdout (deterministic): "BALANCE run ..." per run, "BALANCE policy ..." and "BALANCE waves ..." summaries, the
## greedy purchase timeline of the first seed, one "BALANCE target ..." row per GDD 8.4 target, and as the LAST line
## "BALANCE: PASS|WARN|FAIL rows=.. pass=.. warn=.. fail=..". Wall-clock is on a "TIMING" line (stderr in the
## wrapper). Exit 0 on PASS or WARN, 1 on FAIL, 2 on bad arguments or unreadable content.

const UPGRADE_NAMES: PackedStringArray = ["damage", "fire_rate", "armor_piercing", "auto_turret", "smg_unlock"]


func _initialize() -> void:
	var args: HarnessArgs = HarnessArgs.parse(OS.get_cmdline_user_args(), "both")
	if args.error.is_empty() and args.policy != "both":
		args.error = "balance_run plays both policies; drop --policy (use sim_run for one)"
	if not args.error.is_empty():
		print("BALANCE ERROR: %s" % args.error)
		print(HarnessArgs.USAGE)
		quit(2)
		return
	var loaded: ContentLoadResult = ContentLoader.load_from_dir(args.data_dir)
	var problems: PackedStringArray = loaded.errors
	if problems.is_empty():
		problems = ContentValidator.validate(loaded.content)
	if not problems.is_empty():
		for p: String in problems:
			print("BALANCE ERROR: content: %s" % p)
		quit(2)
		return
	print("BALANCE config data=%s runs=%d seed=%d max_ticks=%d damage_mult=%s start_scrap=%d" % [args.data_dir, args.runs, args.first_seed, args.max_ticks, str(args.damage_mult), args.start_scrap])
	var t0: int = Time.get_ticks_usec()
	var total_ticks: int = 0
	var by_policy: Array[Array] = [[], []]
	for policy: int in [PolicyBot.Policy.NONE, PolicyBot.Policy.GREEDY]:
		for k: int in args.runs:
			var cfg: SimConfig = SimHarness.config_for(loaded.content, args.first_seed + k, args.damage_mult, args.start_scrap)
			var r: HarnessReport = SimHarness.run(cfg, policy, args.max_ticks)
			total_ticks += r.ticks
			by_policy[policy].append(r)
			print(_run_line(r))
			for v: String in r.violations:
				print("BALANCE violation seed=%d policy=%s %s" % [r.run_seed, HarnessArgs.policy_name(policy), v])
	var none_runs: Array[HarnessReport] = []
	var greedy_runs: Array[HarnessReport] = []
	for r: HarnessReport in by_policy[PolicyBot.Policy.NONE]:
		none_runs.append(r)
	for r: HarnessReport in by_policy[PolicyBot.Policy.GREEDY]:
		greedy_runs.append(r)
	_print_policy("none", none_runs)
	_print_policy("greedy", greedy_runs)
	_print_waves("none", none_runs)
	_print_waves("greedy", greedy_runs)
	_print_buys(greedy_runs[0])
	var rows: Array[Dictionary] = BalanceTargets.evaluate(none_runs, greedy_runs)
	for row: Dictionary in rows:
		var status: int = row["status"]
		print("BALANCE target %s measured=\"%s\" target=\"%s\" %s" % [row["id"], row["measured"], row["target"], BalanceTargets.status_name(status)])
	var wall: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	var sim_s: float = float(total_ticks) / float(SimWorld.TICK_RATE)
	print("TIMING wall=%.2fs sim=%.1fs speedup=%.0fx ms_per_tick=%.3f" % [wall, sim_s, sim_s / maxf(wall, 0.000001), 1000.0 * wall / maxf(float(total_ticks), 1.0)])
	var overall: int = BalanceTargets.worst(rows)
	print(
		(
			"BALANCE: %s rows=%d pass=%d warn=%d fail=%d runs=%d"
			% [
				BalanceTargets.status_name(overall),
				rows.size(),
				BalanceTargets.count(rows, BalanceTargets.Status.PASS),
				BalanceTargets.count(rows, BalanceTargets.Status.WARN),
				BalanceTargets.count(rows, BalanceTargets.Status.FAIL),
				none_runs.size() + greedy_runs.size(),
			]
		)
	)
	quit(1 if overall == BalanceTargets.Status.FAIL else 0)


func _run_line(r: HarnessReport) -> String:
	var peaks: PackedStringArray = PackedStringArray()
	for n: int in r.peak_alive:
		peaks.append(str(n))
	return (
		"BALANCE run policy=%s seed=%d result=%s wave=%d seconds=%.1f core=%d peak=%s purchases=%d state_hash=%s"
		% [HarnessArgs.policy_name(r.policy), r.run_seed, r.result_name(), r.wave_reached, r.seconds(), floori(r.core_hp), ",".join(peaks), r.purchases, r.state_hash.substr(0, 12)]
	)


func _print_policy(label: String, runs: Array[HarnessReport]) -> void:
	var victories: int = 0
	var secs: PackedFloat64Array = PackedFloat64Array()
	var death_waves: PackedFloat64Array = PackedFloat64Array()
	var core: PackedFloat64Array = PackedFloat64Array()
	for r: HarnessReport in runs:
		secs.append(r.seconds())
		if r.is_victory():
			victories += 1
			core.append(100.0 * r.core_fraction())
		else:
			death_waves.append(float(r.wave_reached))
	print(
		(
			"BALANCE policy=%s runs=%d victories=%d defeats=%d seconds_median=%.1f death_wave_median=%.1f core_pct_mean=%.1f"
			% [label, runs.size(), victories, runs.size() - victories, BalanceTargets.median(secs), BalanceTargets.median(death_waves), BalanceTargets.mean(core)]
		)
	)


func _print_waves(label: String, runs: Array[HarnessReport]) -> void:
	for w: int in 5:
		var peaks: PackedFloat64Array = PackedFloat64Array()
		var clears: PackedFloat64Array = PackedFloat64Array()
		var lost: PackedFloat64Array = PackedFloat64Array()
		var scrap: PackedFloat64Array = PackedFloat64Array()
		for r: HarnessReport in runs:
			peaks.append(float(r.peak_alive[w]))
			lost.append(r.core_lost[w])
			scrap.append(float(r.scrap_by_wave[w]))
			if r.wave_seconds(w + 1) >= 0.0:
				clears.append(r.wave_seconds(w + 1))
		print(
			(
				"BALANCE waves policy=%s wave=%d peak_median=%.1f peak_min=%d peak_max=%d clear_s_median=%.1f cleared=%d/%d core_lost_mean=%.1f scrap_mean=%.0f"
				% [label, w + 1, BalanceTargets.median(peaks), int(BalanceTargets.min_of(peaks)), int(BalanceTargets.max_of(peaks)), BalanceTargets.median(clears), clears.size(), runs.size(), BalanceTargets.mean(lost), BalanceTargets.mean(scrap)]
			)
		)


func _print_buys(r: HarnessReport) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in r.buy_ticks.size():
		parts.append("w%d@%d:%s" % [r.buy_waves[i], r.buy_ticks[i], UPGRADE_NAMES[r.buy_upgrades[i]]])
	print("BALANCE buys policy=greedy seed=%d %s" % [r.run_seed, " ".join(parts)])
