class_name SalvageSystem
extends RefCounted
## Crates on the field, the bank and the salvage choice (tick step 14; VARIETY_SPEC 3.4, CONTENT 2 and 7). The only
## writer of SalvageState. Contents are drawn from the stream `crate:<crate_ordinal>` when a crate is secured.
## Pushes CRATE_DROPPED, CRATE_SECURED, CRATE_LOST and SALVAGE_RESOLVED. Called every tick of a live run.
##
## On the field (during a wave only): progress rises on every tick with no living bodied enemy within the contest
## radius (minis do not contest; a stunned enemy still does); at secure_ticks x ModState.crate_time_mul the crate is
## secured. The lifetime runs in parallel; at 0 the crate is lost (never with the flag crate_never_lost).
## A secured crate is banked (at most bank_max; one more is paid out as Scrap at once).
## The intermission (PhaseSystem): `open_next` first settles what the wave left (a crate still on the field with no
## body alive is secured; the guaranteed crate after wave 2), then moves the next banked crate into `offer` and
## answers true. `resolve` applies the SALVAGE command and empties `offer`; PhaseSystem then calls `open_next` again.

## Actions of the SALVAGE command: arg = choice * 16 + action.
const ACTION_SLOT_0: int = 0
const ACTION_SLOT_1: int = 1
const ACTION_SLOT_2: int = 2
const ACTION_LEVEL_UP: int = 8
const ACTION_SCRAP: int = 9

const GUARANTEED_AFTER_WAVE: int = 2  ## CONTENT 7.1


static func step(world: SimWorld) -> void:
	var s: SalvageState = world.salvage
	if not s.crate_active or not GameState.is_combat(world.phase):
		return
	var run: RunDef = world.content.run
	if run == null:
		return
	if not world.mods.has_flag(&"crate_never_lost"):
		s.crate_life_left -= 1
	if not is_contested(world):
		s.crate_progress += 1
		if s.crate_progress >= secure_ticks(world):
			_secure_field_crate(world)
			return
	if s.crate_life_left <= 0 and not world.mods.has_flag(&"crate_never_lost"):
		s.crate_active = false
		world.events.push(SimEventKind.Id.CRATE_LOST, s.crate_ordinal)


## Lands a crate at drop point `point` (ArenaDef.drop_points). False when a crate is already on the field.
static func drop_crate(world: SimWorld, point: int, boss_crate: bool) -> bool:
	var s: SalvageState = world.salvage
	var run: RunDef = world.content.run
	var points: PackedVector2Array = world.content.arena.drop_points
	if run == null or s.crate_active or point < 0 or point >= points.size():
		return false
	s.crate_ordinal += 1
	s.crate_active = true
	s.crate_boss = boss_crate
	s.crate_point = point
	s.crate_x = points[point].x
	s.crate_z = points[point].y
	s.crate_progress = 0
	s.crate_life_left = run.salvage_lifetime_ticks
	world.events.push(SimEventKind.Id.CRATE_DROPPED, s.crate_ordinal, 1 if boss_crate else 0, s.crate_x, s.crate_z)
	return true


## Secures a crate that never lands (the guaranteed crate, a boss crate): rolled and banked at once.
static func grant_crate(world: SimWorld, boss_crate: bool) -> void:
	if world.content.run == null:
		return
	world.salvage.crate_ordinal += 1
	_secure(world, world.salvage.crate_ordinal, boss_crate)


## Opens the next banked crate for the SALVAGE await (fills SalvageState.offer). False when the bank is empty.
## Before that it settles the wave: see the class comment. Asking again while an offer is open changes nothing.
static func open_next(world: SimWorld) -> bool:
	var s: SalvageState = world.salvage
	if world.content.run == null:
		return false
	if not s.offer.is_empty():
		return true
	if s.crate_active and _bodied_alive(world) == 0:
		_secure_field_crate(world)
	if s.crates_secured == 0 and world.waves_completed >= GUARANTEED_AFTER_WAVE:
		grant_crate(world, false)
	if s.banked.is_empty():
		return false
	s.offer_boss = s.banked[0] == 1
	s.offer = PackedInt32Array()
	for k: int in SalvageState.ITEMS_PER_CRATE:
		if s.banked_items[k] >= 0:
			s.offer.append(s.banked_items[k])
	s.banked.remove_at(0)
	s.banked_items = s.banked_items.slice(SalvageState.ITEMS_PER_CRATE)
	return true


## SALVAGE: `arg` = choice * 16 + action. Returns a Reason.Id: NOT_AWAITING outside the SALVAGE await or with no open
## offer, INVALID_CHOICE for a choice or action that does not apply. Pushes SALVAGE_RESOLVED(command id, OK, arg).
## Taking a weapon into a slot scraps what was there for half of `scrap_value`; a weapon that is already carried
## can only be levelled up or scrapped.
static func resolve(world: SimWorld, command_id: int, arg: int) -> int:
	var s: SalvageState = world.salvage
	if world.phase_state.awaiting != PhaseState.Await.SALVAGE or s.offer.is_empty():
		return Reason.Id.NOT_AWAITING
	if arg < 0:
		return Reason.Id.INVALID_CHOICE
	var choice: int = arg >> 4
	var action: int = arg & 15
	if choice >= s.offer.size():
		return Reason.Id.INVALID_CHOICE
	var weapon_index: int = s.offer[choice]
	var carried: int = ArsenalSystem.slot_of(world, weapon_index)
	if action == ACTION_SCRAP:
		world.add_scrap(scrap_value(world))
	elif action == ACTION_LEVEL_UP:
		if carried < 0 or world.arsenal.slot_level[carried] >= ArsenalSystem.MAX_LEVEL:
			return Reason.Id.INVALID_CHOICE
		ArsenalSystem.level_up(world, carried)
	elif action >= ACTION_SLOT_0 and action <= ACTION_SLOT_2:
		if action >= world.arsenal.slot_count or carried >= 0:
			return Reason.Id.INVALID_CHOICE
		if world.arsenal.slot_weapon[action] >= 0:
			world.add_scrap(floori(float(scrap_value(world)) / 2.0))
		ArsenalSystem.give_weapon(world, action, weapon_index)
	else:
		return Reason.Id.INVALID_CHOICE
	s.offer = PackedInt32Array()
	s.offer_boss = false
	world.events.push(SimEventKind.Id.SALVAGE_RESOLVED, command_id, Reason.Id.OK, float(arg))
	return Reason.Id.OK


## Scrap for scrapping a crate in the current act.
static func scrap_value(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or run.salvage_scrap_by_act.is_empty():
		return 0
	return run.salvage_scrap_by_act[clampi(world.phase_state.act - 1, 0, run.salvage_scrap_by_act.size() - 1)]


## Uncontested ticks that secure a crate (secure_s x ModState.crate_time_mul).
static func secure_ticks(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null:
		return 0
	return maxi(1, roundi(float(run.salvage_secure_ticks) * world.mods.crate_time_mul))


## True while a living bodied enemy stands within the contest radius of the crate on the field.
static func is_contested(world: SimWorld) -> bool:
	var s: SalvageState = world.salvage
	var run: RunDef = world.content.run
	if run == null or not s.crate_active:
		return false
	var store: EnemyStore = world.enemies
	var r_sq: float = run.salvage_contest_radius_m * run.salvage_contest_radius_m
	for i: int in store.high_water:
		if store.alive[i] == 0 or (world.ext.flags[i] & EnemyExtState.F_MINI) != 0:
			continue
		var dx: float = store.x[i] - s.crate_x
		var dz: float = store.z[i] - s.crate_z
		if dx * dx + dz * dz <= r_sq:
			return true
	return false


## The carried slot a duplicate of `weapon_index` would level up, or -1 (not carried, or already at the top level).
static func level_up_slot(world: SimWorld, weapon_index: int) -> int:
	var slot: int = ArsenalSystem.slot_of(world, weapon_index)
	if slot >= 0 and world.arsenal.slot_level[slot] >= ArsenalSystem.MAX_LEVEL:
		return -1
	return slot


## Called by DeathHooks for every death on variety content: a boss killed by the player's side in an act that has a
## next act leaves a boss crate in the bank (CONTENT 7.1); elite kills are counted for chorus_handshake.
static func on_enemy_killed(world: SimWorld, enemy_index: int, source: int) -> void:
	if source == DeathHooks.SOURCE_SELF:
		return
	if world.ext.is_elite(enemy_index):
		world.salvage.elite_kills += 1
	if world.content.enemies[world.enemies.type[enemy_index]].is_boss and world.phase_state.act < world.content.run.acts.size():
		grant_crate(world, true)


static func _secure_field_crate(world: SimWorld) -> void:
	var s: SalvageState = world.salvage
	s.crate_active = false
	_secure(world, s.crate_ordinal, s.crate_boss)


## Rolls crate `ordinal` and banks it, or pays its Scrap value when the bank is full or nothing can be in it.
static func _secure(world: SimWorld, ordinal: int, boss_crate: bool) -> void:
	var s: SalvageState = world.salvage
	s.crates_secured += 1
	world.stats.crates_secured += 1
	world.events.push(SimEventKind.Id.CRATE_SECURED, ordinal)
	if s.banked.size() >= world.content.run.salvage_bank_max:
		world.add_scrap(scrap_value(world))
		return
	var items: PackedInt32Array = roll_contents(world, ordinal, boss_crate)
	if items.is_empty():
		world.add_scrap(scrap_value(world))
		return
	s.banked.append(1 if boss_crate else 0)
	for k: int in SalvageState.ITEMS_PER_CRATE:
		s.banked_items.append(items[k] if k < items.size() else -1)


## The weapons of crate `ordinal`, from the stream `crate:<ordinal>` (CONTENT 2): 1 weapon, 2 for a boss crate, plus
## ModState.crate_choices, all different. Each roll is, with the chance dupe_bias, a carried weapon below the top
## level (never while a slot is empty: the first crates always bring a new weapon, so no run is stuck on the pistol);
## otherwise a tier by the act's weights (a boss crate uses the next act's row) and then a weapon of that
## tier, both among the weapons that are in the pool (tier 2 and up, not locked behind an unlock the run lacks).
static func roll_contents(world: SimWorld, ordinal: int, boss_crate: bool) -> PackedInt32Array:
	var run: RunDef = world.content.run
	var rng: RandomNumberGenerator = world.rng.stream(StringName("crate:%d" % ordinal))
	var act: int = clampi(world.phase_state.act + (1 if boss_crate else 0), 1, maxi(1, run.acts.size()))
	var want: int = clampi((2 if boss_crate else 1) + roundi(world.mods.crate_choices), 1, SalvageState.ITEMS_PER_CRATE)
	var out: PackedInt32Array = PackedInt32Array()
	for _k: int in want:
		var bias_roll: float = rng.randf()
		var pick_roll: float = rng.randf()
		var dupes: PackedInt32Array = _carried_below_top(world, out)
		var picked: int = -1
		if bias_roll < run.salvage_dupe_bias and not dupes.is_empty():
			picked = dupes[mini(dupes.size() - 1, floori(pick_roll * float(dupes.size())))]
		else:
			picked = _weighted_pick(world, act, pick_roll, out)
		if picked >= 0:
			out.append(picked)
	return out


static func _carried_below_top(world: SimWorld, taken: PackedInt32Array) -> PackedInt32Array:
	var a: ArsenalState = world.arsenal
	var out: PackedInt32Array = PackedInt32Array()
	for slot: int in a.slot_count:
		if a.slot_weapon[slot] < 0:
			return PackedInt32Array()
	for slot: int in a.slot_count:
		var weapon_index: int = a.slot_weapon[slot]
		if weapon_index >= 0 and a.slot_level[slot] < ArsenalSystem.MAX_LEVEL and not taken.has(weapon_index):
			out.append(weapon_index)
	return out


## A weapon by weight: the act's tier weight, shared evenly by the pool weapons of that tier. -1 = nothing to pick.
static func _weighted_pick(world: SimWorld, act: int, roll: float, taken: PackedInt32Array) -> int:
	var run: RunDef = world.content.run
	var pool: PackedInt32Array = PackedInt32Array()
	var per_tier: Dictionary[int, int] = {}
	for def: WeaponDef in world.content.weapons:
		if taken.has(def.index) or run.tier_weight(act, def.tier) <= 0.0 or not in_pool(world, def):
			continue
		pool.append(def.index)
		per_tier[def.tier] = per_tier.get(def.tier, 0) + 1
	var total: float = 0.0
	var weights: PackedFloat64Array = PackedFloat64Array()
	for weapon_index: int in pool:
		var tier: int = world.content.weapons[weapon_index].tier
		weights.append(float(run.tier_weight(act, tier)) / float(per_tier[tier]))
		total += weights[weights.size() - 1]
	var left: float = roll * total
	for k: int in pool.size():
		left -= weights[k]
		if left < 0.0:
			return pool[k]
	return pool[pool.size() - 1] if not pool.is_empty() else -1


## True when crates of this run may hold `def`: tier 2 or higher and not granted by an unlock the run lacks.
static func in_pool(world: SimWorld, def: WeaponDef) -> bool:
	if def.tier < 2:
		return false
	for u: UnlockDef in world.content.unlocks:
		if u.grants.has(def.id) and not world.config.has_unlock(String(u.id)):
			return false
	return true


static func _bodied_alive(world: SimWorld) -> int:
	var n: int = 0
	for i: int in world.enemies.high_water:
		if world.enemies.alive[i] == 1 and (world.ext.flags[i] & EnemyExtState.F_MINI) == 0:
			n += 1
	return n
