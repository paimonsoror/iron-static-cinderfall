class_name WeaponPerks
extends RefCounted
## The level-3 perks of the weapons (VARIETY_CONTENT 2, "Weapon levels"). `WeaponDef.level3` maps a perk key of
## data/weapons.json to its value. The keys that name a WeaponDef field (`magazine`, `pellets`, `pierce`, `salvo`,
## `chains`, `ramp_cap`, `spin_up_s`, `pool_seconds`) replace that field at level 3; `crit_every` and `crit_mult` (the
## pistol) have no field and are read with `level_value`. `effective` returns the def the fire files read: the shared
## def itself below level 3, else a copy with the perks applied (a copy per call, never cached: tests and tools may
## change a def, and a level-3 weapon makes one copy per tick at most).

const MAX_LEVEL: int = 3


## The def to fire with at weapon level `level`.
static func effective(def: WeaponDef, level: int) -> WeaponDef:
	if level < MAX_LEVEL or def.level3.is_empty():
		return def
	var made: WeaponDef = copy_of(def)
	for key: StringName in def.level3:
		_apply(made, key, def.level3[key])
	return made


## The value of the level-3 perk `key` when `level` is 3 and the weapon has it, else `base`.
static func level_value(def: WeaponDef, level: int, key: StringName, base: float) -> float:
	if level >= MAX_LEVEL and def.level3.has(key):
		return def.level3[key]
	return base


## A copy of `def` with the damage multiplied by `factor` (the pistol's guaranteed x3 hit).
static func scaled(def: WeaponDef, factor: float) -> WeaponDef:
	var made: WeaponDef = copy_of(def)
	made.damage = def.damage * factor
	return made


## Every script variable of `def`, copied.
static func copy_of(def: WeaponDef) -> WeaponDef:
	var made: WeaponDef = WeaponDef.new()
	for prop: Dictionary in def.get_property_list():
		var usage: int = prop["usage"]
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var prop_name: String = prop["name"]
		made.set(prop_name, def.get(prop_name))
	return made


static func _apply(made: WeaponDef, key: StringName, value: float) -> void:
	match key:
		&"magazine":
			made.magazine = roundi(value)
		&"pellets":
			made.pellets = roundi(value)
		&"pierce":
			made.pierce = roundi(value)
		&"salvo":
			made.salvo = roundi(value)
		&"chains":
			made.chains = roundi(value)
		&"ramp_cap":
			made.ramp_cap = value
		&"spin_up_s":
			made.spin_up_ticks = Formulas.ticks(value)
		&"pool_seconds":
			made.pool_ticks = Formulas.ticks(value)
		_:
			pass  # crit_every, crit_mult: read through level_value
