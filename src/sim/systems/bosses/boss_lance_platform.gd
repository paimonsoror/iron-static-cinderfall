class_name BossLancePlatform
extends RefCounted
## NODE 5 // LANCE PLATFORM (`lance_platform`; VARIETY_SPEC 6, CONTENT 5): act I. Walks to its standoff point and plants. Cycle 9 s: a 3 s telegraphed charge, then
## a beam at the core. +50% damage taken while charging; an EMP during the charge cancels the shot.
## Shared rules: never an elite; an EMP stuns for 1 s, then 5 s immunity; every telegraphed attack has two answers; no
## attack removes more than 20% of the core maximum.
# TODO(V4-L)


## Phase pips of the boss bar.
static func phase_count() -> int:
	return 1


## The boss spawned at store index `enemy_index`: set BossState and its timers.
static func begin(_world: SimWorld, _enemy_index: int) -> void:
	pass


## One tick of the script (BossSystem.step calls it while the boss lives).
static func step(_world: SimWorld, _enemy_index: int) -> void:
	pass
