class_name HazardState
extends RefCounted
## Delayed effects, ground pools, mines and fuel drums (VARIETY_SPEC 9.5 rule 2, 13.2). The delayed queue is ordered by
## (due tick, sequence number); at most RunDef.max_blasts_per_tick blasts resolve per tick. Written by HazardSystem
## only; hashed.
# TODO(V2-C): the queue and pools for the slice. TODO(V4-V): mines and drums.

## Kinds of a delayed hit (also the `kind` of AREA_BLAST and DELAYED_HIT_LAUNCHED events).
const K_BLAST: int = 0  ## a death or chain blast
const K_STRIKE: int = 1  ## Deadfall Strike
const K_SHELL: int = 2  ## mortar shell
const K_MISSILE: int = 3  ## hornet
const K_BOLT: int = 4  ## spitter bolt (hits the core)
const K_DRUM: int = 5
const K_MINE: int = 6
const K_VENT: int = 7  ## core vent
const K_FREIGHT: int = 8
const FIELDS: PackedStringArray = [
	"next_seq", "q_due", "q_seq", "q_kind", "q_source", "q_flags", "q_x", "q_z", "q_radius", "q_damage", "q_edge",
	"next_pool_id", "p_id", "p_ticks_left", "p_x", "p_z", "p_radius", "p_dps", "p_slow",
	"m_x", "m_z", "m_owner", "d_point", "d_alive", "d_damage_milli",
]

var next_seq: int = 1
var q_due: PackedInt32Array = PackedInt32Array()
var q_seq: PackedInt32Array = PackedInt32Array()
var q_kind: PackedInt32Array = PackedInt32Array()
var q_source: PackedInt32Array = PackedInt32Array()  ## DamageSource.Id
var q_flags: PackedInt32Array = PackedInt32Array()  ## DamageResolver.F_*
var q_x: PackedFloat64Array = PackedFloat64Array()
var q_z: PackedFloat64Array = PackedFloat64Array()
var q_radius: PackedFloat64Array = PackedFloat64Array()
var q_damage: PackedFloat64Array = PackedFloat64Array()
var q_edge: PackedFloat64Array = PackedFloat64Array()  ## damage fraction at the edge
var next_pool_id: int = 1
var p_id: PackedInt32Array = PackedInt32Array()
var p_ticks_left: PackedInt32Array = PackedInt32Array()
var p_x: PackedFloat64Array = PackedFloat64Array()
var p_z: PackedFloat64Array = PackedFloat64Array()
var p_radius: PackedFloat64Array = PackedFloat64Array()
var p_dps: PackedFloat64Array = PackedFloat64Array()
var p_slow: PackedFloat64Array = PackedFloat64Array()
var m_x: PackedFloat64Array = PackedFloat64Array()  ## mines
var m_z: PackedFloat64Array = PackedFloat64Array()
var m_owner: PackedInt32Array = PackedInt32Array()  ## turret pad
var d_point: PackedInt32Array = PackedInt32Array()  ## drums: index into ArenaDef.drum_points
var d_alive: PackedInt32Array = PackedInt32Array()
var d_damage_milli: PackedInt32Array = PackedInt32Array()  ## stray damage taken so far


func queued() -> int:
	return q_due.size()


func pool_count() -> int:
	return p_id.size()


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
