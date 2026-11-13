class_name MetaProfile
extends RefCounted
## Reads of the profile's meta fields (ARCH 7.5, profile v2) for the menu, the Archive and the results screen. The v2
## fields (`best_wave`, `boss_kills`, `daily`, `claimed`, `victories_by_kit`) are read through `Object.get`, so this file
## compiles and answers with the neutral value on a profile that does not have them yet, and answers the real value once it
## does. The v1 fields (`data`, `unlocks`, `kit`) are read directly.


## The furthest wave any run reached (0 when never played).
static func best_wave(profile: Profile) -> int:
	return _int(profile, &"best_wave")


## Boss id -> kills ({} on a profile without the field).
static func boss_kills(profile: Profile) -> Dictionary:
	var v: Variant = profile.get(&"boss_kills") if profile != null else null
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	return d


## { "date": String, "best_wave": int, "won": bool, "rewarded": bool } (empty strings and zeros when absent).
static func daily(profile: Profile) -> Dictionary:
	var out: Dictionary = {"date": "", "best_wave": 0, "won": false, "rewarded": false}
	var v: Variant = profile.get(&"daily") if profile != null else null
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		for key: Variant in d.keys():
			out[key] = d[key]
	return out


## True once an act I boss was killed (any boss of the first act's pool has a kill): the DAILY RUN button appears (GDD 10.2).
static func act_one_boss_killed(profile: Profile, content: ContentSet) -> bool:
	return act_one_boss_killed_in(boss_kills(profile), content)


## The same for a boss id -> kills dictionary.
static func act_one_boss_killed_in(kills: Dictionary, content: ContentSet) -> bool:
	if content == null:
		return false
	for boss: BossDef in content.bosses:
		if boss.pool_act != 1:
			continue
		var n: Variant = kills.get(String(boss.id), kills.get(boss.id, 0))
		if typeof(n) == TYPE_INT:
			var count: int = n
			if count > 0:
				return true
		elif typeof(n) == TYPE_FLOAT:  # a JSON number that was not turned back into an int
			var real: float = n
			if real > 0.0:
				return true
	return false


## "STANDARD ISSUE": the display name of the kit `id`.
static func kit_name(content: ContentSet, id: StringName) -> String:
	var def: KitDef = content.kit(id) if content != null else null
	if def != null and RunUi.has_key(def.name_key):
		return Strings.t(def.name_key)
	return String(id).to_upper()


## The Swap assist setting (VARIETY_SPEC 3.1): false when the profile does not know the key.
static func swap_assist() -> bool:
	var v: Variant = Save.get_setting(&"swap_assist")
	if typeof(v) != TYPE_BOOL:
		return false
	var on: bool = v
	return on


static func _int(profile: Profile, key: StringName) -> int:
	var v: Variant = profile.get(key) if profile != null else null
	if typeof(v) != TYPE_INT:
		return 0
	var n: int = v
	return n
