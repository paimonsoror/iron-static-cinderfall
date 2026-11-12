class_name PolicyBot
extends RefCounted
## Scripted player for headless runs and balance work (ARCH 6.7). A pure function of what it can read from the
## world: it never touches sim state and talks to the sim only through `world.submit`, so every run it plays is
## recorded in the CommandLog and replays exactly (`Replay.run`). Call `act` once per tick, before `world.step()`.
##
## NONE   never submits anything (the "bot that buys nothing" of GDD 8.4).
## GREEDY buys, once per tick at most, the cheapest upgrade that `purchase_block_reason` says is buyable right now
##        (state, level, wave lock and funds all pass); equal prices go by the fixed order in PRIORITY. It never
##        saves up for something dearer. Abilities on simple triggers:
##          EMP        when at least EMP_ATTACKERS enemies are attacking the core,
##          shield     when the core lost integrity since the last call (it is being hit),
##          overdrive  when the boss is alive and inside the Warden's weapon range.

## Append only. The six policies after GREEDY are the variety bots (VARIETY_SPEC 14.1; one file each under
## src/sim/ai/policy_*.gd); until V2-H and V4-T wire them into `act` they submit nothing, like NONE.
enum Policy { NONE, GREEDY, RANDOM, HOARDER, SPAMMER, TURRET_RUSH, BALANCED, RISK }

## Enemies standing at the core that make GREEDY fire the EMP.
const EMP_ATTACKERS: int = 12
## Tie-break order for equal prices: weapon first, then the stats, turret last.
const PRIORITY: Array[int] = [Ids.UP_SMG, Ids.UP_DAMAGE, Ids.UP_FIRE_RATE, Ids.UP_ARMOR_PIERCING, Ids.UP_AUTO_TURRET]

var policy: int = Policy.NONE
## Commands submitted so far; by default the ids are 1, 2, 3, ... (unique per run, as the sim requires).
var commands_submitted: int = 0
## Optional `func() -> int` that mints each command id instead of the private counter. `Game` points it at
## `RunApi.next_command_id`, so a bot and a human tapping the HUD during the same run (--autoplay keeps the HUD up)
## draw from ONE counter. Two counters would repeat ids, and the sim answers a repeated id with DUPLICATE_COMMAND:
## a human's purchase or ability tap, or the bot's own, would be dropped silently (a repeated skip is dropped for good).
var id_source: Callable = Callable()

var _last_core_hp: float = -1.0


func _init(policy_value: int) -> void:
	policy = policy_value


## Submits commands for the next tick. Deterministic; does nothing for NONE or once the run is over.
func act(world: SimWorld) -> void:
	if policy != Policy.GREEDY or world.is_over():
		return
	_buy(world)
	_use_abilities(world)
	_last_core_hp = world.core_hp


## The cheapest buyable upgrade, ties by PRIORITY; -1 when nothing can be bought now.
func pick_purchase(world: SimWorld) -> int:
	var best: int = -1
	var best_cost: int = 0
	for upgrade: int in PRIORITY:
		if world.purchase_block_reason(upgrade) != Reason.Id.OK:
			continue
		var cost: int = world.upgrade_cost(upgrade)
		if best < 0 or cost < best_cost:
			best = upgrade
			best_cost = cost
	return best


func _buy(world: SimWorld) -> void:
	var upgrade: int = pick_purchase(world)
	if upgrade >= 0:
		_submit(world, SimCommand.Kind.PURCHASE, upgrade)


func _use_abilities(world: SimWorld) -> void:
	if world.ability_block_reason(Ids.AB_EMP) == Reason.Id.OK and attackers(world) >= EMP_ATTACKERS:
		_submit(world, SimCommand.Kind.ABILITY, Ids.AB_EMP)
	var core_hit: bool = _last_core_hp >= 0.0 and world.core_hp < _last_core_hp
	if core_hit and world.ability_block_reason(Ids.AB_SHIELD) == Reason.Id.OK:
		_submit(world, SimCommand.Kind.ABILITY, Ids.AB_SHIELD)
	if world.ability_block_reason(Ids.AB_OVERDRIVE) == Reason.Id.OK and boss_in_range(world):
		_submit(world, SimCommand.Kind.ABILITY, Ids.AB_OVERDRIVE)


## Enemies standing in an attack slot (ST_ATTACKING).
func attackers(world: SimWorld) -> int:
	var store: EnemyStore = world.enemies
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 1 and store.state[i] == EnemyStore.ST_ATTACKING:
			n += 1
	return n


## The boss is alive and the Warden's current weapon reaches it.
func boss_in_range(world: SimWorld) -> bool:
	var i: int = world.boss_store_index()
	if i < 0:
		return false
	var dx: float = world.enemies.x[i] - world.warden.x
	var dz: float = world.enemies.z[i] - world.warden.z
	var reach: float = world.content.weapons[world.warden.weapon_index].range_m
	return dx * dx + dz * dz <= reach * reach


func _submit(world: SimWorld, kind: int, arg: int) -> void:
	commands_submitted += 1
	var command_id: int = commands_submitted
	if id_source.is_valid():
		var minted: Variant = id_source.call()
		command_id = minted
	match kind:
		SimCommand.Kind.PURCHASE:
			world.submit(SimCommand.purchase(command_id, arg))
		SimCommand.Kind.ABILITY:
			world.submit(SimCommand.ability(command_id, arg))
		_:
			world.submit(SimCommand.skip(command_id))
