class_name AbilityDef
extends RefCounted

enum CooldownStart { ON_ACTIVATE, ON_END }

var id: StringName
var index: int
var name_key: String
var cooldown_ticks: int
var duration_ticks: int  ## shield and overdrive; 0 for EMP (instant, the stun is per enemy)
var cooldown_start: int
var stun_ticks: int  ## emp
var boss_stun_ticks: int  ## emp
var boss_immunity_ticks: int  ## emp
var absorb: float  ## shield
var fire_rate_mult_milli: int  ## overdrive (2000)
