class_name BossState
extends RefCounted
## The living boss and its script state (VARIETY_SPEC 6, 13.2). Written by BossSystem and its boss files only; hashed.
##
## Integers only (VARIETY_SPEC 9.5 rule 4). The field list is a frozen contract, so everything a boss script has to
## remember beyond the named fields lives in `timers`: a list of integers whose meaning is given by the boss file
## (ticks, enemy ids, counters, positions in millimetres). It has four zeros while no boss lives, so the hash of a
## world without a boss is the hash of the scaffold's neutral state.

const FIELDS: PackedStringArray = [
	"boss_id", "boss_type", "variant", "phase", "phase_count", "timers", "telegraph_attack", "telegraph_left", "flags",
	"exposed_left", "parts_alive",
]

## `telegraph_attack` and the `a` of BOSS_TELEGRAPH (b = ticks until the attack lands).
const ATK_NONE: int = -1
const ATK_HATCH: int = 0  ## brood carrier: the hatches open and release motes
const ATK_LANCE: int = 1  ## lance platform: the beam at the core
const ATK_STOMP: int = 2  ## tremor rig: turrets offline, the magazine emptied
const ATK_BREACH: int = 3  ## reserved (a breach is announced by BOSS_PHASE and read from BossTremorRig.breach_points)
const ATK_CHARGE: int = 4  ## overclocked hulk: the charge starts
const ATK_REDEPLOY: int = 5  ## reserved (the exposed window is read from exposed_left; no event)

## `flags` bits.
const F_BEGUN: int = 1  ## the first step after the spawn has run (parts and escorts were sent)
const F_ENRAGED: int = 2  ## siege hulk below its enrage threshold
const F_MOLTED: int = 4  ## brood carrier after its molt
const F_PLANTED: int = 8  ## lance platform standing at its range
const F_CHARGING: int = 16  ## lance platform charging (vents open) or overclocked hulk running its charge
const F_EXPOSED: int = 32  ## aegis array with no pylon up
const F_BRACED: int = 64  ## tremor rig: the last stomp was negated by an active Shield

## `variant` of a boss that has none (every boss but a Node 9 of the last act).
const NO_VARIANT: int = -1

var boss_id: int = 0  ## enemy id of the living boss, 0 = none
var boss_type: int = -1  ## Ids.ENEMIES index
var variant: int = 0  ## index into RunDef.hulk_variants of a living Node 9, NO_VARIANT for a boss without one
var phase: int = 0
var phase_count: int = 1
var timers: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])  ## script memory, meaning per boss file
var telegraph_attack: int = -1  ## the attack being telegraphed (ATK_*), or -1
var telegraph_left: int = 0  ## ticks until it lands
var flags: int = 0
var exposed_left: int = 0  ## Aegis Array damage window
var parts_alive: int = 0  ## pylons


## Back to the state of a world without a boss.
func reset() -> void:
	boss_id = 0
	boss_type = -1
	variant = 0
	phase = 0
	phase_count = 1
	timers = PackedInt32Array([0, 0, 0, 0])
	telegraph_attack = ATK_NONE
	telegraph_left = 0
	flags = 0
	exposed_left = 0
	parts_alive = 0


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


func set_flag(flag: int, on: bool) -> void:
	flags = (flags | flag) if on else (flags & ~flag)


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
