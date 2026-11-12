class_name BossTremorRig
extends RefCounted
## NODE 7 // TREMOR RIG (`tremor_rig`; VARIETY_SPEC 6, CONTENT 5): act II. Stomps every 10 s (turrets offline 4 s, the magazine emptied; an active Shield negates
## it) and opens borer breaches at 66% and 33% HP.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
# TODO(V4-L)


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 3


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(_world: SimWorld, _enemy_index: int) -> void:
	pass


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(_world: SimWorld, _enemy_index: int) -> void:
	pass
