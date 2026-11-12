class_name BossBroodCarrier
extends RefCounted
## NODE 3 // BROOD CARRIER (`brood_carrier`; VARIETY_SPEC 6, CONTENT 5): act I. Every 6 s it opens its hatches and releases 6 motes; at 50% HP it molts: armor 0, a
## release every 3 s. A stun resets the hatch timer.
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
