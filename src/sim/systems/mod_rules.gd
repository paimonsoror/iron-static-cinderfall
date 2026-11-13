class_name ModRules
extends RefCounted
## The rules of ModSystem that the plain `ops[]` grammar cannot say (VARIETY_CONTENT 3): effects that do not stack
## linearly (`stack_rule`), effects that depend on the state of the run (Scrap, the core, a Static Front, the Tally) and
## the few one-time reactions to a pick. Everything here reads the world and the ModState; only `on_picked` and
## `post_ops` write (ModState and, through HookMemory, the stack count of a hook directive).
##
## The dynamic multipliers (`damage_mul`, `rate_mul`, `last_stand_*`) are the numbers of scrap_rounds, the_tally,
## static_pact and last_stand_protocol. ModState keeps only the flags and the static stats, so a consumer multiplies
## these in at the moment of use (DamageResolver.warden_amount, the fire cadence, the turret cadence, the reload time)
## and nothing is counted twice. Constants are first-pass values of CONTENT 3; V5-C confirms them.

const HOOK_STACK_RULE: StringName = &"stack_rule"
## Every `hook` name data/directives.json may use (a test checks the shipped data against it): the call points of
## ShotHooks and the turret systems (V4-W, V4-V), of CoreHooks and DeathHooks, of RunPlanSystem.patch and of ModSystem.
const KNOWN_HOOKS: PackedStringArray = [
	"on_warden_hit", "on_warden_kill", "on_warden_shot", "off_hand_fire", "on_turret_hit", "on_turret_shot",
	"turret_target_class", "on_core_hit", "on_core_changed", "defeat_check", "core_weapon", "on_wave_cleared", "on_ability",
	"on_emp", "on_shield_end", "on_enemy_killed", "plan_patch", "stack_rule", "remove_turrets",
]

## executioner: the damage bonus does not stack (the ops apply once); each further stack adds this to the threshold.
const STACK_RULE_STEPS: Dictionary[StringName, Dictionary] = {
	&"executioner": {&"w_low_hp_threshold": 0.10},
}
## borrowed_time: the core maximum shrinks by this fraction of the mission maximum after every wave cleared.
const BORROWED_STEP: float = 0.05
## scrap_rounds: +1% Warden damage per 40 banked Scrap, at most +60%.
const SCRAP_ROUNDS_PER: int = 40
const SCRAP_ROUNDS_STEP: float = 0.01
const SCRAP_ROUNDS_CAP: float = 0.60
## static_pact: during a Static Front the Warden fires at +100% rate.
const STATIC_PACT_RATE: float = 2.0
## last_stand_protocol: below this fraction of the core maximum turrets fire +80% faster and the Warden reloads in half
## the time ("50% faster" read as the reload time x0.5).
const LAST_STAND_CORE_FRAC: float = 0.35
const LAST_STAND_TURRET_RATE: float = 1.8
const LAST_STAND_RELOAD_MUL: float = 0.5
## unstable_munitions: 5% of reloads jam for 1.5 s.
const JAM_CHANCE: float = 0.05
const JAM_TICKS: int = 90
## the_tally: +1% damage per 10 Warden kills.
const TALLY_KILLS_PER_PCT: int = 10


## Applies directive `def` held `count` times: the ops `min(held, max)` times, or for a `stack_rule` directive once plus
## the per-stack steps of STACK_RULE_STEPS. A count above `max` (HookMemory) never adds more.
static func apply_directive(world: SimWorld, def: DirectiveDef, count: int) -> void:
	var stacks: int = mini(count, def.max_stacks)
	if def.hook != HOOK_STACK_RULE:
		ModSystem.apply_ops(world, def.ops, stacks)
		return
	ModSystem.apply_ops(world, def.ops, 1)
	var steps: Dictionary = STACK_RULE_STEPS.get(def.id, {})
	for stat_name: StringName in steps:
		var step: float = steps[stat_name]
		world.mods.set(String(stat_name), world.mods.stat(stat_name) + step * float(stacks - 1))


## After the directives and the wave modifier: borrowed_time shrinks the core maximum by its waves paid.
static func post_ops(world: SimWorld) -> void:
	var paid: int = HookMemory.borrowed_waves(world)
	if paid > 0:
		world.mods.core_max_mul -= BORROWED_STEP * float(paid)


## Reactions to a directive that was just added (its stack count is already raised): the_tally starts at the bonus its
## kills so far would have earned.
static func on_picked(world: SimWorld, def: DirectiveDef) -> void:
	if def.id == &"the_tally":
		HookMemory.set_tally(world, mini(HookMemory.TALLY_PCT_MAX, floori(float(warden_kills(world)) / float(TALLY_KILLS_PER_PCT))), 0)


## the_tally: every 10th Warden kill adds 1% (up to 100%). Called after the kill was counted.
static func tally_gain(world: SimWorld) -> void:
	if held(world, &"the_tally") <= 0 or warden_kills(world) % TALLY_KILLS_PER_PCT != 0:
		return
	HookMemory.set_tally(world, HookMemory.tally_pct(world) + 1, HookMemory.tally_last_tick(world))


## Kills by the Warden and its off-hand gun so far.
static func warden_kills(world: SimWorld) -> int:
	var c: CombatState = world.combat
	return c.kills_by_source[DamageSource.Id.WARDEN] + c.kills_by_source[DamageSource.Id.WARDEN_OFFHAND]


## The held stacks of directive `id`, never above its maximum (0 when absent).
static func held(world: SimWorld, id: StringName) -> int:
	var index: int = world.content.directive_index(id)
	if index < 0:
		return 0
	return mini(world.draft.stacks_of(index), world.content.directives[index].max_stacks)


## The Warden damage multiplier of scrap_rounds and the_tally (1.0 when neither is held).
static func damage_mul(world: SimWorld) -> float:
	var mult: float = 1.0
	if world.mods.has_flag(&"scrap_rounds"):
		var bonus: float = minf(SCRAP_ROUNDS_CAP, float(floori(float(world.scrap) / float(SCRAP_ROUNDS_PER))) * SCRAP_ROUNDS_STEP)
		mult *= 1.0 + bonus
	if held(world, &"the_tally") > 0:
		mult *= 1.0 + float(HookMemory.tally_pct(world)) / 100.0
	return mult


## The Warden fire-rate multiplier of static_pact: x2 while a Static Front is running (1.0 otherwise).
static func rate_mul(world: SimWorld) -> float:
	if held(world, &"static_pact") > 0 and world.events_state.ability_lock_ticks > 0:
		return STATIC_PACT_RATE
	return 1.0


## True while last_stand_protocol is held and the core is below 35% of its maximum.
static func last_stand_active(world: SimWorld) -> bool:
	return world.mods.has_flag(&"last_stand") and world.core_hp < LAST_STAND_CORE_FRAC * world.core_max_hp


## The turret fire-rate multiplier of last_stand_protocol (1.0 when it does not apply).
static func last_stand_turret_rate(world: SimWorld) -> float:
	return LAST_STAND_TURRET_RATE if last_stand_active(world) else 1.0


## The Warden reload-time multiplier of last_stand_protocol (1.0 when it does not apply).
static func last_stand_reload_mul(world: SimWorld) -> float:
	return LAST_STAND_RELOAD_MUL if last_stand_active(world) else 1.0


## unstable_munitions: extra ticks a reload that starts now takes (JAM_TICKS on 5% of reloads, else 0). One draw from the
## `proc` stream per call, and none without the directive.
static func reload_jam_ticks(world: SimWorld) -> int:
	if held(world, &"unstable_munitions") <= 0:
		return 0
	var rng: RandomNumberGenerator = world.rng.stream(&"proc")
	return JAM_TICKS if rng.randf() < JAM_CHANCE else 0
