class_name SimRunQueries
extends RefCounted
## The dictionary-shaped queries of the variety RunApi (VARIETY_SPEC 13.4), read from a live SimWorld. SimRunApi
## delegates here; the shapes are the ones documented in run_api.gd (and mirrored by FakeRunApi). Everything is read
## only. The legacy content (no run plan data) gets the base-class answers from SimRunApi, not from here.


## The wave whose route or boss briefing an intermission shows: the one after the current wave, or null.
static func next_wave(w: SimWorld) -> PlannedWave:
	return w.plan.wave(w.wave + 1) if w.plan != null else null


## Options the player chooses between before the next wave; 0 when it is a boss wave or the run has no further wave.
## Like every query below, a null world (no run, or the legacy content) gives the base default of RunApi.
static func route_option_count(w: SimWorld) -> int:
	var pw: PlannedWave = next_wave(w) if w != null else null
	if pw == null or pw.is_boss:
		return 0
	return pw.options.size()


static func route_option(w: SimWorld, i: int) -> Dictionary:
	var pw: PlannedWave = next_wave(w) if w != null else null
	if pw == null or pw.is_boss or i < 0 or i >= pw.options.size():
		return {}
	return describe_option(w, pw.options[i], pw.act)


## RunApi.route_preview (the field option u_f_preview): option `i` of the wave after next; {} when that wave is a boss
## wave, has no such option or does not exist.
static func route_preview(w: SimWorld, i: int) -> Dictionary:
	var pw: PlannedWave = w.plan.wave(w.wave + 2) if w != null and w.plan != null else null
	if pw == null or pw.is_boss or i < 0 or i >= pw.options.size():
		return {}
	return describe_option(w, pw.options[i], pw.act)


## The option the current wave spawns (RunApi.wave_route); {} before the first wave, without a plan and for null.
static func wave_route(w: SimWorld) -> Dictionary:
	if w == null or w.plan == null or w.wave < 1:
		return {}
	var pw: PlannedWave = w.plan.wave(w.wave)
	var o: RouteOption = w.plan.option(w.wave)
	return describe_option(w, o, pw.act) if pw != null and o != null else {}


## One RouteOption in the shape of RunApi.route_option().
static func describe_option(w: SimWorld, o: RouteOption, act_number: int) -> Dictionary:
	var content: ContentSet = w.content
	var run: RunDef = content.run
	var counts: Dictionary = {}
	var total: int = 0
	for g: SpawnGroupDef in o.groups:
		if g.enemy_index < 0 or g.enemy_index >= content.enemies.size():
			continue
		var enemy_id: StringName = content.enemies[g.enemy_index].id
		var so_far: int = counts.get(enemy_id, 0)
		counts[enemy_id] = so_far + g.count
		total += g.count
	var out: Dictionary = {
		"pack": &"", "name_key": "", "counts": counts, "total": total, "modifier": &"", "modifier_key": "",
		"elites": o.elites.size(), "hot": o.hot, "reward": &"", "reward_key": "", "reward_amount": 0,
	}
	if run == null:
		return out
	if o.pack_index >= 0 and o.pack_index < run.packs.size():
		out["pack"] = run.packs[o.pack_index].id
		out["name_key"] = run.packs[o.pack_index].name_key
	if o.modifier_index >= 0 and o.modifier_index < run.modifiers.size():
		out["modifier"] = run.modifiers[o.modifier_index].id
		out["modifier_key"] = run.modifiers[o.modifier_index].name_key
	if o.reward_index >= 0 and o.reward_index < run.route_rewards.size():
		var reward: RewardDef = run.route_rewards[o.reward_index]
		out["reward"] = reward.id
		out["reward_key"] = reward.name_key
		out["reward_amount"] = _reward_amount(reward, act_number)
	return out


## The amount a reward shows next to its name: the Scrap or Data it grants in that act, else 0.
static func _reward_amount(reward: RewardDef, act_number: int) -> int:
	for op: OpDef in reward.ops:
		if op.kind == OpDef.Kind.GRANT and (op.target == &"scrap" or op.target == &"data"):
			return roundi(op.amount(act_number))
	return 0


static func boss_brief(w: SimWorld) -> Dictionary:
	var pw: PlannedWave = next_wave(w) if w != null else null
	if pw == null or not pw.is_boss:
		return {}
	return boss_of_act(w, pw.act)


## RunApi.act_boss (the field option u_f_boss_intel): the boss of the act the player is in, in the shape of boss_brief().
## Between waves that is the act of the next wave, so the first intermission of an act already names its boss.
static func act_boss(w: SimWorld) -> Dictionary:
	if w == null or w.plan == null:
		return {}
	var pw: PlannedWave = w.plan.wave(w.wave if GameState.is_combat(w.phase) else w.wave + 1)
	return boss_of_act(w, pw.act) if pw != null else {}


## The boss the plan picked for act `act_number`, in the shape of RunApi.boss_brief(); {} when the act has none.
static func boss_of_act(w: SimWorld, act_number: int) -> Dictionary:
	var content: ContentSet = w.content
	var boss: BossDef = null
	var act_slot: int = act_number - 1
	if act_slot >= 0 and act_slot < w.plan.boss_ids.size():
		for b: BossDef in content.bosses:
			if b.enemy_index == w.plan.boss_ids[act_slot]:
				boss = b
	if boss == null:
		return {}
	var variant: StringName = &""
	var last_act: bool = content.run != null and act_number >= content.run.acts.size() and content.run.acts.size() > 1
	if last_act and boss.id == &"siege_hulk" and w.plan.boss_variant >= 0 and w.plan.boss_variant < content.run.hulk_variants.size():
		variant = content.run.hulk_variants[w.plan.boss_variant]
	var attack_key: String = "lore.threat.%s" % boss.id
	return {
		"id": boss.id, "name_key": boss.name_key, "banner_key": boss.banner_key, "variant": variant,
		"attack_key": attack_key if content.strings.has(attack_key) else "", "answer_key": "",
	}


static func salvage_offer(w: SimWorld) -> Dictionary:
	if w == null or w.salvage.offer.is_empty():
		return {}
	var s: SalvageState = w.salvage
	var weapons: Array[StringName] = []
	var tiers: Array[int] = []
	var level_up: Array[int] = []
	for weapon_index: int in s.offer:
		if weapon_index < 0 or weapon_index >= w.content.weapons.size():
			continue
		weapons.append(w.content.weapons[weapon_index].id)
		tiers.append(w.content.weapons[weapon_index].tier)
		var held: int = -1
		for slot: int in w.arsenal.slot_count:
			if w.arsenal.slot_weapon[slot] == weapon_index:
				held = slot
				break
		level_up.append(held)
	return {
		"weapons": weapons, "tiers": tiers, "level_up_slot": level_up, "boss": s.offer_boss,
		"scrap_value": SalvageSystem.scrap_value(w),
	}


## The active slot reads the WardenState mirror (weapon, magazine, reload), the holstered ones the ArsenalState.
static func weapon_slot(w: SimWorld, i: int) -> Dictionary:
	if w == null or i < 0 or i >= w.arsenal.slot_count:
		return {}
	var a: ArsenalState = w.arsenal
	var active: bool = i == a.active
	var holds: bool = active or a.slot_weapon[i] >= 0
	var def: WeaponDef = w.content.weapons[w.warden.weapon_index] if active else ArsenalSystem.weapon_of(w, i)
	var state: int = ArsenalSystem.slot_state(w, i) if holds else ArsenalSystem.ST_EMPTY
	var reload_left: int = w.warden.reload_ticks_left if active else a.slot_reload_left[i]
	if state == ArsenalSystem.ST_READY and reload_left > 0:
		state = ArsenalSystem.ST_RELOADING
	var ticks_left: int = 0
	match state:
		ArsenalSystem.ST_RELOADING:
			ticks_left = reload_left
		ArsenalSystem.ST_VENTING:
			ticks_left = a.slot_vent_left[i]
		ArsenalSystem.ST_SWAPPING:
			ticks_left = a.swap_left
		ArsenalSystem.ST_CHARGING:
			ticks_left = a.charge_left
	return {
		"id": def.id if holds else &"", "level": a.slot_level[i],
		"magazine": w.warden.magazine if active else a.slot_magazine[i], "size": def.magazine,
		"heat": a.slot_heat[i], "heat_cap": def.heat_cap, "state": state, "ticks_left": ticks_left,
	}


static func active_events(w: SimWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if w == null:
		return out
	var es: EventState = w.events_state
	for k: int in es.a_event.size():
		var index: int = es.a_event[k]
		if index < 0 or index >= w.content.events.size():
			continue
		var def: EventDef = w.content.events[index]
		var running: bool = k < es.a_phase.size() and es.a_phase[k] == EventState.PH_ACTIVE
		out.append({
			"id": def.id, "phase": 1 if running else 0,
			"ticks_left": es.a_ticks_left[k] if k < es.a_ticks_left.size() else 0,
			"ticks_total": def.duration_ticks if running else def.warn_ticks, "harmful": def.harmful,
			"x": es.a_x[k] if k < es.a_x.size() else 0.0, "z": es.a_z[k] if k < es.a_z.size() else 0.0,
		})
	return out


## The three queries below take the variety world or null (no run, legacy content) and then give the base defaults.
static func buyout_used(w: SimWorld) -> bool:
	return w != null and w.draft.open and (w.draft.bought_out or w.draft.slots_left() < 2)


static func draft_locked(w: SimWorld) -> bool:
	return w != null and w.draft.open and w.draft.reroll_locked


static func crate_status(w: SimWorld) -> Dictionary:
	if w == null or not w.salvage.crate_active:
		return {}
	var s: SalvageState = w.salvage
	var total: int = SalvageSystem.secure_ticks(w)
	return {
		"contested": SalvageSystem.is_contested(w), "ticks_left": maxi(0, total - s.crate_progress), "ticks_total": total,
		"life_left": -1 if w.mods.has_flag(&"crate_never_lost") else maxi(0, s.crate_life_left), "x": s.crate_x, "z": s.crate_z,
	}


static func build_tags(w: SimWorld) -> Dictionary:
	var out: Dictionary = {}
	if w == null:
		return out
	var tags: Dictionary[StringName, int] = DraftSystem.build_tags(w)
	for tag: StringName in tags:
		out[tag] = tags[tag]
	return out
