class_name ContentSet
extends RefCounted
## All game data, typed. Built by ContentLoader, read everywhere else.

var mission: MissionDef
var enemies: Array[EnemyDef] = []  ## indexed by Ids.ENEMIES order
var weapons: Array[WeaponDef] = []
var upgrades: Array[UpgradeDef] = []  ## 5 entries; smg_unlock is synthesized from weapons.smg.unlock_scrap
var abilities: Array[AbilityDef] = []
var waves: Array[WaveDef] = []  ## index 0 = wave 1
var arena: ArenaDef
var tokens: VisualTokens
var strings: Dictionary[String, String] = {}


func enemy(id: StringName) -> EnemyDef:
	for d: EnemyDef in enemies:
		if d.id == id:
			return d
	return null


func weapon(id: StringName) -> WeaponDef:
	for d: WeaponDef in weapons:
		if d.id == id:
			return d
	return null


func upgrade(id: StringName) -> UpgradeDef:
	for d: UpgradeDef in upgrades:
		if d.id == id:
			return d
	return null


func ability(id: StringName) -> AbilityDef:
	for d: AbilityDef in abilities:
		if d.id == id:
			return d
	return null
