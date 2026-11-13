class_name ScorecardPlan
extends RefCounted
## What the card plays and what it needs to know about the content (VARIETY_SPEC 14.2): the list of runs for `n` seeds,
## the pools, one run played into a ScorecardRecord, and the context the rows read (waves, caps, weapon roster).
##
## Per seed the card plays the eight policies once (the main runs), `balanced` forced to the standard route and to the hot
## route (S14), and `balanced` again in the other pool (S15). The list is in seed order, so a card cut short still holds
## whole seeds, and a shard `i` of `k` plays the jobs at positions i, i + k, i + 2k, ...

const POOLS: PackedStringArray = ["base", "full"]
const VARIANT_STANDARD: String = "standard"
const VARIANT_HOT: String = "hot"
const VARIANT_OTHER_POOL: String = "other_pool"


## Every job as { policy (PolicyBot.Policy), seed, variant, pool }.
static func jobs(run_count: int, first_seed: int, pool: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: int in run_count:
		var run_seed: int = first_seed + k
		for policy: int in PolicyBot.Policy.values():
			out.append(_job(policy, run_seed, "", pool))
		out.append(_job(PolicyBot.Policy.BALANCED, run_seed, VARIANT_STANDARD, pool))
		out.append(_job(PolicyBot.Policy.BALANCED, run_seed, VARIANT_HOT, pool))
		out.append(_job(PolicyBot.Policy.BALANCED, run_seed, VARIANT_OTHER_POOL, other_pool(pool)))
	return out


## The jobs of shard `index` of `shards`.
static func shard(all_jobs: Array[Dictionary], index: int, shards: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in all_jobs.size():
		if i % maxi(1, shards) == index:
			out.append(all_jobs[i])
	return out


static func other_pool(pool: String) -> String:
	return "full" if pool == "base" else "base"


## Plays one job. The `base` pool is a profile with no unlock, the `full` pool one with every unlock of the content.
static func play(content: ContentSet, job: Dictionary) -> Dictionary:
	var policy: int = job["policy"]
	var run_seed: int = job["seed"]
	var variant: String = job["variant"]
	var pool: String = job["pool"]
	var config: SimConfig = SimHarness.config_for(content, run_seed)
	config.unlocked = unlocks_of(content, pool)
	var bot: PolicyBot = PolicyBot.new(policy)
	if variant == VARIANT_STANDARD:
		bot.route_mode = PolicyBot.RouteMode.STANDARD
	elif variant == VARIANT_HOT:
		bot.route_mode = PolicyBot.RouteMode.HOT
	var report: HarnessReport = SimHarness.run(config, policy, 0, bot)
	return ScorecardRecord.of(report, content, pool, variant)


## Unlock ids of a pool, sorted (empty for the base pool).
static func unlocks_of(content: ContentSet, pool: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if pool == "full":
		for u: UnlockDef in content.unlocks:
			out.append(String(u.id))
		out.sort()
	return out


## What the rows read from the content: acts, act I waves, the peak table, the caps and the weapon roster of `pool`.
static func context(content: ContentSet, pool: String) -> Dictionary:
	var bodied: Array[int] = []
	var minis: Array[int] = []
	var act_one: int = 0
	var acts: int = 1
	if content.run != null:
		acts = content.run.acts.size()
		for slot: WaveSlotDef in content.run.waves:
			bodied.append(slot.peak_bodied)
			minis.append(slot.peak_minis)
			act_one += 1 if slot.act == 1 else 0
	return {
		"acts": acts, "act1_waves": act_one, "wave_bodied": bodied, "wave_minis": minis,
		"cap_bodied": content.mission.enemy_cap, "cap_minis": content.mission.swarm_cap,
		"cap_blasts": content.run.max_blasts_per_tick if content.run != null else 0,
		"roster": roster(content, pool),
	}


## Weapons a run of `pool` can end up carrying: the tier 1 weapons, and the tier 2 and higher ones that no absent unlock
## holds back and that the crate tables give some weight in some act.
static func roster(content: ContentSet, pool: String) -> Array[String]:
	var unlocked: PackedStringArray = unlocks_of(content, pool)
	var out: Array[String] = []
	for def: WeaponDef in content.weapons:
		if def.tier <= 1 or (_in_crates(content, def) and not _held_back(content, def, unlocked)):
			out.append(String(def.id))
	return out


static func _in_crates(content: ContentSet, def: WeaponDef) -> bool:
	if content.run == null:
		return false
	for act_number: int in range(1, content.run.acts.size() + 1):
		if content.run.tier_weight(act_number, def.tier) > 0.0:
			return true
	return false


static func _held_back(content: ContentSet, def: WeaponDef, unlocked: PackedStringArray) -> bool:
	for u: UnlockDef in content.unlocks:
		if u.grants.has(def.id) and not unlocked.has(String(u.id)):
			return true
	return false


static func _job(policy: int, run_seed: int, variant: String, pool: String) -> Dictionary:
	return {"policy": policy, "seed": run_seed, "variant": variant, "pool": pool}
