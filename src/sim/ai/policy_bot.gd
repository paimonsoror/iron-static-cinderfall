class_name PolicyBot
extends RefCounted
## Scripted player for headless runs and balance work (ARCH 6.7, VARIETY_SPEC 14.1). A pure function of what it can
## read from the world: it never touches sim state and talks to the sim only through `world.submit`, so every run it
## plays is recorded in the CommandLog and replays exactly (`Replay.run`). Call `act` once per tick, before
## `world.step()`. It never draws from a sim random stream, and its decisions depend on the world (and on the notes
## below, which are keyed to ticks and to submitted commands), never on how many times `act` was called: while the
## world awaits a choice the tick stands still, so a bot that answers at once or after 600 idle calls gives one run.
##
## NONE   skips every draft, takes route A, scraps every crate, buys and fires nothing (the "bot that buys nothing" of
##        GDD 8.4).
## GREEDY buys, once per tick at most, the cheapest upgrade that `purchase_block_reason` says is buyable right now
##        (state, level, wave lock and funds all pass); equal prices go by the fixed order in PRIORITY. It never
##        saves up for something dearer. Abilities on simple triggers:
##          EMP        when at least EMP_ATTACKERS enemies are attacking the core,
##          shield     when the core lost integrity since the last call (it is being hit),
##          overdrive  when the boss is alive and inside the Warden's weapon range.
##        At the intermission it takes the lowest-rarity card, route A and the emptiest slot (PolicyGreedy).
## RANDOM, BALANCED, HOARDER, SPAMMER, TURRET_RUSH, RISK: one file each (PolicyRandom, PolicyBalanced, ...). A choice a
## policy leaves open is answered like NONE does (PolicyAnswers.ensure_answered), so no policy can hang a run.

## Append only. The variety bots (VARIETY_SPEC 14.1; one file each under src/sim/ai/policy_*.gd).
enum Policy { NONE, GREEDY, RANDOM, HOARDER, SPAMMER, TURRET_RUSH, BALANCED, RISK }

## Route habit: AUTO is each policy's own; STANDARD and HOT force `balanced` to one kind (scorecard S14).
enum RouteMode { AUTO, STANDARD, HOT }

## Names in enum order, as the tools and the scorecard print them.
const NAMES: PackedStringArray = ["none", "greedy", "random", "hoarder", "spammer", "turret_rush", "balanced", "risk"]
## Enemies standing at the core that make GREEDY fire the EMP.
const EMP_ATTACKERS: int = 12
## Tie-break order for equal prices: weapon first, then the stats, turret last.
const PRIORITY: Array[int] = [Ids.UP_SMG, Ids.UP_DAMAGE, Ids.UP_FIRE_RATE, Ids.UP_ARMOR_PIERCING, Ids.UP_AUTO_TURRET]

var policy: int = Policy.NONE
## Commands submitted so far; by default the ids are 1, 2, 3, ... (unique per run, as the sim requires).
var commands_submitted: int = 0
## Optional `func() -> int` that mints each command id instead of the private counter. The game points it at
## `RunApi.next_command_id`, so a bot and a human tapping the HUD during the same run (--autoplay keeps the HUD up)
## draw from ONE counter. Two counters would repeat ids, and the sim answers a repeated id with DUPLICATE_COMMAND:
## a human's purchase or ability tap, or the bot's own, would be dropped silently (a repeated skip is dropped for good).
var id_source: Callable = Callable()
## Set by the scorecard for its forced-route runs; only `balanced` reads it.
var route_mode: int = RouteMode.AUTO

# --- notes of the policies (public so the policy files can read and write them) ---
## The core at the last call (GREEDY: "it is being hit"; BALANCED: "it crossed 60%"). -1 before the first call.
var last_core_hp: float = -1.0
## BALANCED: no new SWAP_WEAPON before this tick.
var swap_not_before: int = 0
## RANDOM: the tick of the last ability roll (one roll per tick, whatever the number of calls).
var last_roll_tick: int = -1
## BALANCED: rerolls and patches bought in the draft with this offer ordinal.
var draft_ordinal: int = -1
var draft_rerolls: int = 0
var draft_patches: int = 0
## RANDOM: the bot's own generator, created at the first use (never a stream of the world).
var rng: RandomNumberGenerator = null


func _init(policy_value: int) -> void:
	policy = policy_value


## Policy index for a name of NAMES, -1 when unknown.
static func policy_from_name(policy_name: String) -> int:
	return NAMES.find(policy_name)


static func name_of(policy_value: int) -> String:
	return NAMES[policy_value] if policy_value >= 0 and policy_value < NAMES.size() else "unknown"


## Submits commands for the next tick. Deterministic; does nothing once the run is over, and nothing a second time
## while an answer to the current choice is already queued.
func act(world: SimWorld) -> void:
	if world.is_over():
		return
	if PolicyAnswers.waiting(world) and not world.command_queue.is_empty():
		return
	match policy:
		Policy.NONE:
			PolicyNone.act(world, self)
		Policy.GREEDY:
			PolicyGreedy.act(world, self)
		Policy.RANDOM:
			PolicyRandom.act(world, self)
		Policy.HOARDER:
			PolicyHoarder.act(world, self)
		Policy.SPAMMER:
			PolicySpammer.act(world, self)
		Policy.TURRET_RUSH:
			PolicyTurretRush.act(world, self)
		Policy.BALANCED:
			PolicyBalanced.act(world, self)
		Policy.RISK:
			PolicyRisk.act(world, self)
	PolicyAnswers.ensure_answered(world, self)
	last_core_hp = world.core_hp


## The whole of the original GREEDY outside the intermission choices: buy, then the three abilities.
func play_legacy(world: SimWorld) -> void:
	_buy(world)
	_use_abilities(world)


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


## Enemies standing in an attack slot (ST_ATTACKING).
func attackers(world: SimWorld) -> int:
	return PolicySenses.attackers(world)


## The boss is alive and the Warden's current weapon reaches it.
func boss_in_range(world: SimWorld) -> bool:
	return PolicySenses.boss_in_range(world)


## BALANCED: forgets the rerolls and patches of the previous draft when a new offer opens.
func note_draft(offer_ordinal: int) -> void:
	if offer_ordinal != draft_ordinal:
		draft_ordinal = offer_ordinal
		draft_rerolls = 0
		draft_patches = 0


## RANDOM: the generator of this bot, seeded from hash(run seed, "bot") on first use.
func bot_rng(world: SimWorld) -> RandomNumberGenerator:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = ("%d|bot" % world.config.run_seed).hash()
	return rng


## Submits one command of `kind` with the SimCommand constructor for it, under the next command id. `arg` is the
## argument of SimCommand.Kind (for SALVAGE: choice * 16 + action).
func send(world: SimWorld, kind: int, arg: int) -> void:
	commands_submitted += 1
	var command_id: int = commands_submitted
	if id_source.is_valid():
		var minted: Variant = id_source.call()
		command_id = minted
	world.submit(_command(command_id, kind, arg))


static func _command(command_id: int, kind: int, arg: int) -> SimCommand:
	match kind:
		SimCommand.Kind.PURCHASE:
			return SimCommand.purchase(command_id, arg)
		SimCommand.Kind.ABILITY:
			return SimCommand.ability(command_id, arg)
		SimCommand.Kind.PICK_DIRECTIVE:
			return SimCommand.pick_directive(command_id, arg)
		SimCommand.Kind.SKIP_DRAFT:
			return SimCommand.skip_draft(command_id)
		SimCommand.Kind.REROLL:
			return SimCommand.reroll(command_id)
		SimCommand.Kind.BUY_OUT:
			return SimCommand.buy_out(command_id, arg)
		SimCommand.Kind.PATCH_CORE:
			return SimCommand.patch_core(command_id)
		SimCommand.Kind.PICK_ROUTE:
			return SimCommand.pick_route(command_id, arg)
		SimCommand.Kind.SALVAGE:
			return SimCommand.salvage(command_id, arg >> 4, arg & 15)
		SimCommand.Kind.SWAP_WEAPON:
			return SimCommand.swap_weapon(command_id, arg)
		SimCommand.Kind.CALL_EVENT:
			return SimCommand.call_event(command_id, arg)
		_:
			return SimCommand.skip(command_id)


func _buy(world: SimWorld) -> void:
	var upgrade: int = pick_purchase(world)
	if upgrade >= 0:
		send(world, SimCommand.Kind.PURCHASE, upgrade)


func _use_abilities(world: SimWorld) -> void:
	if world.ability_block_reason(Ids.AB_EMP) == Reason.Id.OK and attackers(world) >= EMP_ATTACKERS:
		send(world, SimCommand.Kind.ABILITY, Ids.AB_EMP)
	var core_hit: bool = last_core_hp >= 0.0 and world.core_hp < last_core_hp
	if core_hit and world.ability_block_reason(Ids.AB_SHIELD) == Reason.Id.OK:
		send(world, SimCommand.Kind.ABILITY, Ids.AB_SHIELD)
	if world.ability_block_reason(Ids.AB_OVERDRIVE) == Reason.Id.OK and boss_in_range(world):
		send(world, SimCommand.Kind.ABILITY, Ids.AB_OVERDRIVE)
