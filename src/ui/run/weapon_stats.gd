class_name WeaponStats
extends RefCounted
## The stat words of a weapon for the salvage panels (VARIETY_SPEC 11.3): "DMG 80  4/s  AREA 2.6 m  MAG 4  RELOAD 2.4 s".
## Numbers come from the WeaponDef (data/weapons.json); the level multiplies the damage (level_mult).


static func name_of(id: StringName) -> String:
	return Strings.t("weapon.%s.name" % String(id)).to_upper()


static func short_name(id: StringName) -> String:
	return RunUi.opt("weapon.%s.short" % String(id), name_of(id))


## Damage per shot at `level` (1..3).
static func damage(def: WeaponDef, level: int) -> int:
	var mult: float = def.level_mult[clampi(level - 1, 0, def.level_mult.size() - 1)] if not def.level_mult.is_empty() else 1.0
	return roundi(def.damage * mult)


static func rate(def: WeaponDef) -> float:
	return float(def.sps_milli) / 1000.0


## The stat words, one string each, in the order damage, rate, area, feed, reload, range.
static func parts(def: WeaponDef, level: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append(Strings.tf("weapon.stat.dmg", [damage(def, level)]))
	out.append(Strings.tf("weapon.stat.rate", ["%.1f" % rate(def)]))
	if def.area_m > 0.0:
		out.append(Strings.tf("weapon.stat.area", ["%.1f" % def.area_m]))
	if def.is_heat():
		out.append(Strings.t("weapon.stat.heat"))
	elif def.magazine > 0:
		out.append(Strings.tf("weapon.stat.mag", [def.magazine]))
		if def.reload_ticks > 0:
			out.append(Strings.tf("weapon.stat.reload", ["%.1f" % (float(def.reload_ticks) / float(ContentLoader.TICK_RATE))]))
	return out


static func line(def: WeaponDef, level: int) -> String:
	return "  ".join(parts(def, level))


## The two words a carried slot shows ("DMG 30  2.0/s", VARIETY_SPEC 11.3): damage and rate fit one line of a half-width panel
## at 30 px for every weapon (the pistol's magazine and reload do not, and wrapped).
static func brief(def: WeaponDef, level: int) -> String:
	return "  ".join(parts(def, level).slice(0, 2))
