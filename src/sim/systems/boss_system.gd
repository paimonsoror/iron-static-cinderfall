class_name BossSystem
extends RefCounted
## The script of the living boss (tick step 13; VARIETY_SPEC 6, CONTENT 5). The only writer of BossState. Each boss
## lives in its own file under systems/bosses/ with the same functions (begin, step, phase_count); `step` is the one
## place that maps the boss type to its file. Pushes BOSS_TELEGRAPH and BOSS_PHASE. Called every tick of a live run.
# TODO(V4-L): the stub tracks nothing, so the Siege Hulk of the slice behaves as the plain enemy it is today.


static func step(_world: SimWorld) -> void:
	pass


## Called when a boss enemy spawned (store index): fills BossState and runs the boss file's `begin`.
static func on_spawned(_world: SimWorld, _enemy_index: int) -> void:
	pass


## Phase pips of the boss bar for an enemy type (1 for a type that is not a scripted boss).
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
