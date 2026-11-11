class_name HarnessChecker
extends RefCounted
## Watches a whole run through the real `world.step()` and records every broken invariant instead of stopping at
## the first one (so a sweep reports all of them). Feed it each tick's drained events right after the step:
## `after_step(world, events)`, then call `finish(world, commands_submitted)` once. Findings are in `violations`.
##
## Per tick: the 50 enemy cap and the store high-water mark, finite positions, no enemy during an INTERMISSION, a
## wave in CLEARING is fully spawned, spawned + pending + not-yet-due == scheduled, no wave clear (or VICTORY)
## while anything is alive or queued, the core never heals, the shield is never negative or alive without its
## ability. Per event: Scrap equals the sum of kill rewards, a kill happens once per enemy, every purchase command
## is answered once and a success debits exactly its price, every ability command is answered, RUN_FINISHED once.

const MAX_VIOLATIONS: int = 24

var violations: PackedStringArray = PackedStringArray()
var purchases_ok: int = 0
var purchases_by_upgrade: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var abilities_used: PackedInt32Array = PackedInt32Array([0, 0, 0])
var spawned: int = 0
var killed: int = 0
var stuck_events: int = 0
## Tick the boss entered and the tick it died (-1 = never).
var boss_spawn_tick: int = -1
var boss_kill_tick: int = -1
var finished_events: int = 0
var reward_sum: int = 0
var spent_expected: int = 0
## Per wave (index 0 = before wave 1, then 1..5): core integrity lost and Scrap earned by kills.
var core_lost_by_wave: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var scrap_by_wave: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
## Successful purchases in order: tick, wave (world.wave then), upgrade index.
var buy_ticks: PackedInt32Array = PackedInt32Array()
var buy_waves: PackedInt32Array = PackedInt32Array()
var buy_upgrades: PackedInt32Array = PackedInt32Array()

var _type_of: Dictionary[int, int] = {}
var _killed_ids: Dictionary[int, bool] = {}
var _resolved: Dictionary[int, int] = {}
var _levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var _purchase_events: int = 0
var _ability_events: int = 0
var _wave_total: int = 0
var _wave_spawned: int = 0
var _last_core: float = 0.0
var _start_scrap: int = 0


func _init(world: SimWorld) -> void:
	_last_core = world.core_hp
	_start_scrap = world.scrap


func after_step(world: SimWorld, events: Array[SimEvent]) -> void:
	for e: SimEvent in events:
		_event(world, e)
	_state(world)


## End-of-run totals. `commands_submitted` is what the bot (or test) handed to world.submit.
func finish(world: SimWorld, commands_submitted: int) -> void:
	var stats: RunStats = world.stats
	if stats.scrap_earned != reward_sum:
		_bad(world, "Scrap earned %d != sum of kill rewards %d" % [stats.scrap_earned, reward_sum])
	if world.scrap != _start_scrap + stats.scrap_earned - stats.scrap_spent:
		_bad(world, "scrap %d != start + earned - spent" % world.scrap)
	if stats.scrap_spent != spent_expected:
		_bad(world, "Scrap spent %d != price of the %d successful purchases (%d)" % [stats.scrap_spent, purchases_ok, spent_expected])
	var level_sum: int = 0
	for level: int in world.upgrade_levels:
		level_sum += level
	if level_sum != purchases_ok:
		_bad(world, "upgrade levels add up to %d but %d purchases succeeded" % [level_sum, purchases_ok])
	if world.command_log.entries.size() != commands_submitted:
		_bad(world, "%d commands submitted, %d applied and logged" % [commands_submitted, world.command_log.entries.size()])
	var purchase_cmds: int = 0
	var ability_cmds: int = 0
	for c: SimCommand in world.command_log.entries:
		if c.kind == SimCommand.Kind.PURCHASE:
			purchase_cmds += 1
		elif c.kind == SimCommand.Kind.ABILITY:
			ability_cmds += 1
	if purchase_cmds != _purchase_events:
		_bad(world, "%d purchase commands logged, %d answered" % [purchase_cmds, _purchase_events])
	if ability_cmds != _ability_events:
		_bad(world, "%d ability commands logged, %d answered" % [ability_cmds, _ability_events])
	if world.is_over():
		if finished_events != 1:
			_bad(world, "RUN_FINISHED pushed %d times" % finished_events)
		if world.phase == GameState.Id.DEFEAT and world.core_hp > 0.0:
			_bad(world, "DEFEAT with core_hp %.1f" % world.core_hp)
		if world.phase == GameState.Id.VICTORY:
			_check_victory(world)
	elif finished_events != 0:
		_bad(world, "RUN_FINISHED pushed in a live run")


func _check_victory(world: SimWorld) -> void:
	var total: int = 0
	for w: WaveDef in world.content.waves:
		total += w.total_count()
	if spawned != total or killed != total:
		_bad(world, "VICTORY with %d spawned and %d killed of %d scheduled" % [spawned, killed, total])
	if world.waves_completed != world.content.waves.size() or world.alive_count() != 0:
		_bad(world, "VICTORY with %d waves completed and %d alive" % [world.waves_completed, world.alive_count()])
	if world.core_hp <= 0.0:
		_bad(world, "VICTORY with a dead core")


func _event(world: SimWorld, e: SimEvent) -> void:
	match e.kind:
		SimEventKind.Id.WAVE_STARTED:
			_wave_total = e.b
			_wave_spawned = 0
		SimEventKind.Id.BOSS_SPAWNED:
			boss_spawn_tick = world.tick
		SimEventKind.Id.ENEMY_SPAWNED:
			spawned += 1
			_wave_spawned += 1
			if _type_of.has(e.a):
				_bad(world, "enemy id %d spawned twice" % e.a)
			_type_of[e.a] = e.b
		SimEventKind.Id.ENEMY_KILLED:
			killed += 1
			if _killed_ids.has(e.a):
				_bad(world, "enemy id %d killed twice" % e.a)
			_killed_ids[e.a] = true
			if not _type_of.has(e.a):
				_bad(world, "enemy id %d killed but never spawned" % e.a)
			else:
				var reward: int = world.content.enemies[_type_of[e.a]].scrap
				reward_sum += reward
				if world.content.enemies[_type_of[e.a]].is_boss:
					boss_kill_tick = world.tick
				scrap_by_wave[clampi(world.wave, 0, 5)] += reward
		SimEventKind.Id.WAVE_CLEARED:
			_wave_cleared(world, e.a)
		SimEventKind.Id.PURCHASE_RESOLVED:
			_purchase(world, e)
		SimEventKind.Id.ABILITY_ACTIVATED:
			_ability_events += 1
			if e.a >= 0 and e.a < abilities_used.size():
				abilities_used[e.a] += 1
		SimEventKind.Id.ABILITY_REJECTED:
			_ability_events += 1
		SimEventKind.Id.ENEMY_STUCK:
			stuck_events += 1
		SimEventKind.Id.RUN_FINISHED:
			finished_events += 1
		_:
			pass


func _purchase(world: SimWorld, e: SimEvent) -> void:
	_purchase_events += 1
	_resolved[e.a] = _resolved.get(e.a, 0) + 1
	if e.a > 0 and _resolved[e.a] > 1 and e.b == Reason.Id.OK:
		_bad(world, "purchase command %d succeeded after being answered before" % e.a)
	if e.b != Reason.Id.OK:
		return
	var up: int = roundi(e.f)
	if up < 0 or up >= _levels.size():
		_bad(world, "purchase of unknown upgrade %d succeeded" % up)
		return
	var def: UpgradeDef = world.content.upgrades[up]
	spent_expected += Formulas.upgrade_cost(def.base_cost, def.growth, _levels[up])
	_levels[up] += 1
	purchases_ok += 1
	purchases_by_upgrade[up] += 1
	buy_ticks.append(world.tick)
	buy_waves.append(world.wave)
	buy_upgrades.append(up)


func _wave_cleared(world: SimWorld, wave: int) -> void:
	if world.alive_count() != 0:
		_bad(world, "wave %d cleared with %d enemies alive" % [wave, world.alive_count()])
	if SpawnSystem.pending_count(world) != 0 or not SpawnSystem.is_wave_fully_spawned(world):
		_bad(world, "wave %d cleared with spawns still scheduled or queued" % wave)
	if _wave_spawned != _wave_total:
		_bad(world, "wave %d cleared with %d spawned of %d scheduled" % [wave, _wave_spawned, _wave_total])


func _state(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var cap: int = world.content.mission.enemy_cap
	var alive: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		alive += 1
		if not (is_finite(store.x[i]) and is_finite(store.z[i]) and is_finite(store.hp[i])):
			_bad(world, "enemy id %d has a non-finite position or hp" % store.id[i])
	if alive > cap:
		_bad(world, "%d enemies alive, cap %d" % [alive, cap])
	if store.high_water > store.capacity:
		_bad(world, "store high_water %d above capacity %d" % [store.high_water, store.capacity])
	var nav: NavState = world.nav
	if nav.wave_begun > 0:
		var due_later: int = nav.sched_due.size() - nav.sched_next
		if _wave_spawned + nav.pending_count() + due_later != _wave_total:
			_bad(world, "spawned %d + pending %d + not due %d != scheduled %d" % [_wave_spawned, nav.pending_count(), due_later, _wave_total])
	if world.phase == GameState.Id.INTERMISSION and alive != 0:
		_bad(world, "%d enemies alive during an intermission" % alive)
	if world.phase == GameState.Id.CLEARING and not SpawnSystem.is_wave_fully_spawned(world):
		_bad(world, "CLEARING while spawns are still scheduled or queued")
	if world.core_hp > _last_core:
		_bad(world, "core healed %.1f -> %.1f" % [_last_core, world.core_hp])
	else:
		core_lost_by_wave[clampi(world.wave, 0, 5)] += _last_core - world.core_hp
	_last_core = world.core_hp
	if world.shield_hp < 0.0:
		_bad(world, "negative shield %.1f" % world.shield_hp)
	if world.shield_hp > 0.0 and not world.abilities.is_active(Ids.AB_SHIELD):
		_bad(world, "shield %.1f up without the ability active" % world.shield_hp)


func _bad(world: SimWorld, text: String) -> void:
	if violations.size() < MAX_VIOLATIONS:
		violations.append("t%d: %s" % [world.tick, text])
