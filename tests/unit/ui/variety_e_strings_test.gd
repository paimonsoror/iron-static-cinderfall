extends GdUnitTestSuite
## Every string the variety UI shows exists in the string tables (data/strings/variety_en.json is V2-E's file in wave V2):
## the literal keys of src/ui/run and src/ui/combat, the keys built from ids (weapons, bosses, events, acts, packs, modifiers,
## rewards, directives, tags, affixes) and the lore rules of the new lines (CHORUS logs lowercase, no skulls).

const PREFIXES: String = "draft|route|salvage|boss_brief|boss|directive|tag|hud|weapon|event|act|modifier|reward|build|ui|enemy|affix|reason|pack|menu|hint"


func _literal_keys(dir: String) -> Array[String]:
	var found: Array[String] = []
	var rx: RegEx = RegEx.new()
	rx.compile("\"((?:%s)\\.[a-z0-9_.]*[a-z0-9_])\"" % PREFIXES)
	for file: String in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(dir + "/" + file)
		for m: RegExMatch in rx.search_all(source):
			var key: String = m.get_string(1)
			if not found.has(key):
				found.append(key)
	return found


func test_every_literal_key_of_the_run_screens_and_the_combat_hud_exists() -> void:
	var keys: Array[String] = _literal_keys("res://src/ui/run")
	keys.append_array(_literal_keys("res://src/ui/combat"))
	assert_int(keys.size()).is_greater(60)
	for key: String in keys:
		assert_bool(Content.db.strings.has(key)).override_failure_message("missing string '%s'" % key).is_true()


func test_every_weapon_has_a_name_a_short_name_and_a_rules_line() -> void:
	for id: StringName in Ids.WEAPONS:
		for part: String in ["name", "short", "desc"]:
			var key: String = "weapon.%s.%s" % [String(id), part]
			assert_bool(Content.db.strings.has(key)).override_failure_message("missing string '%s'" % key).is_true()
		assert_bool(Content.db.strings.has("weapon.%s.short" % String(id))).is_true()
		assert_int(Strings.t("weapon.%s.short" % String(id)).length()).is_less_equal(10)  # it has to fit a 300 px card at 30 px


func test_every_boss_has_its_lines_and_every_event_its_name() -> void:
	var content: ContentSet = TestContent.variety()
	for id: String in ["brood_carrier", "lance_platform", "aegis_array", "tremor_rig", "siege_hulk", "hulk_plated", "hulk_fed", "hulk_overclocked"]:
		for part: String in ["attack", "answer"]:
			assert_bool(Content.db.strings.has("boss.%s.%s" % [id, part])).override_failure_message("boss.%s.%s" % [id, part]).is_true()
	for def: EventDef in content.events:
		assert_bool(Content.db.strings.has(def.name_key)).is_true()
	for id: String in ["deadfall_strike", "core_vent", "freight_call", "accord_window", "supply_drop", "power_surge", "runaway_freight", "static_front", "floor_breach", "recount"]:
		assert_bool(Content.db.strings.has("event.%s.name" % id)).override_failure_message("event.%s.name" % id).is_true()


func test_the_names_of_the_acts_packs_modifiers_rewards_directives_and_tags_exist() -> void:
	var content: ContentSet = TestContent.variety()
	var keys: Array[String] = []
	for a: ActDef in content.run.acts:
		keys.append(a.name_key)
	for p: PackDef in content.run.packs:
		keys.append(p.name_key)
	for m: ModifierDef in content.run.modifiers:
		keys.append(m.name_key)
		keys.append(m.name_key.trim_suffix(".name") + ".desc")
	for r: RewardDef in content.run.route_rewards:
		keys.append(r.name_key)
	for d: DirectiveDef in content.directives:
		keys.append(d.name_key)
		keys.append(d.desc_key)
		for tag: StringName in d.tags:
			keys.append("tag.%s" % String(tag))
	for tag: String in RunUi.TAGS:
		keys.append("tag.%s" % tag)
	for a: AffixDef in content.affixes:
		keys.append(a.name_key)
	for key: String in keys:
		assert_bool(Content.db.strings.has(key)).override_failure_message("missing string '%s'" % key).is_true()
	for id: String in ["bullet", "blast", "arc", "fortress", "gunline", "hoard", "tempo", "rail"]:
		assert_bool(ResourceLoader.exists("res://assets/icons/tag_%s.svg" % id)).is_true()
	for id: String in ["common", "rare", "prototype", "corrupted"]:
		assert_bool(ResourceLoader.exists("res://assets/icons/frame_%s.svg" % id)).is_true()
	for id: StringName in Ids.WEAPONS:
		assert_bool(ResourceLoader.exists("res://assets/icons/weapon_%s.svg" % String(id))).is_true()


func test_every_placeholder_string_keeps_its_arguments() -> void:
	var cases: Dictionary[String, int] = {
		"draft.reroll": 1, "draft.patch": 2, "draft.skip": 1, "draft.buyout": 1, "draft.confirm": 1, "draft.confirm_both": 2,
		"draft.cleared": 1, "route.wave_of": 2, "route.hostiles": 1, "route.elites": 1, "route.confirm": 1, "route.glyph_count": 1,
		"salvage.scrap_it": 1, "salvage.level_up": 3, "salvage.confirm_replace": 1, "salvage.confirm_take": 1, "salvage.tier": 1,
		"salvage.level": 1, "hud.wave_short": 2, "hud.call.charges": 1, "hud.call.vent_price": 1, "hud.ticker.in": 2, "hud.ticker.on": 2,
		"hud.ticker.elite": 1, "hud.weapon.heat_pct": 1, "hud.act_banner.title": 2, "act.tier": 1, "act.label": 1, "directive.stacks": 3,
		"weapon.stat.dmg": 1, "weapon.stat.rate": 1, "weapon.stat.area": 1, "weapon.stat.mag": 1, "weapon.stat.reload": 1, "build.stacks": 1,
	}
	for key: String in cases:
		var args: Array = []
		for i: int in cases[key]:
			args.append(i + 1)
		assert_str(Strings.tf(key, args)).override_failure_message("placeholder count of '%s'" % key).is_not_equal("#%s#" % key)


func test_the_new_chorus_log_lines_are_lowercase_and_nothing_breaks_the_canon() -> void:
	for id: String in ["brood_carrier", "lance_platform", "aegis_array", "tremor_rig", "siege_hulk"]:
		var banner: String = Strings.t("boss.%s.banner" % id)
		assert_str(banner).is_equal(banner.to_lower())
	var all: String = ""
	for key: String in Content.db.strings:
		if key.begins_with("boss.") or key.begins_with("weapon.") or key.begins_with("directive."):
			all += Content.db.strings[key].to_lower() + " "
	for word: String in ["skull", "terminator", "9mm", "workshop", "cash"]:
		assert_bool(all.contains(word)).override_failure_message("forbidden word '%s'" % word).is_false()
