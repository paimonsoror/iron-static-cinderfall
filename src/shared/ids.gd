class_name Ids
extends RefCounted
## Fixed content ids. The index is the position in these arrays, forever (ARCH 4). Append only: the variety milestone
## (VARIETY_SPEC 13.2) added enemies 4..17 and weapons 2..9; the legacy fixture uses only the first LEGACY_* entries.

const ENEMIES: Array[StringName] = [
	&"skitter", &"hollow_warden", &"rusher", &"siege_hulk",
	&"mote", &"shard", &"burster", &"spitter", &"splitter", &"shieldbearer", &"reclaimer", &"jammer", &"borer",
	&"ward_pylon", &"brood_carrier", &"lance_platform", &"aegis_array", &"tremor_rig",
]
const WEAPONS: Array[StringName] = [
	&"pistol", &"smg",
	&"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"arc_projector", &"rail_lance",
]
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
# --- variety milestone (append only) ---
const EN_MOTE := 4
const EN_SHARD := 5
const EN_BURSTER := 6
const EN_SPITTER := 7
const EN_SPLITTER := 8
const EN_SHIELDBEARER := 9
const EN_RECLAIMER := 10
const EN_JAMMER := 11
const EN_BORER := 12
const EN_WARD_PYLON := 13
const EN_BROOD_CARRIER := 14
const EN_LANCE_PLATFORM := 15
const EN_AEGIS_ARRAY := 16
const EN_TREMOR_RIG := 17

const WP_PISTOL := 0
const WP_SMG := 1
const WP_SCATTERGUN := 2
const WP_ASSAULT_RIFLE := 3
const WP_HORNET_RACK := 4
const WP_LMG := 5
const WP_SLAG_MORTAR := 6
const WP_CUTTING_TORCH := 7
const WP_ARC_PROJECTOR := 8
const WP_RAIL_LANCE := 9

## How many entries the legacy 5-wave content uses (content built without the variety files).
const LEGACY_ENEMY_COUNT := 4
const LEGACY_WEAPON_COUNT := 2


## -1 if unknown.
static func enemy_index(id: StringName) -> int:
	return ENEMIES.find(id)


static func weapon_index(id: StringName) -> int:
	return WEAPONS.find(id)


static func upgrade_index(id: StringName) -> int:
	return UPGRADES.find(id)


static func ability_index(id: StringName) -> int:
	return ABILITIES.find(id)
