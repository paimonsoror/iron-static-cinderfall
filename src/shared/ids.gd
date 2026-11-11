class_name Ids
extends RefCounted
## Fixed content ids. The index is the position in these arrays, forever (ARCH 4).

const ENEMIES: Array[StringName] = [&"skitter", &"hollow_warden", &"rusher", &"siege_hulk"]
const WEAPONS: Array[StringName] = [&"pistol", &"smg"]
const UPGRADES: Array[StringName] = [&"damage", &"fire_rate", &"armor_piercing", &"auto_turret", &"smg_unlock"]
const ABILITIES: Array[StringName] = [&"emp", &"shield", &"overdrive"]

const UP_DAMAGE := 0
const UP_FIRE_RATE := 1
const UP_ARMOR_PIERCING := 2
const UP_AUTO_TURRET := 3
const UP_SMG := 4

const AB_EMP := 0
const AB_SHIELD := 1
const AB_OVERDRIVE := 2

const EN_SKITTER := 0
const EN_HOLLOW := 1
const EN_RUSHER := 2
const EN_HULK := 3


## -1 if unknown.
static func enemy_index(id: StringName) -> int:
	return ENEMIES.find(id)


static func weapon_index(id: StringName) -> int:
	return WEAPONS.find(id)


static func upgrade_index(id: StringName) -> int:
	return UPGRADES.find(id)


static func ability_index(id: StringName) -> int:
	return ABILITIES.find(id)
