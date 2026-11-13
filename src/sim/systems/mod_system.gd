class_name ModSystem
extends RefCounted
## The `ops[]` interpreter (VARIETY_SPEC 13.1, 13.2). The only writer of ModState; it also feeds the legacy level
## fields (`world.upgrade_levels[UP_DAMAGE | UP_FIRE_RATE | UP_ARMOR_PIERCING | UP_AUTO_TURRET]`) from the stat
## directives, so Formulas and its golden values stay the single damage path, and it is the writer of the core maximum
## and of core repairs (through SimWorld.set_core_max and set_core_hp).
##
## ModState is a pure function of (kit, held directives, wave modifier): `recompute` rebuilds it from scratch, so it is
## the same after a snapshot restore. ADD adds `value * stacks`, MUL multiplies by `value ^ stacks`, FLAG sets the bit.
## GRANT ops are one-time effects, applied by `grant` once per application of their source (a pick, the kit at tick 0,
## a reward); only `turret` is also a stat contribution (+n to `turrets`), so a re-derived ModState keeps the pad.
## A legacy world (no run definition) is never touched.

## The `hook` value of a directive that patches the plan of the remaining waves (chorus_handshake, static_pact, open_gate).
const HOOK_PLAN_PATCH: StringName = &"plan_patch"
const DEFAULT_CHARGE_CAP: int = 3
const STRIKE_EVENT: StringName = &"deadfall_strike"
const FREIGHT_EVENT: StringName = &"freight_call"


## Applies the kit of the run (SimConfig.kit_index): its stat ops now and in every recompute, its grants once.
## Called once by SimWorld._init.
static func init_world(world: SimWorld) -> void:
	if not world.content.is_variety():
		return
	recompute(world)
	var kit: KitDef = _kit(world)
	if kit != null:
		grant(world, kit.ops)


## Rebuilds ModState from the kit, the held directives (DraftState.stacks) and the wave modifier, then feeds the
## legacy level fields, the deployed turrets and the core maximum.
static func recompute(world: SimWorld) -> void:
	if not world.content.is_variety():
		return
	var m: ModState = world.mods
	m.reset()
	var kit: KitDef = _kit(world)
	if kit != null:
		apply_ops(world, kit.ops, 1)
	for def: DirectiveDef in world.content.directives:
		var held: int = world.draft.stacks_of(def.index)
		if held > 0:
			ModRules.apply_directive(world, def, held)
	var modifiers: Array[ModifierDef] = world.content.run.modifiers
	if m.wave_modifier >= 0 and m.wave_modifier < modifiers.size():
		apply_ops(world, modifiers[m.wave_modifier].ops, 1)
	ModRules.post_ops(world)
	_sync_levels(world)
	if m.has_flag(&"pads_disabled"):
		_drop_turrets(world)
	EconomySystem.sync_turrets(world, roundi(m.turrets))
	_sync_core_max(world)


## Applies `ops` `stacks` times onto ModState (ADD, MUL, FLAG). GRANT ops are one-time effects: see `grant`.
static func apply_ops(world: SimWorld, ops: Array[OpDef], stacks: int) -> void:
	var m: ModState = world.mods
	for op: OpDef in ops:
		match op.kind:
			OpDef.Kind.ADD:
				if OpDef.STATS.has(String(op.target)):
					m.set(String(op.target), m.stat(op.target) + op.value * float(stacks))
			OpDef.Kind.MUL:
				if OpDef.STATS.has(String(op.target)):
					m.set(String(op.target), m.stat(op.target) * pow(op.value, float(stacks)))
			OpDef.Kind.FLAG:
				m.set_flag(op.target, true)
			OpDef.Kind.GRANT:
				if op.target == &"turret":
					m.turrets += op.amount(world.phase_state.act) * float(stacks)


## The one-time GRANT ops of `ops` (scrap, core repair, charges, weapons, ...), in order.
static func grant(world: SimWorld, ops: Array[OpDef]) -> void:
	for op: OpDef in ops:
		if op.kind != OpDef.Kind.GRANT:
			continue
		var n: float = op.amount(world.phase_state.act)
		match op.target:
			&"scrap":
				world.add_scrap(roundi(n))
			&"core_repair":
				repair_core(world, n)
			&"core_repair_frac":
				repair_core(world, n * world.core_max_hp)
			&"free_reroll":
				DraftSystem.add_free_rerolls(world, roundi(n))
			&"event_charge":
				_grant_charge(world, op.arg, roundi(n))
			&"weapon":
				_grant_weapon(world, op.arg)
			&"directive":
				for _i: int in maxi(1, roundi(n)):
					var _granted: bool = DraftSystem.grant_stack(world, world.content.directive_index(op.arg))
			&"directive_random":
				for _i: int in maxi(1, roundi(n)):
					_grant_random_directive(world, op.arg)
			_:
				pass  # turret: a stat (apply_ops); crate and data: the salvage and reward systems


## A route reward (RewardDef index) at wave clear: its flags, then its grants. rw_rare_draft and rw_double_pick arm the
## next draft. Not called by this task's code: PhaseSystem or CoreHooks.on_wave_cleared calls it before the first await.
static func apply_reward(world: SimWorld, reward_index: int) -> void:
	var run: RunDef = world.content.run
	if run == null or reward_index < 0 or reward_index >= run.route_rewards.size():
		return
	var ops: Array[OpDef] = run.route_rewards[reward_index].ops
	apply_ops(world, ops, 1)
	for op: OpDef in ops:
		if op.kind != OpDef.Kind.FLAG:
			continue
		if op.target == &"next_draft_rare":
			DraftSystem.arm_next_rare(world)
		elif op.target == &"next_draft_double":
			DraftSystem.arm_next_double(world)
	grant(world, ops)


## Sets the modifier of the wave that starts (-1 = none), recomputes, and applies what a wave start brings: the
## Deadfall and Freight charges of `strike_per_act` / `freight_per_act` at the first wave of an act, and the offline
## time of mod_low_power (PhaseAwaits.begin_wave calls this after ACT_STARTED and before EventSystem.begin_wave).
static func set_wave_modifier(world: SimWorld, modifier_index: int) -> void:
	if not world.content.is_variety():
		return
	var valid: bool = modifier_index >= 0 and modifier_index < world.content.run.modifiers.size()
	world.mods.wave_modifier = modifier_index if valid else -1
	recompute(world)
	if is_act_start(world):
		_grant_charge(world, STRIKE_EVENT, roundi(world.mods.strike_per_act))
		_grant_charge(world, FREIGHT_EVENT, roundi(world.mods.freight_per_act))
	var offline: int = roundi(world.mods.turret_offline_ticks)
	if offline > world.events_state.turret_offline_ticks:
		world.events_state.turret_offline_ticks = offline


## True when `world.wave` is the first wave of its act (wave 1, or the act differs from the wave before).
static func is_act_start(world: SimWorld) -> bool:
	var run: RunDef = world.content.run
	var slot: WaveSlotDef = run.wave_slot(world.wave) if run != null else null
	if slot == null:
		return false
	if world.wave <= 1:
		return true
	var before: WaveSlotDef = run.wave_slot(world.wave - 1)
	return before != null and before.act != slot.act


## Adds one stack of directive `def` (already counted in DraftState.stacks): its one-time reactions, the recompute, the
## charges a per-act stat adds right away (deadfall_uplink, signal_hijack) and its GRANT ops. DraftSystem calls this.
static func on_directive_added(world: SimWorld, def: DirectiveDef) -> void:
	var strike_before: float = world.mods.strike_per_act
	var freight_before: float = world.mods.freight_per_act
	ModRules.on_picked(world, def)
	recompute(world)
	_grant_charge(world, STRIKE_EVENT, roundi(world.mods.strike_per_act - strike_before))
	_grant_charge(world, FREIGHT_EVENT, roundi(world.mods.freight_per_act - freight_before))
	grant(world, def.ops)


## Repairs the core by up to `amount` (never above the maximum); pushes CORE_HEALED. Returns what was repaired.
static func repair_core(world: SimWorld, amount: float) -> float:
	var healed: float = clampf(amount, 0.0, world.core_max_hp - world.core_hp)
	if healed <= 0.0:
		return 0.0
	world.set_core_hp(world.core_hp + healed)
	world.events.push(SimEventKind.Id.CORE_HEALED, 0, 0, healed, world.core_hp)
	return healed


static func _kit(world: SimWorld) -> KitDef:
	var kits: Array[KitDef] = world.content.kits
	var i: int = world.config.kit_index
	return kits[i] if i >= 0 and i < kits.size() else null


## The legacy level fields follow the stat directives: UP_DAMAGE, UP_FIRE_RATE, UP_ARMOR_PIERCING.
static func _sync_levels(world: SimWorld) -> void:
	var m: ModState = world.mods
	_set_level(world, Ids.UP_DAMAGE, roundi(m.lvl_damage))
	_set_level(world, Ids.UP_FIRE_RATE, roundi(m.lvl_fire_rate))
	_set_level(world, Ids.UP_ARMOR_PIERCING, roundi(m.lvl_armor_piercing))


static func _set_level(world: SimWorld, upgrade_index: int, level: int) -> void:
	var now: int = maxi(0, level)
	if world.upgrade_levels[upgrade_index] == now:
		return
	world.upgrade_levels[upgrade_index] = now
	world.events.push(SimEventKind.Id.UPGRADE_LEVEL_CHANGED, upgrade_index, now)


## Core maximum = (mission maximum + core_max_add) * core_max_mul, rounded. A smaller maximum scales the current hp with
## it (glass_cannon: the same fraction of a smaller core); a larger one keeps it (the repair is a grant of its own).
static func _sync_core_max(world: SimWorld) -> void:
	var m: ModState = world.mods
	var target: float = maxf(1.0, float(roundi((world.content.mission.core_max_hp + m.core_max_add) * m.core_max_mul)))
	if target == world.core_max_hp:
		return
	if target < world.core_max_hp:
		world.set_core_hp(world.core_hp * target / world.core_max_hp)
	world.set_core_max(target)


## +n charges of the player event `event_id`, up to its charge_cap. Interim: EventState is written here until
## EventSystem gets an add-charge function of its own.
static func _grant_charge(world: SimWorld, event_id: StringName, n: int) -> void:
	if n == 0:
		return
	var index: int = world.content.event_index(event_id)
	var es: EventState = world.events_state
	if index < 0 or index >= es.charges.size():
		return
	var cap: int = roundi(world.content.events[index].param(&"charge_cap", float(DEFAULT_CHARGE_CAP)))
	var now: int = clampi(es.charges[index] + n, 0, cap)
	if now == es.charges[index]:
		return
	es.charges[index] = now
	world.events.push(SimEventKind.Id.CHARGES_CHANGED, index, now)


## single_point: every turret is removed (the pads are disabled by the flag, so none comes back).
static func _drop_turrets(world: SimWorld) -> void:
	for pad: int in world.turrets.active.size():
		world.turrets.active[pad] = 0


## The weapon `weapon_id` into the first empty slot (ArsenalSystem does the rest); nothing when every slot is taken.
static func _grant_weapon(world: SimWorld, weapon_id: StringName) -> void:
	var weapon_index: int = Ids.weapon_index(weapon_id)
	if weapon_index < 0 or weapon_index >= world.content.weapons.size():
		return
	var a: ArsenalState = world.arsenal
	for slot: int in mini(a.slot_count, a.slot_weapon.size()):
		if a.slot_weapon[slot] < 0:
			ArsenalSystem.give_weapon(world, slot, weapon_index)
			return


## One uniformly random candidate of the rarity named `rarity_name` (k_gambler), drawn from the `kit` stream.
static func _grant_random_directive(world: SimWorld, rarity_name: StringName) -> void:
	var rarity: int = DirectiveDef.RARITY_NAMES.find(String(rarity_name))
	if rarity < 0:
		return
	var cand: Array[int] = []
	for index: int in DraftOffer.candidates(world):
		if world.content.directives[index].rarity == rarity:
			cand.append(index)
	if cand.is_empty():
		return
	var rng: RandomNumberGenerator = world.rng.stream(&"kit")
	var pick: int = mini(cand.size() - 1, floori(rng.randf() * float(cand.size())))
	var _granted: bool = DraftSystem.grant_stack(world, cand[pick])
