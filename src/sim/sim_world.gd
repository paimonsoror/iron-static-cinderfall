class_name SimWorld
extends RefCounted
## The whole simulation state and the fixed tick (ARCH 6.2). Pure RefCounted code: no nodes, no clocks,
## no global randomness. Same seed plus the same ordered commands gives the same state_hash().

const TICK_RATE: int = 60
const DT: float = 1.0 / 60.0

var config: SimConfig
var content: ContentSet  ## == config.content
var tick: int = 0
var phase: int = GameState.Id.PREPARING
var wave: int = 0  ## 0 while PREPARING, then 1..5
var waves_completed: int = 0
var phase_ticks_left: int = 0  ## countdown in PREPARING and INTERMISSION, else 0
var core_hp: float
var core_max_hp: float
var shield_hp: float = 0.0  ## > 0 only while the shield ability is active
var scrap: int = 0
var upgrade_levels: PackedInt32Array = PackedInt32Array()  ## size 5, indexed by Ids.UP_*
var enemies: EnemyStore
var turrets: TurretStore
var warden: WardenState
var abilities: AbilityState
var nav: NavState  ## owned by nav systems
var combat: CombatState  ## owned by combat systems
var phase_state: PhaseState  ## owned by flow systems
var rng: SimRng
var events: SimEvents
var stats: RunStats
var command_log: CommandLog
var next_enemy_id: int = 1
## Commands submitted and not yet applied (CommandSystem.apply_queued consumes it). Additive to ARCH 6.2.
var command_queue: Array[SimCommand] = []
# --- variety milestone (VARIETY_SPEC 13.2): one writer per state class, the system of the same name ---
var plan: RunPlan  ## null in the legacy content (SpawnSystem then reads content.waves)
var mods: ModState
var arsenal: ArsenalState
var draft: DraftState
var salvage: SalvageState
var ext: EnemyExtState  ## parallel to `enemies` by store index
var hazards: HazardState
var events_state: EventState
var boss: BossState


func _init(cfg: SimConfig) -> void:
	config = cfg
	content = cfg.content
	core_max_hp = content.mission.core_max_hp
	core_hp = core_max_hp
	scrap = cfg.debug_start_scrap
	upgrade_levels.resize(Ids.UPGRADES.size())
	enemies = EnemyStore.new(content.mission.enemy_cap + content.mission.swarm_cap + 8)
	turrets = TurretStore.new(content.arena.turret_pads.size())
	for p: int in content.arena.turret_pads.size():
		turrets.x[p] = content.arena.turret_pads[p].x
		turrets.z[p] = content.arena.turret_pads[p].y
	warden = WardenState.new()
	warden.x = content.arena.warden_x
	warden.z = content.arena.warden_z
	warden.aim_x = warden.x + 1.0
	warden.aim_z = warden.z
	warden.magazine = content.weapons[0].magazine
	abilities = AbilityState.new()
	nav = NavState.new()
	combat = CombatState.new()
	phase_state = PhaseState.new()
	rng = SimRng.new(cfg.run_seed)
	events = SimEvents.new()
	stats = RunStats.new()
	stats.setup(content)
	command_log = CommandLog.new()
	mods = ModState.new()
	arsenal = ArsenalState.new()
	draft = DraftState.new(content.directives.size())
	salvage = SalvageState.new()
	ext = EnemyExtState.new(enemies.capacity)
	hazards = HazardState.new()
	events_state = EventState.new(content.events.size())
	boss = BossState.new()
	NavSystemHooks.init_world(self)
	PhaseSystem.init_world(self)
	ModSystem.init_world(self)
	ArsenalSystem.init_world(self)
	EventSystem.init_world(self)
	plan = RunPlanSystem.build(self)
	DebugStart.apply(self)


## Exactly one tick; a no-op once the run is over. Order is fixed (ARCH 6.2, extended by VARIETY_SPEC 13.2).
## While the run awaits a choice (PhaseState.awaiting) the tick does not advance: a call with an empty queue does
## nothing, and a call with queued commands advances one tick, applies them and stops again if still awaiting. So the
## tick count of a run depends on the seed and the decisions only, never on thinking time.
## The systems added by the variety milestone (Event, Status, Hazard, Boss, Salvage) are called on every tick of a live
## run and gate on the phase themselves; the legacy systems keep their gates.
func step() -> void:
	if is_over():
		return
	if phase_state.awaiting != PhaseState.Await.NONE and command_queue.is_empty():
		return
	tick += 1
	events.current_tick = tick
	CommandSystem.apply_queued(self)
	if phase_state.awaiting != PhaseState.Await.NONE:
		return
	PhaseSystem.pre_step(self)
	var live: bool = not GameState.is_terminal(phase)
	if live:
		EventSystem.step(self)
	if GameState.is_combat(phase):
		SpawnSystem.step(self)
	if live:
		AbilitySystem.step(self)
		StatusSystem.step(self)
	if GameState.is_combat(phase):
		MovementSystem.step(self)
		WeaponSystem.step(self)
		TurretSystem.step(self)
	if live:
		HazardSystem.step(self)
	if GameState.is_combat(phase):
		CoreAttackSystem.step(self)
	if live:
		BossSystem.step(self)
		SalvageSystem.step(self)
	PhaseSystem.post_step(self)
	stats.sample(self)


## Queue a command for the next tick.
func submit(cmd: SimCommand) -> void:
	command_queue.append(cmd)


func is_over() -> bool:
	return GameState.is_terminal(phase)


func result() -> int:
	if phase == GameState.Id.VICTORY:
		return RunResult.Id.VICTORY
	if phase == GameState.Id.DEFEAT:
		return RunResult.Id.DEFEAT
	return RunResult.Id.NONE


## sha256 hex over all sim state, in a fixed order.
func state_hash() -> String:
	var h: StateHasher = StateHasher.new()
	h.put_int(tick)
	h.put_int(phase)
	h.put_int(wave)
	h.put_int(waves_completed)
	h.put_int(phase_ticks_left)
	h.put_float(core_hp)
	h.put_float(core_max_hp)
	h.put_float(shield_hp)
	h.put_int(scrap)
	h.put_ints(upgrade_levels)
	h.put_int(next_enemy_id)
	enemies.hash_into(h)
	turrets.hash_into(h)
	warden.hash_into(h)
	abilities.hash_into(h)
	nav.hash_into(h)
	combat.hash_into(h)
	phase_state.hash_into(h)
	rng.hash_into(h)
	h.put_int(1 if plan != null else 0)
	if plan != null:
		plan.hash_into(h)
	mods.hash_into(h)
	arsenal.hash_into(h)
	draft.hash_into(h)
	salvage.hash_into(h)
	ext.hash_into(h)
	hazards.hash_into(h)
	events_state.hash_into(h)
	boss.hash_into(h)
	return h.finish()


func summary(run_id: String) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = run_id
	s.run_seed = config.run_seed
	s.result = result()
	s.waves_completed = waves_completed
	s.core_hp = floori(core_hp)
	s.core_max_hp = floori(core_max_hp)
	s.duration_ticks = tick
	s.kills_by_type = stats.kills_by_type.duplicate()
	s.peak_alive_by_wave = stats.peak_alive_by_wave.duplicate()
	s.scrap_earned = stats.scrap_earned
	s.scrap_spent = stats.scrap_spent
	s.data_reward = data_reward()
	s.act_reached = stats.act_reached
	s.combat_ticks = stats.combat_ticks
	s.directives = draft.stacks.duplicate()
	s.weapons = arsenal.slot_weapon.duplicate()
	s.route_choices = stats.route_choices.duplicate()
	s.core_damage_by_type = stats.core_damage_by_type.duplicate()
	s.damage_by_source = combat.damage_by_source.duplicate()
	s.events_seen = stats.events_seen.duplicate()
	s.crates_secured = stats.crates_secured
	s.boss_ids = stats.boss_ids.duplicate()
	return s


## The Recovered Data the run is worth now. A generated run pays the table of CONTENT 10: what RunStats.data banked
## (waves cleared, act bosses, `rw_data`, data_siphon) plus, for a victory, victory_base + floor(victory_core_bonus x
## core / core max). An unfinished run is worth what it banked (a run that cannot be resumed is closed with it). The
## legacy content keeps Formulas.data_reward.
func data_reward() -> int:
	if content.run == null:
		return Formulas.data_reward(result(), waves_completed, core_hp, content.mission)
	var total: int = stats.data
	if phase == GameState.Id.VICTORY:
		var frac: float = clampf(core_hp / maxf(1.0, core_max_hp), 0.0, 1.0)
		total += content.run.reward_victory_base + floori(float(content.run.reward_victory_core_bonus) * frac)
	return total


# --- shared mutators: the ONLY way these things may change ---


## Validates via GameStateMachine.can_transition; illegal changes are ignored. Pushes PHASE_CHANGED.
func set_phase(new_phase: int) -> void:
	if new_phase == GameState.Id.PAUSED or not GameState.is_run_phase(new_phase):
		return
	if not GameStateMachine.can_transition(phase, new_phase):
		return
	var previous: int = phase
	phase = new_phase
	events.push(SimEventKind.Id.PHASE_CHANGED, previous, new_phase)


## Clamps at 0; pushes SCRAP_CHANGED(new value, applied delta); updates stats. No event when nothing changes.
func add_scrap(delta: int) -> void:
	var new_value: int = maxi(0, scrap + delta)
	var applied: int = new_value - scrap
	if applied == 0:
		return
	scrap = new_value
	if applied > 0:
		stats.scrap_earned += applied
	else:
		stats.scrap_spent += -applied
	events.push(SimEventKind.Id.SCRAP_CHANGED, new_value, applied)


## Store index, or -1 at capacity. Pushes ENEMY_SPAWNED (+ BOSS_SPAWNED). The enemy faces the core.
## Variety content also returns -1 when the enemy's class (bodied or mini), its type or, for `affix_mask` != 0, the
## elite cap is full (VARIETY_SPEC 5.5); the caller keeps the spawn queued. `affix_mask` makes the enemy an elite.
func spawn_enemy(type_index: int, x: float, z: float, affix_mask: int = 0) -> int:
	var def: EnemyDef = content.enemies[type_index]
	if content.run != null and not _has_room(def, affix_mask != 0):
		return -1
	var i: int = enemies.alloc()
	if i < 0:
		return -1
	ext.reset(i)
	if def.is_mini():
		ext.flags[i] = EnemyExtState.F_MINI
	var enemy_id: int = next_enemy_id
	next_enemy_id += 1
	enemies.id[i] = enemy_id
	enemies.type[i] = type_index
	enemies.x[i] = x
	enemies.z[i] = z
	enemies.prev_x[i] = x
	enemies.prev_z[i] = z
	var dx: float = content.arena.core_x - x
	var dz: float = content.arena.core_z - z
	var d: float = sqrt(dx * dx + dz * dz)
	if d > 0.0001:
		enemies.face_x[i] = dx / d
		enemies.face_z[i] = dz / d
	var hp: float = EliteSystem.spawn_hp(self, def, affix_mask)
	enemies.hp[i] = hp
	enemies.max_hp[i] = hp
	enemies.state[i] = EnemyStore.ST_MOVING
	enemies.spawn_tick[i] = tick
	events.push(SimEventKind.Id.ENEMY_SPAWNED, enemy_id, type_index, x, z)
	if def.is_boss:
		events.push(SimEventKind.Id.BOSS_SPAWNED, enemy_id, type_index)
		if not stats.boss_ids.has(type_index):
			stats.boss_ids.append(type_index)  # one entry per boss type of the run, in spawn order
		BossSystem.on_spawned(self, i)
	if affix_mask != 0:
		ext.flags[i] |= EnemyExtState.F_ELITE
		ext.affix_mask[i] = affix_mask
		EliteSystem.apply(self, i, affix_mask)
	return i


## Room under the caps of VARIETY_SPEC 5.5: bodied enemies (the store kept 8 spare rows above enemy_cap before the
## variety milestone, and still does), minis (swarm_cap), the type's alive_cap, and elites alive.
func _has_room(def: EnemyDef, elite: bool) -> bool:
	var mini: bool = def.is_mini()
	var of_class: int = 0
	var of_type: int = 0
	var elites: int = 0
	for j: int in enemies.high_water:
		if enemies.alive[j] == 0:
			continue
		if ext.has_flag(j, EnemyExtState.F_MINI) == mini:
			of_class += 1
		if enemies.type[j] == def.index:
			of_type += 1
		if ext.is_elite(j):
			elites += 1
	if of_class >= (content.mission.swarm_cap if mini else content.mission.enemy_cap + 8):
		return false
	if def.alive_cap > 0 and of_type >= def.alive_cap:
		return false
	return not elite or elites < content.run.max_elites_alive


## Exactly once: a no-op if the slot is not alive. Pays Scrap, counts the kill, pushes ENEMY_KILLED,
## releases the attack slot, frees the store slot.
func kill_enemy(index: int, source: int) -> void:
	if index < 0 or index >= enemies.capacity or enemies.alive[index] == 0:
		return
	var type_index: int = enemies.type[index]
	add_scrap(DeathHooks.scrap_for(self, index, source))
	stats.kills_by_type[type_index] += 1
	events.push(SimEventKind.Id.ENEMY_KILLED, enemies.id[index], source, enemies.x[index], enemies.z[index])
	DeathHooks.on_killed(self, index, source)
	NavSystemHooks.on_enemy_removed(self, index)
	enemies.free_index(index)


## Clamps to 0..max; pushes CORE_CHANGED(current, max).
func set_core_hp(value: float) -> void:
	core_hp = clampf(value, 0.0, core_max_hp)
	events.push(SimEventKind.Id.CORE_CHANGED, 0, 0, core_hp, core_max_hp)


## Changes the core maximum (never below 1) and clamps the current value; pushes CORE_CHANGED(current, max).
func set_core_max(value: float) -> void:
	core_max_hp = maxf(1.0, value)
	set_core_hp(core_hp)


# --- read-only queries ---


func alive_count() -> int:
	return enemies.alive_count()


## Cost of the next level, or -1 at max level.
func upgrade_cost(upgrade_index: int) -> int:
	if upgrade_index < 0 or upgrade_index >= content.upgrades.size():
		return -1
	var u: UpgradeDef = content.upgrades[upgrade_index]
	var level: int = upgrade_levels[upgrade_index]
	if level >= u.max_level:
		return -1
	return Formulas.upgrade_cost(u.base_cost, u.growth, level)


func purchase_block_reason(upgrade_index: int) -> int:
	return EconomySystem.block_reason(self, upgrade_index)


func ability_block_reason(ability_index: int) -> int:
	return AbilitySystem.block_reason(self, ability_index)


## Store index of the living boss, or -1.
func boss_store_index() -> int:
	for i: int in enemies.high_water:
		if enemies.alive[i] == 1 and content.enemies[enemies.type[i]].is_boss:
			return i
	return -1
