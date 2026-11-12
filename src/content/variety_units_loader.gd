class_name VarietyUnitsLoader
extends RefCounted
## data/weapons.json and data/enemies.json to defs (VARIETY_SPEC 13.1, CONTENT 2, 4, 5, 8). The legacy weapons
## (pistol, smg) and enemies (the first four) keep their numbers from vertical_slice_balance.json and content_ext.json
## and only gain the new fields; every other id of Ids.WEAPONS and Ids.ENEMIES must be fully described here.

const WEAPON_KEYS: PackedStringArray = [
	"tier", "kind", "damage", "shots_per_second", "magazine", "reload_seconds", "range_m", "min_range_m", "spread_deg",
	"pierce", "pierce_falloff", "area_m", "edge_frac", "pellets", "salvo", "splash_damage", "flight_s", "chains",
	"chain_range_m", "chain_falloff", "charge_s", "heat_per_shot", "cool_per_s", "heat_cap", "vent_s", "armor_ignore",
	"ward_mult", "stunned_mult", "spin_up_s", "sps_min", "stray_chance", "armor_shred", "ramp_per_hit", "ramp_cap", "pool",
	"knockback_m", "level_mult", "level3",
]
const ENEMY_KEYS: PackedStringArray = [
	"hp", "speed_mps", "armor", "core_damage", "attack_period_s", "scrap", "radius", "mass", "separation_weight",
	"weave_amp_m", "weave_period_s", "direct_seek", "is_boss", "priority_class", "slot_span", "visual_height_m", "class",
	"cost", "min_act", "alive_cap", "standoff_m", "behaviour",
]
const OVERRIDE_KEYS: PackedStringArray = ["scrap", "class", "cost", "min_act", "alive_cap"]


static func weapons(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	cs.run.swap_ticks = OpReader.ticks(r.num(d, "swap_seconds", "$"))
	cs.run.holster_reload_mult = r.num(d, "holster_reload_mult", "$")
	var wd: Dictionary = r.dict(d, "weapons", "$")
	for k: Variant in wd.keys():
		if Ids.weapon_index(StringName(str(k))) < 0:
			r.fail("$.weapons." + str(k), "unknown id")
	for i: int in Ids.WEAPONS.size():
		var key: String = String(Ids.WEAPONS[i])
		var p: String = "$.weapons." + key
		var legacy: bool = i < cs.weapons.size()
		if not wd.has(key) and legacy:
			continue
		var s: Dictionary = r.dict(wd, key, "$.weapons")
		r.check_keys(s, WEAPON_KEYS, p)
		var w: WeaponDef = cs.weapons[i] if legacy else WeaponDef.new()
		if not legacy:
			w.id = Ids.WEAPONS[i]
			w.index = i
			w.name_key = "weapon.%s.name" % key
			cs.weapons.append(w)
		if not legacy or s.has("damage"):
			w.damage = r.num(s, "damage", p)
		if not legacy or s.has("shots_per_second"):
			w.sps_milli = roundi(r.num(s, "shots_per_second", p) * 1000.0)
		if not legacy or s.has("magazine"):
			w.magazine = r.integer(s, "magazine", p)
		if not legacy or s.has("reload_seconds"):
			w.reload_ticks = OpReader.ticks(r.num(s, "reload_seconds", p))
		if not legacy or s.has("range_m"):
			w.range_m = r.num(s, "range_m", p)
		_weapon_ext(r, s, p, w)
	var td: Dictionary = r.dict(d, "turrets", "$")
	for k: Variant in td.keys():
		var key: String = str(k)
		var p: String = "$.turrets." + key
		var s: Dictionary = r.dict(td, key, "$.turrets")
		r.check_keys(s, PackedStringArray(["damage", "shots_per_second", "range_m", "min_range_m", "params"]), p)
		var t: TurretTypeDef = TurretTypeDef.new()
		t.id = StringName(key)
		t.index = cs.turret_types.size()
		t.name_key = "turret.%s.name" % key.trim_prefix("turret_")
		t.damage = r.num(s, "damage", p)
		t.sps_milli = roundi(r.num(s, "shots_per_second", p) * 1000.0)
		t.range_m = r.num(s, "range_m", p)
		t.min_range_m = r.num_or(s, "min_range_m", p, 0.0)
		t.params = OpReader.num_dict(r, s, "params", p)
		cs.turret_types.append(t)


static func _weapon_ext(r: JsonRead, s: Dictionary, p: String, w: WeaponDef) -> void:
	w.tier = r.integer(s, "tier", p)
	w.kind = OpReader.enum_index(r, s, "kind", p, WeaponDef.KIND_NAMES)
	w.min_range_m = r.num_or(s, "min_range_m", p, 0.0)
	w.spread_deg = r.num_or(s, "spread_deg", p, 0.0)
	w.pierce = OpReader.int_or(r, s, "pierce", p, 0)
	w.pierce_falloff = r.num_or(s, "pierce_falloff", p, 1.0)
	w.area_m = r.num_or(s, "area_m", p, 0.0)
	w.edge_frac = r.num_or(s, "edge_frac", p, 1.0)
	w.pellets = OpReader.int_or(r, s, "pellets", p, 0)
	w.salvo = OpReader.int_or(r, s, "salvo", p, 0)
	w.splash_damage = r.num_or(s, "splash_damage", p, 0.0)
	w.flight_ticks = OpReader.ticks(r.num_or(s, "flight_s", p, 0.0))
	w.chains = OpReader.int_or(r, s, "chains", p, 0)
	w.chain_range_m = r.num_or(s, "chain_range_m", p, 0.0)
	w.chain_falloff = r.num_or(s, "chain_falloff", p, 1.0)
	w.charge_ticks = OpReader.ticks(r.num_or(s, "charge_s", p, 0.0))
	w.heat_per_shot = OpReader.int_or(r, s, "heat_per_shot", p, 0)
	w.cool_per_s = OpReader.int_or(r, s, "cool_per_s", p, 0)
	w.heat_cap = OpReader.int_or(r, s, "heat_cap", p, 0)
	w.vent_ticks = OpReader.ticks(r.num_or(s, "vent_s", p, 0.0))
	w.armor_ignore = r.num_or(s, "armor_ignore", p, 0.0)
	w.ward_mult = r.num_or(s, "ward_mult", p, 1.0)
	w.stunned_mult = r.num_or(s, "stunned_mult", p, 1.0)
	w.spin_up_ticks = OpReader.ticks(r.num_or(s, "spin_up_s", p, 0.0))
	w.sps_min_milli = roundi(r.num_or(s, "sps_min", p, 0.0) * 1000.0)
	w.stray_chance = r.num_or(s, "stray_chance", p, 0.0)
	w.armor_shred = r.num_or(s, "armor_shred", p, 0.0)
	w.ramp_per_hit = r.num_or(s, "ramp_per_hit", p, 0.0)
	w.ramp_cap = r.num_or(s, "ramp_cap", p, 0.0)
	w.knockback_m = r.num_or(s, "knockback_m", p, 0.0)
	if s.has("pool"):
		var pool: Dictionary = r.dict(s, "pool", p)
		r.check_keys(pool, PackedStringArray(["seconds", "dps", "slow", "radius_m"]), p + ".pool")
		w.pool_ticks = OpReader.ticks(r.num(pool, "seconds", p + ".pool"))
		w.pool_dps = r.num(pool, "dps", p + ".pool")
		w.pool_slow = r.num(pool, "slow", p + ".pool")
		w.pool_radius_m = r.num(pool, "radius_m", p + ".pool")
	w.level_mult = OpReader.floats(r, s, "level_mult", p, 3)
	w.level3 = OpReader.num_dict(r, s, "level3", p)


static func enemies(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	var ed: Dictionary = r.dict(d, "enemies", "$")
	var od: Dictionary = r.dict(d, "overrides", "$")
	var legacy_n: int = cs.enemies.size()
	for k: Variant in ed.keys():
		var i: int = Ids.enemy_index(StringName(str(k)))
		if i < 0:
			r.fail("$.enemies." + str(k), "unknown id")
		elif i < legacy_n:
			r.fail("$.enemies." + str(k), "a legacy enemy belongs in $.overrides")
	for k: Variant in od.keys():
		var i: int = Ids.enemy_index(StringName(str(k)))
		if i < 0 or i >= legacy_n:
			r.fail("$.overrides." + str(k), "unknown legacy enemy id")
	for i: int in legacy_n:
		var key: String = String(Ids.ENEMIES[i])
		if not od.has(key):
			continue
		var p: String = "$.overrides." + key
		var s: Dictionary = r.dict(od, key, "$.overrides")
		r.check_keys(s, OVERRIDE_KEYS, p)
		var e: EnemyDef = cs.enemies[i]
		if s.has("scrap"):
			e.scrap = r.integer(s, "scrap", p)
		if s.has("class"):
			e.enemy_class = OpReader.enum_index(r, s, "class", p, EnemyDef.CLASS_NAMES)
		e.cost = r.num_or(s, "cost", p, e.cost)
		e.min_act = OpReader.int_or(r, s, "min_act", p, e.min_act)
		e.alive_cap = OpReader.int_or(r, s, "alive_cap", p, e.alive_cap)
	for i: int in range(legacy_n, Ids.ENEMIES.size()):
		var key: String = String(Ids.ENEMIES[i])
		var p: String = "$.enemies." + key
		var s: Dictionary = r.dict(ed, key, "$.enemies")
		r.check_keys(s, ENEMY_KEYS, p)
		var e: EnemyDef = EnemyDef.new()
		e.id = Ids.ENEMIES[i]
		e.index = i
		e.name_key = "enemy.%s.name" % key
		e.hp = r.num(s, "hp", p)
		e.speed_mps = r.num(s, "speed_mps", p)
		e.armor = r.num(s, "armor", p)
		e.core_damage = r.num(s, "core_damage", p)
		e.attack_period_ticks = OpReader.ticks(r.num(s, "attack_period_s", p))
		e.scrap = r.integer(s, "scrap", p)
		e.radius = r.num(s, "radius", p)
		e.mass = r.num(s, "mass", p)
		e.separation_weight = r.num(s, "separation_weight", p)
		e.weave_amp_m = r.num(s, "weave_amp_m", p)
		e.weave_period_ticks = OpReader.ticks(r.num(s, "weave_period_s", p))
		e.direct_seek = r.flag(s, "direct_seek", p)
		e.is_boss = r.flag(s, "is_boss", p)
		e.priority_class = r.flag(s, "priority_class", p)
		e.slot_span = r.integer(s, "slot_span", p)
		e.visual_id = e.id
		e.visual_height_m = r.num(s, "visual_height_m", p)
		e.enemy_class = OpReader.enum_index(r, s, "class", p, EnemyDef.CLASS_NAMES)
		e.cost = r.num(s, "cost", p)
		e.min_act = r.integer(s, "min_act", p)
		e.alive_cap = r.integer(s, "alive_cap", p)
		e.standoff_m = r.num_or(s, "standoff_m", p, 0.0)
		e.behaviour = OpReader.num_dict(r, s, "behaviour", p)
		cs.enemies.append(e)


## The run-wide parts of enemies.json. Called after run.json is loaded (boss escorts may name a pack).
static func elites_and_bosses(r: JsonRead, d: Dictionary, cs: ContentSet) -> void:
	var run_def: RunDef = cs.run
	var elite: Dictionary = r.dict(d, "elite", "$")
	r.check_keys(elite, PackedStringArray(["hp_mult", "scale", "scrap_mult"]), "$.elite")
	run_def.elite_hp_mult = r.num(elite, "hp_mult", "$.elite")
	run_def.elite_scale = r.num(elite, "scale", "$.elite")
	run_def.elite_scrap_mult = r.num(elite, "scrap_mult", "$.elite")
	for row: Dictionary in OpReader.rows(r, d, "affixes", "$"):
		var p: String = "$.affixes[%d]" % cs.affixes.size()
		r.check_keys(row, PackedStringArray(["id", "name_key", "ops"]), p)
		var a: AffixDef = AffixDef.new()
		a.id = StringName(r.text(row, "id", p))
		a.index = cs.affixes.size()
		a.name_key = r.text(row, "name_key", p)
		a.ops = OpReader.ops(r, row, "ops", p)
		cs.affixes.append(a)
	var rules: Dictionary = r.dict(d, "affix_rules", "$")
	r.check_keys(rules, PackedStringArray(["forbidden_pairs", "by_act"]), "$.affix_rules")
	var pairs: Array[Dictionary] = OpReader.rows(r, rules, "forbidden_pairs", "$.affix_rules")
	for i: int in pairs.size():
		var p: String = "$.affix_rules.forbidden_pairs[%d]" % i
		r.check_keys(pairs[i], ["a", "b", "until_act", "enemy"], p)
		var ia: int = cs.affix_index(StringName(r.text(pairs[i], "a", p)))
		var ib: int = cs.affix_index(StringName(r.text(pairs[i], "b", p)))
		if ia < 0 or ib < 0:
			r.fail(p, "unknown affix id")
		run_def.forbid_a.append(ia)
		run_def.forbid_b.append(ib)
		run_def.forbid_until_act.append(OpReader.int_or(r, pairs[i], "until_act", p, 0))
		run_def.forbid_enemy.append(OpReader.enemy(r, pairs[i], "enemy", p) if pairs[i].has("enemy") else -1)
	var by_act: Array[Dictionary] = OpReader.rows(r, rules, "by_act", "$.affix_rules")
	for i: int in by_act.size():
		run_def.affix_two_chance.append(r.num(by_act[i], "two_chance", "$.affix_rules.by_act[%d]" % i))
	run_def.hulk_variants = OpReader.names(r, d, "hulk_variants", "$")
	var bd: Dictionary = r.dict(d, "bosses", "$")
	for k: Variant in bd.keys():
		var key: String = str(k)
		var p: String = "$.bosses." + key
		var s: Dictionary = r.dict(bd, key, "$.bosses")
		r.check_keys(s, PackedStringArray(["pool_act", "hp", "behaviour", "escorts"]), p)
		var b: BossDef = BossDef.new()
		b.id = StringName(key)
		b.enemy_index = Ids.enemy_index(b.id)
		if b.enemy_index < 0:
			r.fail(p, "unknown enemy id")
		b.name_key = "boss.%s.name" % key
		b.banner_key = "boss.%s.banner" % key
		b.pool_act = r.integer(s, "pool_act", p)
		b.hp = r.num(s, "hp", p)
		b.behaviour = OpReader.num_dict(r, s, "behaviour", p)
		var escorts: Array[Dictionary] = OpReader.rows(r, s, "escorts", p)
		for i: int in escorts.size():
			var pe: String = "%s.escorts[%d]" % [p, i]
			r.check_keys(escorts[i], ["enemy", "share", "pack"], pe)
			if escorts[i].has("pack"):
				b.escort_pack = StringName(r.text(escorts[i], "pack", pe))
				if run_def.pack_index(b.escort_pack) < 0:
					r.fail(pe + ".pack", "unknown pack id '%s'" % String(b.escort_pack))
			else:
				b.escort_enemy.append(OpReader.enemy(r, escorts[i], "enemy", pe))
				b.escort_share.append(r.num(escorts[i], "share", pe))
		cs.bosses.append(b)
