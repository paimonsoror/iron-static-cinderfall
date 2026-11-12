class_name ContentSet
extends RefCounted
## All game data, typed. Built by ContentLoader, read everywhere else.

var mission: MissionDef
var enemies: Array[EnemyDef] = []  ## indexed by Ids.ENEMIES order (4 in the legacy content, all 18 with variety)
var weapons: Array[WeaponDef] = []  ## indexed by Ids.WEAPONS order (2 in the legacy content, all 10 with variety)
var upgrades: Array[UpgradeDef] = []  ## 5 entries; smg_unlock is synthesized from weapons.smg.unlock_scrap
var abilities: Array[AbilityDef] = []
var waves: Array[WaveDef] = []  ## index 0 = wave 1 (the legacy scripted waves)
var arena: ArenaDef
var tokens: VisualTokens
var strings: Dictionary[String, String] = {}
# --- variety milestone (VARIETY_SPEC 13.1). `run` is null and the lists are empty in the legacy content. ---
var run: RunDef
var directives: Array[DirectiveDef] = []  ## index = position in directives.json
var events: Array[EventDef] = []  ## index = position in events.json
var unlocks: Array[UnlockDef] = []
var affixes: Array[AffixDef] = []  ## index = the bit of the affix mask
var bosses: Array[BossDef] = []
var kits: Array[KitDef] = []  ## index = SimConfig.kit_index; kit 0 is the standard kit
var turret_types: Array[TurretTypeDef] = []


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


## True for content built with the variety files (a generated run); false for the legacy 5-wave content.
func is_variety() -> bool:
	return run != null


func directive(id: StringName) -> DirectiveDef:
	for d: DirectiveDef in directives:
		if d.id == id:
			return d
	return null


## -1 if unknown.
func directive_index(id: StringName) -> int:
	var d: DirectiveDef = directive(id)
	return d.index if d != null else -1


func event_def(id: StringName) -> EventDef:
	for d: EventDef in events:
		if d.id == id:
			return d
	return null


func event_index(id: StringName) -> int:
	var d: EventDef = event_def(id)
	return d.index if d != null else -1


func affix_index(id: StringName) -> int:
	for d: AffixDef in affixes:
		if d.id == id:
			return d.index
	return -1


func boss(id: StringName) -> BossDef:
	for d: BossDef in bosses:
		if d.id == id:
			return d
	return null


func unlock(id: StringName) -> UnlockDef:
	for d: UnlockDef in unlocks:
		if d.id == id:
			return d
	return null


func kit(id: StringName) -> KitDef:
	for d: KitDef in kits:
		if d.id == id:
			return d
	return null


func kit_index(id: StringName) -> int:
	var d: KitDef = kit(id)
	return d.index if d != null else -1
