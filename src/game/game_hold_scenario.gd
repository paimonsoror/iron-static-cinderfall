class_name GameHoldScenario
extends RefCounted
## `--scenario=hold<N>` (ARCH 11): a perf and view scenario on the real simulation. While a wave is in combat it tops
## the field up with extra enemies so that N stay alive (the Warden keeps killing them, so there is spawn and death
## churn); the caller also makes the core invulnerable. It spawns through `SimWorld.spawn_enemy`, the sim's own shared
## mutator, from the arena's spawn regions, using its own RNG. Never part of a normal run.

const MAX_SPAWNS_PER_TICK: int = 3
## Skitter-heavy crowd with Hollow Wardens and Rushers mixed in, as SimPuppet does.
const MIX: Array[int] = [0, 0, 0, 1, 0, 2, 0, 0, 1, 2]

var hold: int
var spawned_total: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(count: int, scenario_seed: int) -> void:
	hold = maxi(count, 1)
	_rng.seed = scenario_seed


## Called before every tick. Only acts while a wave is in combat.
func act(world: SimWorld) -> void:
	if not GameState.is_combat(world.phase):
		return
	var target: int = mini(hold, world.content.mission.enemy_cap)
	var added: int = 0
	while world.alive_count() < target and added < MAX_SPAWNS_PER_TICK:
		if not _spawn_one(world):
			return
		added += 1


func _spawn_one(world: SimWorld) -> bool:
	var regions: Array[SpawnRegionDef] = world.content.arena.spawn_regions
	if regions.is_empty():
		return false
	var region: SpawnRegionDef = regions[_rng.randi() % regions.size()]
	var t: float = _rng.randf()
	var type_index: int = MIX[spawned_total % MIX.size()]
	var i: int = world.spawn_enemy(type_index, lerpf(region.x0, region.x1, t), lerpf(region.z0, region.z1, t))
	if i < 0:
		return false
	spawned_total += 1
	return true
