class_name ContentLoader
extends RefCounted
## Maps the JSON files in res://data to typed defs (ARCH 5). Wave 0 does the straight mapping with basic
## checks (file present, JSON parses, ids known, required keys, schema versions). TODO(W1-D): full rules,
## better messages, ContentValidator.

const FILES: PackedStringArray = ["vertical_slice_balance.json", "waves.json", "visual_tokens.json", "content_ext.json", "arena.json"]
const STRING_FILES: PackedStringArray = ["content_en.json", "combat_en.json", "screens_en.json", "lore_en.json"]
const TICK_RATE: int = 60  ## must equal SimWorld.TICK_RATE (content may not depend on the sim layer)
const BALANCE_UPGRADES: Array[StringName] = [&"damage", &"fire_rate", &"armor_piercing", &"auto_turret"]
const SCHEMA_BALANCE: int = 2
const SCHEMA_WAVES: int = 2
const SCHEMA_EXT: int = 1
const SCHEMA_ARENA: int = 1


## dir = "res://data". Reads the five data files and data/strings/*_en.json.
static func load_from_dir(dir: String) -> ContentLoadResult:
	var res: ContentLoadResult = ContentLoadResult.new()
	var docs: Array[Dictionary] = []
	for f: String in FILES:
		docs.append(_read_json(dir + "/" + f, f, res.errors))
	var strings: Dictionary = {}
	for f: String in STRING_FILES:
		var d: Dictionary = _read_json(dir + "/strings/" + f, "strings/" + f, res.errors)
		for k: Variant in d.keys():
			var ks: String = str(k)
			if typeof(d[k]) != TYPE_STRING:
				res.errors.append("strings/%s: $.%s: not a string" % [f, ks])
			elif strings.has(ks):
				res.errors.append("strings/%s: $.%s: duplicate key" % [f, ks])
			else:
				strings[ks] = d[k]
	if not res.errors.is_empty():
		return res
	var built: ContentLoadResult = build(docs[0], docs[1], docs[2], docs[3], docs[4], strings)
	return built


static func build(
	balance: Dictionary, waves: Dictionary, tokens: Dictionary, ext: Dictionary, arena: Dictionary, strings: Dictionary
) -> ContentLoadResult:
	var res: ContentLoadResult = ContentLoadResult.new()
	var cs: ContentSet = ContentSet.new()
	var rb: JsonRead = JsonRead.new("vertical_slice_balance.json")
	var rw: JsonRead = JsonRead.new("waves.json")
	var rt: JsonRead = JsonRead.new("visual_tokens.json")
	var re: JsonRead = JsonRead.new("content_ext.json")
	var ra: JsonRead = JsonRead.new("arena.json")
	_check_schema(rb, balance, SCHEMA_BALANCE)
	_check_schema(rw, waves, SCHEMA_WAVES)
	_check_schema(re, ext, SCHEMA_EXT)
	_check_schema(ra, arena, SCHEMA_ARENA)
	cs.mission = _mission(rb, re, balance, ext)
	cs.enemies = _enemies(rb, re, balance, ext)
	cs.weapons = _weapons(rb, balance)
	cs.upgrades = _upgrades(rb, re, balance, ext)
	cs.abilities = _abilities(rb, re, balance, ext)
	cs.arena = ArenaBuilder.build(ra, arena)
	cs.waves = _waves(rw, waves, cs.arena)
	cs.tokens = _tokens(rt, tokens)
	for k: Variant in strings.keys():
		cs.strings[str(k)] = str(strings[k])
	for r: JsonRead in [rb, rw, rt, re, ra]:
		res.errors.append_array(r.errors)
	if res.errors.is_empty():
		res.content = cs
	return res


static func _read_json(path: String, label: String, errors: PackedStringArray) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("%s: file missing (%s)" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: not a JSON object or does not parse" % label)
		return {}
	var out: Dictionary = parsed
	return out


static func _check_schema(r: JsonRead, d: Dictionary, expected: int) -> void:
	var got: int = r.integer(d, "schema_version", "$")
	if got != expected:
		r.fail("$.schema_version", "expected %d, got %d" % [expected, got])


static func _ticks(seconds: float) -> int:
	return roundi(seconds * float(TICK_RATE))


static func _mission(rb: JsonRead, re: JsonRead, b: Dictionary, e: Dictionary) -> MissionDef:
	var m: MissionDef = MissionDef.new()
	var em: Dictionary = re.dict(e, "mission", "$")
	var rew: Dictionary = rb.dict(b, "reward", "$")
	var tgt: Dictionary = rb.dict(b, "targeting", "$")
	m.id = StringName(rb.text(b, "mission_id", "$"))
	m.name_key = "mission.%s.name" % String(m.id)
	m.core_max_hp = rb.num(b, "core_max_hp", "$")
	m.ticks_per_second = rb.integer(b, "sim_ticks_per_second", "$")
	if m.ticks_per_second != TICK_RATE:
		rb.fail("$.sim_ticks_per_second", "expected %d, got %d" % [TICK_RATE, m.ticks_per_second])
	m.enemy_cap = rb.integer(b, "simultaneous_enemy_cap", "$")
	m.intermission_ticks = _ticks(rb.num(b, "intermission_seconds", "$"))
	m.prepare_ticks = _ticks(re.num(em, "prepare_seconds", "$.mission"))
	var dur: Array = rb.list(b, "target_duration_seconds", "$")
	if dur.size() == 2:
		m.target_duration_min_s = rb.as_num(dur[0], "$.target_duration_seconds[0]")
		m.target_duration_max_s = rb.as_num(dur[1], "$.target_duration_seconds[1]")
	elif not dur.is_empty():
		rb.fail("$.target_duration_seconds", "expected two numbers")
	m.reward_victory_base = rb.integer(rew, "victory_base_data", "$.reward")
	m.reward_core_hp_divisor = rb.integer(rew, "victory_bonus_core_hp_divisor", "$.reward")
	m.reward_defeat_per_wave = rb.integer(rew, "defeat_data_per_completed_wave", "$.reward")
	m.lock_ticks = _ticks(rb.num(tgt, "lock_seconds", "$.targeting"))
	m.eta_bucket_ticks = _ticks(re.num(em, "eta_bucket_seconds", "$.mission"))
	m.max_spawns_per_tick = re.integer(em, "max_spawns_per_tick", "$.mission")
	m.stuck_ticks = _ticks(re.num(em, "stuck_seconds", "$.mission"))
	m.stuck_min_progress_m = re.num(em, "stuck_min_progress_m", "$.mission")
	return m


static func _enemies(rb: JsonRead, re: JsonRead, b: Dictionary, e: Dictionary) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var bd: Dictionary = rb.dict(b, "enemies", "$")
	var ed: Dictionary = re.dict(e, "enemies", "$")
	_check_ids(rb, bd, Ids.ENEMIES, "$.enemies")
	_check_ids(re, ed, Ids.ENEMIES, "$.enemies")
	for i: int in Ids.ENEMIES.size():
		var key: String = String(Ids.ENEMIES[i])
		var pb: String = "$.enemies." + key
		var sb: Dictionary = rb.dict(bd, key, "$.enemies")
		var se: Dictionary = re.dict(ed, key, "$.enemies")
		var d: EnemyDef = EnemyDef.new()
		d.id = Ids.ENEMIES[i]
		d.index = i
		d.name_key = "enemy.%s.name" % key
		d.hp = rb.num(sb, "hp", pb)
		d.speed_mps = rb.num(sb, "speed_mps", pb)
		d.armor = rb.num(sb, "armor", pb)
		d.core_damage = rb.num(sb, "core_damage", pb)
		d.attack_period_ticks = _ticks(rb.num(sb, "attack_period_s", pb))
		d.scrap = rb.integer(sb, "scrap", pb)
		d.radius = re.num(se, "radius", pb)
		d.mass = re.num(se, "mass", pb)
		d.separation_weight = re.num(se, "separation_weight", pb)
		d.weave_amp_m = re.num(se, "weave_amp_m", pb)
		d.weave_period_ticks = _ticks(re.num(se, "weave_period_s", pb))
		d.direct_seek = re.flag(se, "direct_seek", pb)
		d.is_boss = re.flag(se, "is_boss", pb)
		d.priority_class = re.flag(se, "priority_class", pb)
		d.slot_span = re.integer(se, "slot_span", pb)
		d.visual_id = d.id
		d.visual_height_m = re.num(se, "visual_height_m", pb)
		out.append(d)
	return out


static func _weapons(rb: JsonRead, b: Dictionary) -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	var wd: Dictionary = rb.dict(b, "weapons", "$")
	_check_ids(rb, wd, Ids.WEAPONS, "$.weapons")
	for i: int in Ids.WEAPONS.size():
		var key: String = String(Ids.WEAPONS[i])
		var p: String = "$.weapons." + key
		var s: Dictionary = rb.dict(wd, key, "$.weapons")
		var d: WeaponDef = WeaponDef.new()
		d.id = Ids.WEAPONS[i]
		d.index = i
		d.name_key = "weapon.%s.name" % key
		d.damage = rb.num(s, "damage", p)
		d.sps_milli = roundi(rb.num(s, "shots_per_second", p) * 1000.0)
		d.magazine = rb.integer(s, "magazine", p)
		d.reload_ticks = _ticks(rb.num(s, "reload_seconds", p))
		d.range_m = rb.num(s, "range_m", p)
		out.append(d)
	return out


static func _upgrades(rb: JsonRead, re: JsonRead, b: Dictionary, e: Dictionary) -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	var bd: Dictionary = rb.dict(b, "upgrades", "$")
	var ed: Dictionary = re.dict(e, "upgrades", "$")
	var wd: Dictionary = rb.dict(b, "weapons", "$")
	var smg: Dictionary = rb.dict(wd, "smg", "$.weapons")
	for i: int in Ids.UPGRADES.size():
		var key: String = String(Ids.UPGRADES[i])
		var p: String = "$.upgrades." + key
		var se: Dictionary = re.dict(ed, key, "$.upgrades")
		var d: UpgradeDef = UpgradeDef.new()
		d.id = Ids.UPGRADES[i]
		d.index = i
		d.name_key = "upgrade.%s.name" % key
		var kind_text: String = re.text(se, "kind", p)
		match kind_text:
			"stat":
				d.kind = UpgradeDef.Kind.STAT
			"turret":
				d.kind = UpgradeDef.Kind.TURRET
			"weapon_unlock":
				d.kind = UpgradeDef.Kind.WEAPON_UNLOCK
			_:
				re.fail(p + ".kind", "unknown kind '%s'" % kind_text)
		d.min_wave = re.integer(se, "min_wave", p)
		d.cap = re.num_or(se, "cap", p, 0.0)
		if key == "smg_unlock":
			d.base_cost = rb.integer(smg, "unlock_scrap", "$.weapons.smg")
			d.growth = 1.0
			d.max_level = 1
			d.per_level = 0.0
			d.weapon_index = Ids.weapon_index(StringName(re.text(se, "weapon", p)))
			if d.weapon_index < 0:
				re.fail(p + ".weapon", "unknown weapon id")
		else:
			var sb: Dictionary = rb.dict(bd, key, "$.upgrades")
			d.base_cost = rb.integer(sb, "base_cost", p)
			d.growth = rb.num(sb, "growth", p)
			d.max_level = rb.integer(sb, "max_level", p)
			d.per_level = rb.num_or(sb, "per_level", p, 0.0)
			if key == "auto_turret":
				d.turret_damage = rb.num(sb, "turret_damage", p)
				d.turret_sps_milli = roundi(rb.num(sb, "turret_sps", p) * 1000.0)
				d.turret_range_m = rb.num(sb, "turret_range_m", p)
				d.turret_lock_ticks = _ticks(re.num(se, "lock_seconds", p))
		out.append(d)
	_check_ids(rb, bd, BALANCE_UPGRADES, "$.upgrades")
	return out


static func _abilities(rb: JsonRead, re: JsonRead, b: Dictionary, e: Dictionary) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	var bd: Dictionary = rb.dict(b, "abilities", "$")
	var ed: Dictionary = re.dict(e, "abilities", "$")
	_check_ids(rb, bd, Ids.ABILITIES, "$.abilities")
	for i: int in Ids.ABILITIES.size():
		var key: String = String(Ids.ABILITIES[i])
		var p: String = "$.abilities." + key
		var sb: Dictionary = rb.dict(bd, key, "$.abilities")
		var se: Dictionary = re.dict(ed, key, "$.abilities")
		var d: AbilityDef = AbilityDef.new()
		d.id = Ids.ABILITIES[i]
		d.index = i
		d.name_key = "ability.%s.name" % key
		d.cooldown_ticks = _ticks(rb.num(sb, "cooldown_s", p))
		match re.text(se, "cooldown_starts", p):
			"on_activate":
				d.cooldown_start = AbilityDef.CooldownStart.ON_ACTIVATE
			"on_end":
				d.cooldown_start = AbilityDef.CooldownStart.ON_END
			_:
				re.fail(p + ".cooldown_starts", "expected on_activate or on_end")
		match key:
			"emp":
				d.stun_ticks = _ticks(rb.num(sb, "normal_stun_s", p))
				d.boss_stun_ticks = _ticks(rb.num(sb, "boss_stun_s", p))
				d.boss_immunity_ticks = _ticks(re.num(se, "boss_immunity_s", p))
			"shield":
				d.absorb = rb.num(sb, "absorb_damage", p)
				d.duration_ticks = _ticks(rb.num(sb, "duration_s", p))
			"overdrive":
				d.fire_rate_mult_milli = roundi(rb.num(sb, "fire_rate_multiplier", p) * 1000.0)
				d.duration_ticks = _ticks(rb.num(sb, "duration_s", p))
		out.append(d)
	return out


static func _waves(r: JsonRead, w: Dictionary, arena: ArenaDef) -> Array[WaveDef]:
	var out: Array[WaveDef] = []
	var rows: Array = r.list(w, "waves", "$")
	for wi: int in rows.size():
		var pw: String = "$.waves[%d]" % wi
		if typeof(rows[wi]) != TYPE_DICTIONARY:
			r.fail(pw, "not an object")
			continue
		var wd: Dictionary = rows[wi]
		var def: WaveDef = WaveDef.new()
		def.index = r.integer(wd, "index", pw)
		def.peak_target = r.integer(wd, "peak_target", pw)
		var groups: Array = r.list(wd, "groups", pw)
		for gi: int in groups.size():
			var pg: String = "%s.groups[%d]" % [pw, gi]
			if typeof(groups[gi]) != TYPE_DICTIONARY:
				r.fail(pg, "not an object")
				continue
			var gd: Dictionary = groups[gi]
			var g: SpawnGroupDef = SpawnGroupDef.new()
			var enemy_id: String = r.text(gd, "enemy", pg)
			g.enemy_index = Ids.enemy_index(StringName(enemy_id))
			if g.enemy_index < 0:
				r.fail(pg + ".enemy", "unknown enemy id '%s'" % enemy_id)
			g.count = r.integer(gd, "count", pg)
			g.start_tick = _ticks(r.num(gd, "start_s", pg))
			g.interval_ticks = _ticks(r.num(gd, "interval_s", pg))
			g.region_id = StringName(r.text(gd, "region", pg))
			if arena != null and arena.region(g.region_id) == null:
				r.fail(pg + ".region", "unknown spawn region '%s'" % String(g.region_id))
			def.groups.append(g)
		out.append(def)
	return out


static func _tokens(r: JsonRead, t: Dictionary) -> VisualTokens:
	var v: VisualTokens = VisualTokens.new()
	var pal: Dictionary = r.dict(t, "palette", "$")
	for name_key: String in ["obsidian", "warden_cyan", "core_amber", "chorus_red", "gunmetal", "bone_ceramic"]:
		var hex: String = r.text(pal, name_key, "$.palette")
		if hex.is_valid_html_color():
			v.palette[StringName(name_key)] = Color.html(hex)
		else:
			r.fail("$.palette." + name_key, "not a color: '%s'" % hex)
	var cam: Dictionary = r.dict(t, "camera", "$")
	var ui: Dictionary = r.dict(t, "ui", "$")
	v.down_angle_min_deg = r.num(cam, "down_angle_deg_min", "$.camera")
	v.down_angle_max_deg = r.num(cam, "down_angle_deg_max", "$.camera")
	v.top_hud_fraction = r.num(ui, "top_hud_fraction", "$.ui")
	v.bottom_controls_fraction = r.num(ui, "bottom_controls_fraction", "$.ui")
	v.touch_target_min_dp = r.integer(ui, "touch_target_min_dp", "$.ui")
	v.text_contrast_target = r.num(ui, "text_contrast_target", "$.ui")
	return v


## Reports keys of `d` that are not in `ids`.
static func _check_ids(r: JsonRead, d: Dictionary, ids: Array[StringName], path: String) -> void:
	for k: Variant in d.keys():
		if not ids.has(StringName(str(k))):
			r.fail(path + "." + str(k), "unknown id")
