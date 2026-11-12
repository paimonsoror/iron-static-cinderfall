class_name VarietyMetaLoader
extends RefCounted
## data/directives.json, data/events.json and data/unlocks.json to defs (VARIETY_SPEC 13.1, CONTENT 3, 6, 10 to 12).


static func directives(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	for row: Dictionary in OpReader.rows(r, d, "directives", "$"):
		var p: String = "$.directives[%d]" % cs.directives.size()
		r.check_keys(row, PackedStringArray(["id", "category", "rarity", "max", "tags", "requires", "ops", "hook", "pool"]), p)
		var def: DirectiveDef = DirectiveDef.new()
		var key: String = r.text(row, "id", p)
		def.id = StringName(key)
		def.index = cs.directives.size()
		def.name_key = "directive.%s.name" % key
		def.desc_key = "directive.%s.desc" % key
		def.category = OpReader.enum_index(r, row, "category", p, DirectiveDef.CATEGORY_NAMES)
		def.rarity = OpReader.enum_index(r, row, "rarity", p, DirectiveDef.RARITY_NAMES)
		def.max_stacks = r.integer(row, "max", p)
		def.tags = OpReader.names(r, row, "tags", p)
		var req: Dictionary = r.dict(row, "requires", p)
		for k: Variant in req.keys():
			var ks: String = str(k)
			if not DirectiveDef.REQUIRE_KEYS.has(ks):
				r.fail("%s.requires.%s" % [p, ks], "unknown key")
			elif ks == "weapon_kind":
				def.requires[&"weapon_kind"] = float(OpReader.enum_index(r, req, ks, p + ".requires", WeaponDef.KIND_NAMES))
			else:
				def.requires[StringName(ks)] = r.num(req, ks, p + ".requires")
		def.ops = OpReader.ops(r, row, "ops", p)
		def.hook = StringName(r.text_or(row, "hook", p, ""))
		def.pool = StringName(r.text(row, "pool", p))
		cs.directives.append(def)


static func events(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	for row: Dictionary in OpReader.rows(r, d, "events", "$"):
		var p: String = "$.events[%d]" % cs.events.size()
		r.check_keys(row, PackedStringArray(["id", "who", "name_key", "warn_s", "duration_s", "weights", "boss_safe", "harmful", "params"]), p)
		var def: EventDef = EventDef.new()
		def.id = StringName(r.text(row, "id", p))
		def.index = cs.events.size()
		def.who = OpReader.enum_index(r, row, "who", p, EventDef.WHO_NAMES)
		def.name_key = r.text(row, "name_key", p)
		def.warn_ticks = OpReader.ticks(r.num(row, "warn_s", p))
		def.duration_ticks = OpReader.ticks(r.num(row, "duration_s", p))
		def.weights = OpReader.floats(r, row, "weights", p, 3)
		def.boss_safe = r.flag(row, "boss_safe", p)
		def.harmful = r.flag(row, "harmful", p)
		def.params = OpReader.num_dict(r, row, "params", p)
		cs.events.append(def)
	var hazards: Dictionary = r.dict(d, "hazards", "$")
	for k: Variant in hazards.keys():
		cs.run.hazards[StringName(str(k))] = OpReader.num_dict(r, hazards, str(k), "$.hazards")
	var rules: Dictionary = r.dict(d, "rules", "$")
	r.check_keys(rules, PackedStringArray(["window_min", "window_max", "mercy_core_frac"]), "$.rules")
	cs.run.event_window_min = r.num(rules, "window_min", "$.rules")
	cs.run.event_window_max = r.num(rules, "window_max", "$.rules")
	cs.run.mercy_core_frac = r.num(rules, "mercy_core_frac", "$.rules")


static func unlocks(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	for row: Dictionary in OpReader.rows(r, d, "unlocks", "$"):
		var p: String = "$.unlocks[%d]" % cs.unlocks.size()
		r.check_keys(row, PackedStringArray(["id", "branch", "tier", "cost", "grants"]), p)
		var def: UnlockDef = UnlockDef.new()
		var key: String = r.text(row, "id", p)
		def.id = StringName(key)
		def.index = cs.unlocks.size()
		def.name_key = "archive.%s.name" % key
		def.branch = OpReader.enum_index(r, row, "branch", p, UnlockDef.BRANCH_NAMES)
		def.tier = r.integer(row, "tier", p)
		def.cost = r.integer(row, "cost", p)
		def.grants = OpReader.names(r, row, "grants", p)
		cs.unlocks.append(def)
	for row: Dictionary in OpReader.rows(r, d, "kits", "$"):
		var p: String = "$.kits[%d]" % cs.kits.size()
		r.check_keys(row, PackedStringArray(["id", "name_key", "cost", "ops"]), p)
		var kit: KitDef = KitDef.new()
		kit.id = StringName(r.text(row, "id", p))
		kit.index = cs.kits.size()
		kit.name_key = r.text(row, "name_key", p)
		kit.cost = r.integer(row, "cost", p)
		kit.ops = OpReader.ops(r, row, "ops", p)
		cs.kits.append(kit)
	cs.run.tier_gates = OpReader.ints(r, d, "tier_gates", "$", -1)
	var milestones: Array[Dictionary] = OpReader.rows(r, d, "milestones", "$")
	for i: int in milestones.size():
		var p: String = "$.milestones[%d]" % i
		r.check_keys(milestones[i], ["id", "data"], p)
		cs.run.milestones[StringName(r.text(milestones[i], "id", p))] = r.integer(milestones[i], "data", p)
