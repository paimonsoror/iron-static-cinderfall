class_name VarietyLoader
extends RefCounted
## Loads the six variety data files (VARIETY_SPEC 13.1) onto a ContentSet that already holds the legacy content:
## run.json, weapons.json, enemies.json, directives.json, events.json, unlocks.json. A straight mapping from JSON to
## defs; range and consistency rules are VarietyValidator's. ContentLoader.build calls `apply` only when its 7th
## parameter is not empty, so content built without these files is exactly the legacy content.

const FILES: PackedStringArray = ["run.json", "weapons.json", "enemies.json", "directives.json", "events.json", "unlocks.json"]
const SCHEMA: int = 1
const KEYS_RUN: PackedStringArray = [
	"schema_version", "note", "acts", "waves", "packs", "modifiers", "route_rewards", "draft", "salvage", "caps", "reward",
	"mission",
]
const KEYS_WEAPONS: PackedStringArray = ["schema_version", "note", "weapons", "turrets", "swap_seconds", "holster_reload_mult"]
const KEYS_ENEMIES: PackedStringArray = [
	"schema_version", "note", "enemies", "overrides", "elite", "affixes", "affix_rules", "bosses", "hulk_variants",
]
const KEYS_DIRECTIVES: PackedStringArray = ["schema_version", "note", "directives"]
const KEYS_EVENTS: PackedStringArray = ["schema_version", "note", "events", "hazards", "rules"]
const KEYS_UNLOCKS: PackedStringArray = ["schema_version", "note", "unlocks", "kits", "tier_gates", "milestones"]


## `variety` maps a file name of FILES to its parsed JSON. All six are required. Errors are appended to `errors`.
static func apply(cs: ContentSet, variety: Dictionary, errors: PackedStringArray) -> void:
	var readers: Dictionary[String, JsonRead] = {}
	var docs: Dictionary[String, Dictionary] = {}
	var keys: Array[PackedStringArray] = [KEYS_RUN, KEYS_WEAPONS, KEYS_ENEMIES, KEYS_DIRECTIVES, KEYS_EVENTS, KEYS_UNLOCKS]
	for i: int in FILES.size():
		var file: String = FILES[i]
		var r: JsonRead = JsonRead.new(file)
		readers[file] = r
		docs[file] = {}
		var v: Variant = variety.get(file)
		if typeof(v) != TYPE_DICTIONARY:
			r.fail("$", "file missing from the variety set (all of %s are required)" % ", ".join(FILES))
			continue
		var doc: Dictionary = v
		docs[file] = doc
		var before: int = r.errors.size()
		var got: int = r.integer(doc, "schema_version", "$")
		if r.errors.size() == before and got != SCHEMA:
			r.fail("$.schema_version", "expected %d, got %d" % [SCHEMA, got])
		r.check_keys(doc, keys[i], "$")
	var missing: bool = false
	for file: String in FILES:
		if docs[file].is_empty():
			missing = true
	if not missing:
		var run: RunDef = RunDef.new()
		cs.run = run
		VarietyUnitsLoader.weapons(readers["weapons.json"], docs["weapons.json"], cs)
		VarietyUnitsLoader.enemies(readers["enemies.json"], docs["enemies.json"], cs)
		VarietyRunLoader.run(readers["run.json"], docs["run.json"], cs)
		VarietyUnitsLoader.elites_and_bosses(readers["enemies.json"], docs["enemies.json"], cs)
		VarietyMetaLoader.directives(readers["directives.json"], docs["directives.json"], cs)
		VarietyMetaLoader.events(readers["events.json"], docs["events.json"], cs)
		VarietyMetaLoader.unlocks(readers["unlocks.json"], docs["unlocks.json"], cs)
	for file: String in FILES:
		errors.append_array(readers[file].errors)
