class_name BossSiegeHulk
extends RefCounted
## NODE 9 // SIEGE HULK (`siege_hulk`; VARIETY_SPEC 6, CONTENT 5): act III, always; the act I stand-in of the slice. One of three variants per run (plated, fed,
## overclocked). Every variant: below 25% HP its attack period is -30%.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
# TODO(V4-L)


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 2


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(_world: SimWorld, _enemy_index: int) -> void:
	pass


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(_world: SimWorld, _enemy_index: int) -> void:
	pass
