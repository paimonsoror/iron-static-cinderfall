class_name RewardLedger
extends RefCounted
## What a finished run writes into the profile besides the run's Data (VARIETY_SPEC 8.4 and 8.5, CONTENT 10): the best
## wave, the boss kills, victories per kit and per primary weapon, the milestones and the Daily Run record. Pure
## functions of a Profile; `Save.grant_run_reward` calls `apply` once per run id, inside the same grant and the same
## flush, so a run is rewarded once however often it is resumed.
##
## `extras` is what the game layer knows about the run (GameRewards.extras_of); every key is optional and a wrong type
## is ignored:
##   "best_wave": int            waves cleared
##   "boss_kills": Array[String] ids of the bosses killed in this run
##   "kit": String               the kit id the run started with
##   "primary_weapon": String    the weapon that carried the run (GameRewards.primary_weapon)
##   "daily": { "date": "YYYY-MM-DD" }   present for a Daily Run, `date` is the UTC day it started
##
## Milestone ids and what each pays come from `content.run.milestones`; an id that the content does not list pays
## nothing and is not claimed. A grant with no `extras` at all (the four-parameter form) is the plain Data grant of
## before the Archive: it records no facts and claims no milestone.

const MS_FIRST_BOSS: String = "ms_first_boss_"
const MS_FIRST_VICTORY: StringName = &"ms_first_victory"
const MS_VICTORY_KIT: String = "ms_victory_kit_"
const MS_THREE_BUILDS: StringName = &"ms_three_builds"
const THREE_BUILDS: int = 3  ## victories with this many different primary weapons
const PRACTICE_DIVISOR: float = 2.0  ## a Daily Run practice attempt pays half of the run's Data


## Applies the run to `p` and returns what it added, for the results screen:
## { "run_data": int, "milestones": [ { "id": String, "data": int } ], "milestone_data": int, "total": int,
##   "daily": "" | "rewarded" | "practice" }.
## `run_data` is already halved for a practice attempt. Counters of `p` other than the ones named in the header
## (`data`, `runs_played`, ...) are the caller's.
static func apply(p: Profile, content: ContentSet, result: int, run_data: int, extras: Dictionary) -> Dictionary:
	var victory: bool = result == RunResult.Id.VICTORY
	var run_amount: int = maxi(run_data, 0)
	var waves: int = _whole(extras.get("best_wave"))
	p.best_wave = maxi(p.best_wave, mini(waves, Profile.MAX_COUNT))
	var killed: PackedStringArray = _killed_bosses(extras)
	for boss_id: String in killed:
		_bump(p.boss_kills, boss_id)
	var kit: String = _text(extras.get("kit"))
	var weapon: String = _text(extras.get("primary_weapon"))
	if victory:
		if not kit.is_empty():
			_bump(p.victories_by_kit, kit)
		if not weapon.is_empty() and not p.victory_weapons.has(weapon) and p.victory_weapons.size() < Profile.MAX_WEAPONS:
			p.victory_weapons.append(weapon)
	var daily: String = _daily(p, extras, waves, victory)
	if daily == "practice":
		run_amount = floori(float(run_amount) / PRACTICE_DIVISOR)
	var rows: Array = []
	var paid: int = 0
	var claimable: PackedStringArray = _earned(p, killed, victory, kit) if not extras.is_empty() else PackedStringArray()
	for id: String in claimable:
		var amount: int = _milestone_data(content, id)
		if amount < 0 or p.claimed.has(id) or p.claimed.size() >= Profile.MAX_CLAIMED:
			continue
		p.claimed.append(id)
		rows.append({"id": id, "data": amount})
		paid += amount
	return {"run_data": run_amount, "milestones": rows, "milestone_data": paid, "total": run_amount + paid, "daily": daily}


## Milestone ids this run could claim, in the order they are listed in CONTENT 10 (boss firsts, first victory, kit,
## three builds). Claimed ones are filtered by the caller.
static func _earned(p: Profile, killed: PackedStringArray, victory: bool, kit: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for boss_id: String in killed:
		out.append(MS_FIRST_BOSS + boss_id)
	if victory:
		out.append(String(MS_FIRST_VICTORY))
		if not kit.is_empty():
			out.append(MS_VICTORY_KIT + kit)
		if p.victory_weapons.size() >= THREE_BUILDS:
			out.append(String(MS_THREE_BUILDS))
	return out


## Updates the Daily Run record. "" when the run was not a Daily Run, "rewarded" for the first attempt of the day,
## "practice" for every later one. A new date starts a new record.
static func _daily(p: Profile, extras: Dictionary, waves: int, victory: bool) -> String:
	var d_v: Variant = extras.get("daily")
	if typeof(d_v) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = d_v
	var date: String = _text(d.get("date"))
	if not Profile.is_date(date):
		return ""
	if p.daily.get("date", "") != date:
		p.daily = Profile.empty_daily()
		p.daily["date"] = date
	var was_rewarded: bool = p.daily.get("rewarded", false) == true
	var best: int = p.daily.get("best_wave", 0)
	p.daily["best_wave"] = maxi(best, mini(waves, Profile.MAX_COUNT))
	p.daily["won"] = p.daily.get("won", false) == true or victory
	p.daily["rewarded"] = true
	return "practice" if was_rewarded else "rewarded"


static func _milestone_data(content: ContentSet, id: String) -> int:
	if content == null or content.run == null:
		return -1
	var amount: int = content.run.milestones.get(StringName(id), -1)
	return amount


static func _killed_bosses(extras: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var v: Variant = extras.get("boss_kills")
	if typeof(v) != TYPE_ARRAY:
		return out
	var rows: Array = v
	for item: Variant in rows:
		var id: String = _text(item)
		if not id.is_empty() and id.length() <= Profile.MAX_ID_LENGTH and not out.has(id):
			out.append(id)
	return out


static func _bump(tally: Dictionary[String, int], id: String) -> void:
	if not tally.has(id) and tally.size() >= Profile.MAX_TALLY:
		return
	var n: int = tally.get(id, 0)
	tally[id] = mini(n + 1, Profile.MAX_COUNT)


static func _whole(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		var n: int = v
		return maxi(n, 0)
	return 0


static func _text(v: Variant) -> String:
	if typeof(v) == TYPE_STRING:
		var s: String = v
		return s
	return ""
