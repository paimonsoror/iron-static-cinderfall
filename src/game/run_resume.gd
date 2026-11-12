class_name RunResume
extends RefCounted
## Rebuilds the world of a run file: the fallback chain of VARIETY_SPEC 2.8.
##
##  1. SNAPSHOT: a fresh world from the saved config, `WorldSnapshot.restore`, then `state_hash()` must equal the saved
##     `state_hash`.
##  2. FULL_REPLAY, when 1 fails: `Replay.run` of the saved log from tick 0 up to the boundary tick; the hash there must
##     equal the saved one as well (the test oracle and the last resort; its time grows with the run).
##  3. FAILED, when 2 fails too: the caller closes the run and pays it as a defeat at the last saved wave (`close`).
##
## After 1 or 2 the saved tail is submitted again with Replay-style stepping up to `resume_tick` (or, after a crash
## with no pause notice, up to the last recorded command, so the running wave starts again). The same commands on the
## same seed land in the same state: a resume gives nothing back but the wave a crash took.

enum Mode { FAILED, SNAPSHOT, FULL_REPLAY }


static func rebuild(doc: Dictionary, content: ContentSet) -> RunResumeResult:
	var r: RunResumeResult = RunResumeResult.new()
	r.run_id = RunFile.id_of(doc)
	if RunFile.check(doc, content) != RunFile.Verdict.RESUMABLE:
		r.reason = "the run file is not from this build and content"
		return r
	r.config = RunFile.config_from(doc, content)
	var boundary: Dictionary = RunFile.boundary_of(doc)
	var at: int = maxi(0, RunFile.whole(boundary.get("tick"), 0))
	var saved_hash: String = RunFile.text(boundary.get("state_hash"))
	var state: Dictionary = boundary.get("state", {})
	var before: CommandLog = RunFile.commands(doc, "log")
	var world: SimWorld = SimWorld.new(r.config)
	if WorldSnapshot.restore(world, state) and world.tick == at and world.state_hash() == saved_hash:
		world.command_log.entries = _copies(before.entries, true)
		r.mode = Mode.SNAPSHOT
	else:
		r.reason = "snapshot rejected (state hash mismatch)"
		world = Replay.run(r.config, before, at)
		if world.tick != at or world.state_hash() != saved_hash:
			r.reason = "snapshot and full replay both rejected (state hash mismatch at tick %d)" % at
			return r
		r.mode = Mode.FULL_REPLAY
	if not replay_tail(world, RunFile.commands(doc, "tail").entries, RunFile.target_tick(doc)):
		r.mode = Mode.FAILED
		r.reason = "the command tail does not fit the run"
		return r
	r.world = world
	return r


## Submits `rows` (commands with the tick they were applied at) to `world` and steps it up to `target_tick`, like
## Replay.run: a command logged at tick T is submitted before step T, and a world that waits for a choice with no
## command left stops there. Events are drained and dropped. True when every command was submitted.
static func replay_tail(world: SimWorld, rows: Array[SimCommand], target_tick: int) -> bool:
	var next_entry: int = 0
	while not world.is_over() and world.tick < target_tick:
		var due: int = world.tick + 1
		while next_entry < rows.size() and rows[next_entry].tick <= due:
			world.submit(_copy(rows[next_entry], false))
			next_entry += 1
		if world.phase_state.awaiting != PhaseState.Await.NONE and world.command_queue.is_empty():
			break
		world.step()
		world.events.drain()
	return next_entry == rows.size()


## Ends a run that cannot be resumed: pays it once as a defeat at the last saved wave and deletes the run file.
## Returns true when this call granted the reward (false for a run id that was paid before, or a file with no id).
static func close(doc: Dictionary, content: ContentSet) -> bool:
	var id: String = RunFile.id_of(doc)
	var granted: bool = false
	if not id.is_empty():
		var summary: RunSummary = RunSummary.new()
		summary.run_id = id
		summary.run_seed = RunFile.whole(doc.get("seed"), 0)
		summary.result = RunResult.Id.DEFEAT
		summary.waves_completed = RunFile.waves_cleared(doc)
		summary.data_reward = RunFile.closing_reward(doc, content)
		granted = GameRewards.grant(summary)
	Save.clear_run()
	Log.info("RunResume", "run %s closed as a defeat at wave %d granted=%s" % [id, RunFile.waves_cleared(doc), str(granted)])
	return granted


static func _copies(rows: Array[SimCommand], keep_tick: bool) -> Array[SimCommand]:
	var out: Array[SimCommand] = []
	for c: SimCommand in rows:
		out.append(_copy(c, keep_tick))
	return out


static func _copy(c: SimCommand, keep_tick: bool) -> SimCommand:
	var out: SimCommand = SimCommand.new()
	out.command_id = c.command_id
	out.kind = c.kind
	out.arg = c.arg
	if keep_tick:
		out.tick = c.tick
	return out
