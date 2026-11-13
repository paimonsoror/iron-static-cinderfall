extends SceneTree
## Headless predictability scorecard (VARIETY_SPEC 14.2). Run through tools\scorecard_run.ps1.
## Usage: godot --headless --path . -s res://tools/scorecard_run.gd -- [--runs N] [--seed S] [--pool base|full]
##   [--shard I --shards K] [--out FILE] [--report FILE,FILE] [--data DIR]
## Plays N seeds x 8 policies, `balanced` with a forced standard and a forced hot route, and `balanced` in the other
## pool (ScorecardPlan), then prints the card. With --out it plays only its shard, writes one JSON record per run to
## FILE and prints no card; with --report it plays nothing and prints the card of the records in the given files (the
## wrapper joins the shards this way).
## stdout (deterministic): "SCORECARD run ..." per run, "SCORECARD policy ..." per policy, "SCORECARD row ..." and
## "SCORECARD detail ..." per row, and as the LAST line "SCORECARD: PASS|WARN|FAIL rows=.. pass=.. warn=.. fail=..
## runs=..". Wall-clock is on a "TIMING" line. Exit 0 on PASS or WARN, 1 on FAIL, 2 on bad arguments or unreadable
## content or records.


func _initialize() -> void:
	var args: ScorecardArgs = ScorecardArgs.parse(OS.get_cmdline_user_args())
	if not args.error.is_empty():
		print("SCORECARD ERROR: %s" % args.error)
		print(ScorecardArgs.USAGE)
		quit(2)
		return
	var loaded: ContentLoadResult = ContentLoader.load_from_dir(args.data_dir)
	var problems: PackedStringArray = loaded.errors
	if problems.is_empty():
		problems = ContentValidator.validate(loaded.content)
	if problems.is_empty() and not loaded.content.is_variety():
		problems.append("%s is the legacy content: the scorecard needs the variety files (run.json and the others)" % args.data_dir)
	if not problems.is_empty():
		for p: String in problems:
			print("SCORECARD ERROR: content: %s" % p)
		quit(2)
		return
	var context: Dictionary = ScorecardPlan.context(loaded.content, args.pool)
	if not args.report_files.is_empty():
		var stored: Array[Dictionary] = _read(args.report_files)
		if stored.is_empty():
			print("SCORECARD ERROR: no records in %s" % ",".join(args.report_files))
			quit(2)
			return
		_card(stored, context)
		return
	var jobs: Array[Dictionary] = ScorecardPlan.shard(
		ScorecardPlan.jobs(args.runs, args.first_seed, args.pool), args.shard, args.shards
	)
	print("SCORECARD config data=%s runs=%d seed=%d pool=%s shard=%d/%d jobs=%d" % [
		args.data_dir, args.runs, args.first_seed, args.pool, args.shard, args.shards, jobs.size(),
	])
	var records: Array[Dictionary] = []
	var sink: FileAccess = null
	if not args.out_file.is_empty():
		sink = FileAccess.open(args.out_file, FileAccess.WRITE)
		if sink == null:
			print("SCORECARD ERROR: cannot write %s" % args.out_file)
			quit(2)
			return
	var t0: int = Time.get_ticks_usec()
	var ticks: int = 0
	for job: Dictionary in jobs:
		var rec: Dictionary = ScorecardPlan.play(loaded.content, job)
		records.append(rec)
		ticks += ScorecardRecord.whole(rec, "ticks")
		print(_run_line(rec))
		if sink != null:
			sink.store_line(ScorecardRecord.to_line(rec))
			sink.flush()
	var wall: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	var sim_s: float = float(ticks) / float(SimWorld.TICK_RATE)
	print("TIMING wall=%.2fs sim=%.1fs speedup=%.0fx" % [wall, sim_s, sim_s / maxf(wall, 0.000001)])
	if sink != null:
		sink.close()
		print("SCORECARD shard %d/%d done runs=%d" % [args.shard, args.shards, records.size()])
		quit(0)
		return
	_card(records, context)


func _card(records: Array[Dictionary], context: Dictionary) -> void:
	for policy_name: String in PolicyBot.NAMES:
		var group: Array[Dictionary] = ScorecardRecord.select(records, policy_name)
		if not group.is_empty():
			print(_policy_line(policy_name, group))
	var rows: Array[Dictionary] = Scorecard.evaluate(records, context)
	for row: Dictionary in rows:
		var verdict: int = row["verdict"]
		print("SCORECARD row %s %s measured=\"%s\" target=\"%s\"" % [row["id"], Scorecard.verdict_name(verdict), row["measured"], row["target"]])
		var detail: PackedStringArray = row["detail"]
		for line: String in detail:
			print("SCORECARD detail %s %s" % [row["id"], line])
	print(Scorecard.summary_line(rows, records.size()))
	quit(1 if Scorecard.worst(rows) == Scorecard.Verdict.FAIL else 0)


func _read(files: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n", false):
			var rec: Dictionary = ScorecardRecord.from_line(line)
			if not rec.is_empty():
				out.append(rec)
	return out


func _run_line(rec: Dictionary) -> String:
	return (
		"SCORECARD run policy=%s variant=%s pool=%s seed=%d result=%s waves=%d/%d death_wave=%d combat_s=%.1f core=%.2f data=%d clean=%d signature=%s"
		% [
			ScorecardRecord.text(rec, "policy"), ScorecardRecord.text(rec, "variant"), ScorecardRecord.text(rec, "pool"),
			ScorecardRecord.whole(rec, "seed"), ScorecardRecord.text(rec, "result"), ScorecardRecord.whole(rec, "waves"),
			ScorecardRecord.whole(rec, "wave_total"), ScorecardRecord.whole(rec, "death_wave"), ScorecardRecord.num(rec, "combat_s"),
			ScorecardRecord.num(rec, "core"), ScorecardRecord.whole(rec, "data"), 1 if ScorecardRecord.flag(rec, "clean", true) else 0,
			ScorecardRecord.text(rec, "signature"),
		]
	)


func _policy_line(policy_name: String, group: Array[Dictionary]) -> String:
	var wins: Array[Dictionary] = ScorecardRecord.wins_of(group)
	var deaths: PackedFloat64Array = PackedFloat64Array()
	for rec: Dictionary in ScorecardRecord.losses_of(group):
		deaths.append(ScorecardRecord.num(rec, "death_wave"))
	return "SCORECARD policy=%s runs=%d wins=%d win_rate=%s death_wave_median=%.1f" % [
		policy_name, group.size(), wins.size(), ScorecardStats.percent(ScorecardRecord.win_rate(group)), ScorecardStats.median(deaths),
	]
