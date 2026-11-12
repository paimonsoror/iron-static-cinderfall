class_name BossAegisArray
extends RefCounted
## NODE 6 // AEGIS ARRAY (`aegis_array`; VARIETY_SPEC 6, CONTENT 5): act II. Three ward pylons orbit it; while one lives the boss takes x0.2 damage. When all are
## down it is exposed for 10 s, then redeploys 3, 2, 1.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
# TODO(V4-L)


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 4


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(_world: SimWorld, _enemy_index: int) -> void:
	pass


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(_world: SimWorld, _enemy_index: int) -> void:
	pass
