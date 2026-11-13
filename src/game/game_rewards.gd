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
	var launch: Dictionary = launch_of(summary)
	var extras: Dictionary = {}
	if not launch.is_empty():
		extras = extras_of(summary, Save.content_set(), launch)
	var granted: bool = Save.grant_run_reward(summary.run_id, summary.result, summary.data_reward, summary.core_hp, extras)
	if not granted and Save.profile_dirty():
		var _retried: bool = Save.flush()
	flush_pending = Save.profile_dirty()
	if flush_pending:
		Log.warn("GameRewards", "profile flush failed after run %s; will retry" % summary.run_id)
	return granted


## How the run of `summary` was started: { "kit": StringName, "daily": bool }, known only to the live generated run
## (`Game.run` with this run id). {} for anything else (a stale run file closed at launch, a run of the legacy five-wave
## content, a controller driven without `Game`) and for a run with a debug switch on (invulnerable core, damage
## multiplier, starting Scrap): such a run is paid its Data and nothing of the Archive layer (milestones, records,
## Daily Run) is recorded for it, so a debug build cannot fill the Archive.
static func launch_of(summary: RunSummary) -> Dictionary:
	var live: RunController = Game.run
	if live == null or live.run_id != summary.run_id or live.sim == null or not live.sim.content.is_variety():
		return {}
	var config: SimConfig = live.sim.config
	if config.debug_invulnerable_core or config.debug_damage_mult != 1.0 or config.debug_start_scrap != 0:
		return {}
	var kit_id: StringName = Profile.DEFAULT_KIT
	if config.kit_index >= 0 and config.kit_index < config.content.kits.size():
		kit_id = config.content.kits[config.kit_index].id
	return {"kit": kit_id, "daily": config.daily}


## What the Archive layer of the profile learns from a finished run (RewardLedger lists the keys): the best wave, the
## bosses killed (a boss counts when `kills_by_type` has its body), the kit, the primary weapon and, for a Daily Run, its
## UTC date (the day the run started). `launch` is `launch_of(summary)`.
static func extras_of(summary: RunSummary, content: ContentSet, launch: Dictionary = {}) -> Dictionary:
	var kit_text: String = str(launch.get("kit", Save.profile.kit))
	var out: Dictionary = {
		"best_wave": summary.waves_completed,
		"act_reached": summary.act_reached,
		"boss_kills": Array(boss_kills(summary, content)),
		"kit": kit_text,
		"primary_weapon": String(primary_weapon(summary, content)),
		"weapons": Array(weapon_ids(summary, content)),
	}
	if launch.get("daily", false) == true:
		var date: String = GameLaunch.run_date(summary.run_id)
		out["daily"] = {"date": date if date != "" else GameLaunch.utc_date()}
	return out


## Ids of the bosses of `content` that the run killed.
static func boss_kills(summary: RunSummary, content: ContentSet) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if content == null:
		return out
	for b: BossDef in content.bosses:
		if b.enemy_index >= 0 and b.enemy_index < summary.kills_by_type.size() and summary.kills_by_type[b.enemy_index] > 0:
			out.append(String(b.id))
	return out


## Ids of the weapons carried at the end, slot order (empty slots left out).
static func weapon_ids(summary: RunSummary, content: ContentSet) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if content == null:
		return out
	for index: int in summary.weapons:
		if index >= 0 and index < content.weapons.size():
			out.append(String(content.weapons[index].id))
	return out


## The weapon that carried the run: the carried weapon with the highest tier (weapons.json `tier`), the lower slot on a
## tie. "" when nothing is carried. The milestone "victories with 3 different primary weapons" counts these.
static func primary_weapon(summary: RunSummary, content: ContentSet) -> StringName:
	var best: StringName = &""
	var best_tier: int = -1
	if content == null:
		return best
	for index: int in summary.weapons:
		if index < 0 or index >= content.weapons.size():
			continue
		var def: WeaponDef = content.weapons[index]
		if def.tier > best_tier:
			best_tier = def.tier
			best = def.id
	return best


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
