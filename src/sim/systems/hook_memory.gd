class_name HookMemory
extends RefCounted
## The run memory of the three hook directives that need a counter or a spent flag (VARIETY_SPEC 13.2 has no state class
## for it). It lives in the stack count of the directive itself, which is hashed, saved and restored with DraftState:
##   dead_mans_switch  1 = armed, 2 = spent (stacks above `max` are never offered again and never apply ops)
##   borrowed_time     1 + the waves cleared since it was taken
##   the_tally         1 + bonus percent (0..100) + TALLY_TICK_STEP x the tick of the last halving (0 = never)
##   amber_surge       1 = armed, 2 + n = its free shield is running and the Shield cooldown was n ticks before it
## DraftSystem.build_tags and ModSystem.recompute clamp a held count to `max`, so these numbers never leak into the
## draft weights or the op stacks. The UI must not print the count of a directive whose `max` is 1.
## TODO(needs owner): a real state class (HookState on SimWorld) would replace this file and nothing else.

const TALLY_TICK_STEP: int = 128  ## 7 bits for the percent (0..100)
const TALLY_PCT_MAX: int = 100
const TALLY_MAX_TICK: int = 8000000  ## 37 hours of play; keeps the packed number below 2^31
const SPENT: int = 2


## The raw stack count of directive `id` (0 when it is not held or unknown).
static func raw(world: SimWorld, id: StringName) -> int:
	return world.draft.stacks_of(world.content.directive_index(id))


static func set_raw(world: SimWorld, id: StringName, value: int) -> void:
	var index: int = world.content.directive_index(id)
	if index >= 0 and index < world.draft.stacks.size():
		world.draft.stacks[index] = value


## True while dead_mans_switch is held and not yet used.
static func switch_armed(world: SimWorld) -> bool:
	return raw(world, &"dead_mans_switch") == 1


static func spend_switch(world: SimWorld) -> void:
	set_raw(world, &"dead_mans_switch", SPENT)


## amber_surge: the Shield cooldown to give back when the free shield ends, or -1 when no free shield is running.
static func free_shield_cooldown(world: SimWorld) -> int:
	var n: int = raw(world, &"amber_surge")
	return n - SPENT if n >= SPENT else -1


static func begin_free_shield(world: SimWorld, cooldown_ticks: int) -> void:
	set_raw(world, &"amber_surge", SPENT + maxi(0, cooldown_ticks))


static func end_free_shield(world: SimWorld) -> void:
	set_raw(world, &"amber_surge", 1)


## Waves cleared since borrowed_time was taken.
static func borrowed_waves(world: SimWorld) -> int:
	return maxi(0, raw(world, &"borrowed_time") - 1)


static func add_borrowed_wave(world: SimWorld) -> void:
	set_raw(world, &"borrowed_time", raw(world, &"borrowed_time") + 1)


## The Tally bonus in whole percent (0 when it is not held).
static func tally_pct(world: SimWorld) -> int:
	var n: int = raw(world, &"the_tally")
	return 0 if n <= 0 else (n - 1) % TALLY_TICK_STEP


static func tally_last_tick(world: SimWorld) -> int:
	var n: int = raw(world, &"the_tally")
	return 0 if n <= 0 else floori(float(n - 1) / float(TALLY_TICK_STEP))


static func set_tally(world: SimWorld, pct: int, last_tick: int) -> void:
	var p: int = clampi(pct, 0, TALLY_PCT_MAX)
	var t: int = clampi(last_tick, 0, TALLY_MAX_TICK)
	set_raw(world, &"the_tally", 1 + p + TALLY_TICK_STEP * t)
