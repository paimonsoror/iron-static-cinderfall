class_name BossSystem
extends RefCounted
## The script of the living boss (tick step 13; VARIETY_SPEC 6, CONTENT 5). The only writer of BossState. Each boss
## lives in its own file under systems/bosses/ with the same functions (begin, step, phase_count); `step` is the one
## place that maps the boss type to its file. Pushes BOSS_TELEGRAPH and BOSS_PHASE. Called every tick of a live run.
##
## One boss is scripted at a time: the first boss body that spawns while none is tracked. The legacy content (no
## `run`) has no script, so its Siege Hulk stays the plain enemy of the five-wave fixture. When the boss dies its parts
## go with it and BossState returns to neutral.
##
## Two rules of a boss fight live in the damage path and are answered here for DamageResolver: `damage_taken_mult`
## (the Aegis Array behind its pylons, the Lance Platform with its vents open) and `armor_of` (the molted Brood
## Carrier, the plated Node 9).


static func step(world: SimWorld) -> void:
	var b: BossState = world.boss
	if b.boss_id == 0:
		return
	var i: int = world.enemies.index_of(b.boss_id)
	if i < 0 or world.enemies.type[i] != b.boss_type:
		_on_boss_gone(world)
		return
	if not GameState.is_combat(world.phase):
		return
	match b.boss_type:
		Ids.EN_HULK:
			BossSiegeHulk.step(world, i)
		Ids.EN_BROOD_CARRIER:
			BossBroodCarrier.step(world, i)
		Ids.EN_LANCE_PLATFORM:
			BossLancePlatform.step(world, i)
		Ids.EN_AEGIS_ARRAY:
			BossAegisArray.step(world, i)
		Ids.EN_TREMOR_RIG:
			BossTremorRig.step(world, i)


## Called when a boss enemy spawned (store index): fills BossState and runs the boss file's `begin`.
static func on_spawned(world: SimWorld, enemy_index: int) -> void:
	if world.content.run == null or world.boss.boss_id != 0:
		return
	match world.enemies.type[enemy_index]:
		Ids.EN_HULK:
			BossSiegeHulk.begin(world, enemy_index)
		Ids.EN_BROOD_CARRIER:
			BossBroodCarrier.begin(world, enemy_index)
		Ids.EN_LANCE_PLATFORM:
			BossLancePlatform.begin(world, enemy_index)
		Ids.EN_AEGIS_ARRAY:
			BossAegisArray.begin(world, enemy_index)
		Ids.EN_TREMOR_RIG:
			BossTremorRig.begin(world, enemy_index)


## Phase pips of the boss bar for an enemy type (1 for a type that is not a scripted boss). A living boss may show
## more (the plated Node 9): the bar reads BossState.phase_count.
static func phase_count(type_index: int) -> int:
	match type_index:
		Ids.EN_HULK:
			return BossSiegeHulk.phase_count()
		Ids.EN_BROOD_CARRIER:
			return BossBroodCarrier.phase_count()
		Ids.EN_LANCE_PLATFORM:
			return BossLancePlatform.phase_count()
		Ids.EN_AEGIS_ARRAY:
			return BossAegisArray.phase_count()
		Ids.EN_TREMOR_RIG:
			return BossTremorRig.phase_count()
	return 1


## True when store index `enemy_index` is the body of the scripted boss.
static func is_boss_body(world: SimWorld, enemy_index: int) -> bool:
	var b: BossState = world.boss
	return b.boss_id != 0 and enemy_index >= 0 and enemy_index < world.enemies.capacity and world.enemies.id[enemy_index] == b.boss_id


## The factor on the damage the enemy at `enemy_index` takes from one hit, after armor (1.0 for everything but the
## scripted boss): x0.2 for the Aegis Array while a pylon protects it, x1.5 for the Lance Platform while it charges.
static func damage_taken_mult(world: SimWorld, enemy_index: int) -> float:
	if not is_boss_body(world, enemy_index):
		return 1.0
	match world.boss.boss_type:
		Ids.EN_AEGIS_ARRAY:
			return BossAegisArray.damage_taken_mult(world)
		Ids.EN_LANCE_PLATFORM:
			return BossLancePlatform.damage_taken_mult(world)
	return 1.0


## The armor of the enemy at `enemy_index` before modifiers and shred: `base_armor` (its type's value) for everything
## but the scripted boss, whose script may change it (molt: 0; plated: 24, 12, 4).
static func armor_of(world: SimWorld, enemy_index: int, base_armor: float) -> float:
	if not is_boss_body(world, enemy_index):
		return base_armor
	match world.boss.boss_type:
		Ids.EN_BROOD_CARRIER:
			return BossBroodCarrier.armor_of(world, base_armor)
		Ids.EN_HULK:
			return BossSiegeHulk.armor_of(world, base_armor)
	return base_armor


## The boss left the store (killed, or freed by a debug tool): its parts go with it, the state returns to neutral.
static func _on_boss_gone(world: SimWorld) -> void:
	if world.boss.boss_type == Ids.EN_AEGIS_ARRAY:
		BossAegisArray.end(world)
	world.boss.reset()
