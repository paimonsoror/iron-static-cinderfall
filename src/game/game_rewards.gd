class_name GameRewards
extends RefCounted
## Recovered Data for a finished run (GDD 8.2): granted once per run id, saved at once, before anything shows it.
## `Save.grant_run_reward` is idempotent per run id and keeps the grant in memory when the disk write fails, but it
## cannot tell the caller that the write failed (and a restart before a successful write would lose the grant). So
## this class flushes again after a grant, remembers a failed flush in `flush_pending`, and `retry_pending` is called
## at the next opportunities (state changes, app pause, a slow timer) until a flush succeeds. No UI code grants.

## True while the profile in memory has changes that no successful flush has written yet.
static var flush_pending: bool = false


## Grants `summary` once. True only for the call that actually granted (a second call, a replayed results screen or a
## second finish returns false and changes nothing). Always flushes after a real grant.
static func grant(summary: RunSummary) -> bool:
	if summary.result != RunResult.Id.VICTORY and summary.result != RunResult.Id.DEFEAT:
		return false
	var granted: bool = Save.grant_run_reward(summary.run_id, summary.result, summary.data_reward, summary.core_hp)
	if granted or flush_pending:
		flush_pending = not Save.flush()
		if flush_pending:
			Log.warn("GameRewards", "profile flush failed after run %s; will retry" % summary.run_id)
	return granted


## Writes the profile now (app pause, quit). A failed write is remembered and retried later.
static func flush_now() -> bool:
	var ok: bool = Save.flush()
	flush_pending = not ok
	return ok


## Retries a failed flush. True when nothing is pending afterwards.
static func retry_pending() -> bool:
	if not flush_pending:
		return true
	flush_pending = not Save.flush()
	if not flush_pending:
		Log.info("GameRewards", "pending profile flush succeeded")
	return not flush_pending
