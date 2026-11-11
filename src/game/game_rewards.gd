class_name GameRewards
extends RefCounted
## Recovered Data for a finished run (GDD 8.2): granted once per run id, saved at once, before anything shows it.
## `Save.grant_run_reward` is idempotent per run id, flushes once and keeps the grant in memory when the disk write
## fails; it cannot return the failure, so this class reads `Save.profile_dirty()` afterwards. A failed write is
## remembered in `flush_pending` and `retry_pending` is called at the next opportunities (state changes, app pause, a
## slow timer) until a flush succeeds (a restart before that would lose the grant). No UI code grants.

## True while the profile in memory has changes that no successful flush has written yet.
static var flush_pending: bool = false


## Grants `summary` once. True only for the call that actually granted (a second call, a replayed results screen or a
## second finish returns false and changes nothing, except that it retries a write that failed earlier). A real grant
## is written exactly once (by `Save`), so the previous profile file becomes the `.bak` and stays a useful backup.
static func grant(summary: RunSummary) -> bool:
	if summary.result != RunResult.Id.VICTORY and summary.result != RunResult.Id.DEFEAT:
		return false
	var granted: bool = Save.grant_run_reward(summary.run_id, summary.result, summary.data_reward, summary.core_hp)
	if not granted and Save.profile_dirty():
		var _retried: bool = Save.flush()
	flush_pending = Save.profile_dirty()
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
