class_name ContentValidator
extends RefCounted
## Strict rules on the typed ContentSet (ARCH 5.4): finite and sensible numbers, a complete wave plan, ids and
## regions that resolve, enough attack slots, a clear approach, reachable spawns, six palette tokens, a string for
## every name. The loader owns structural problems (types, missing keys, schema versions, unknown keys). Every
## message reads "<file>: <JSON path>: <problem>" and names the source file and path the value came from.

const BAL: String = "vertical_slice_balance.json"
const EXT: String = "content_ext.json"
const WAVES: String = "waves.json"
const ARENA: String = "arena.json"
const TOKENS: String = "visual_tokens.json"
const STRINGS: String = "strings/content_en.json"
const WAVE_COUNT: int = 5
const PALETTE: Array[StringName] = [&"obsidian", &"warden_cyan", &"core_amber", &"chorus_red", &"gunmetal", &"bone_ceramic"]
## The content layer may not name sim classes (tools/lint_layers.py), so the flow field is resolved by path.
const FLOW_FIELD_SCRIPT: String = "res://src/sim/nav/flow_field.gd"


## Returns one message per problem; empty when the content is valid.
static func validate(content: ContentSet) -> PackedStringArray:
	var e: PackedStringArray = PackedStringArray()
	if content == null or content.mission == null or content.arena == null or content.tokens == null:
		e.append("content: no content, or mission, arena or tokens missing")
		return e
	_mission(e, content.mission)
	_enemies(e, content)
	_weapons(e, content)
	_upgrades(e, content)
	_abilities(e, content)
	_waves(e, content)
	_arena(e, content)
	_tokens(e, content.tokens)
	_strings(e, content)
	return e


## Flow-field reachability (ARCH 5.4): `field` is a built FlowField. Skipped when it has no cells (the stub until
## W1-A merges), otherwise every spawn-region cell must reach the core.
static func reachability_errors(arena: ArenaDef, field: Object) -> PackedStringArray:
	var e: PackedStringArray = PackedStringArray()
	if field == null:
		return e
	var cost_v: Variant = field.get("cost")
	if typeof(cost_v) != TYPE_PACKED_FLOAT32_ARRAY:
		return e
	var cost: PackedFloat32Array = cost_v
	if cost.is_empty():
		return e
	var bad_v: Variant = field.call("unreachable_spawn_cells", arena)
	var bad: int = bad_v
	if bad > 0:
		_bad(e, ARENA, "$.spawn_regions", "%d spawn-region cells cannot reach the core in the flow field" % bad)
	return e


static func _bad(e: PackedStringArray, file: String, path: String, problem: String) -> void:
	e.append("%s: %s: %s" % [file, path, problem])


static func _fmt(v: float, unit: String) -> String:
	var text: String = "%s" % v
	if is_finite(v) and v == floorf(v) and absf(v) < 1.0e15:
		text = "%d" % int(v)
	return text if unit.is_empty() else text + " " + unit


## v must be finite and > lo.
static func _gt(e: PackedStringArray, file: String, path: String, v: float, lo: float = 0.0, unit: String = "") -> void:
	if not is_finite(v):
		_bad(e, file, path, "not a finite number (got %s)" % _fmt(v, ""))
	elif not v > lo:
		_bad(e, file, path, "must be > %s (got %s)" % [_fmt(lo, ""), _fmt(v, unit)])


## v must be finite and >= lo.
static func _ge(e: PackedStringArray, file: String, path: String, v: float, lo: float = 0.0, unit: String = "") -> void:
	if not is_finite(v):
		_bad(e, file, path, "not a finite number (got %s)" % _fmt(v, ""))
	elif not v >= lo:
		_bad(e, file, path, "must be >= %s (got %s)" % [_fmt(lo, ""), _fmt(v, unit)])


static func _fin(e: PackedStringArray, file: String, path: String, v: float) -> void:
	if not is_finite(v):
		_bad(e, file, path, "not a finite number (got %s)" % _fmt(v, ""))


static func _mission(e: PackedStringArray, m: MissionDef) -> void:
	_gt(e, BAL, "$.core_max_hp", m.core_max_hp)
	if m.ticks_per_second != ContentLoader.TICK_RATE:
		_bad(e, BAL, "$.sim_ticks_per_second", "expected %d, got %d" % [ContentLoader.TICK_RATE, m.ticks_per_second])
	_ge(e, BAL, "$.simultaneous_enemy_cap", float(m.enemy_cap), 1.0)
	_ge(e, BAL, "$.intermission_seconds", float(m.intermission_ticks), 0.0, "ticks")
	_ge(e, EXT, "$.mission.prepare_seconds", float(m.prepare_ticks), 0.0, "ticks")
	_ge(e, BAL, "$.target_duration_seconds[0]", m.target_duration_min_s)
	_ge(e, BAL, "$.target_duration_seconds[1]", m.target_duration_max_s, m.target_duration_min_s)
	_ge(e, BAL, "$.reward.victory_base_data", float(m.reward_victory_base))
	_ge(e, BAL, "$.reward.victory_bonus_core_hp_divisor", float(m.reward_core_hp_divisor), 1.0)
	_ge(e, BAL, "$.reward.defeat_data_per_completed_wave", float(m.reward_defeat_per_wave))
	_ge(e, BAL, "$.targeting.lock_seconds", float(m.lock_ticks), 0.0, "ticks")
	_ge(e, EXT, "$.mission.eta_bucket_seconds", float(m.eta_bucket_ticks), 1.0, "ticks")
	_ge(e, EXT, "$.mission.max_spawns_per_tick", float(m.max_spawns_per_tick), 1.0)
	_ge(e, EXT, "$.mission.stuck_seconds", float(m.stuck_ticks), 1.0, "ticks")
	_ge(e, EXT, "$.mission.stuck_min_progress_m", m.stuck_min_progress_m)


static func _enemies(e: PackedStringArray, c: ContentSet) -> void:
	if c.enemies.size() != Ids.ENEMIES.size():
		_bad(e, BAL, "$.enemies", "expected %d enemies, got %d" % [Ids.ENEMIES.size(), c.enemies.size()])
		return
	for i: int in c.enemies.size():
		var d: EnemyDef = c.enemies[i]
		var p: String = "$.enemies." + String(Ids.ENEMIES[i])
		if d.id != Ids.ENEMIES[i] or d.index != i:
			_bad(e, BAL, p, "enemy %d must be '%s' at index %d" % [i, String(Ids.ENEMIES[i]), i])
		_gt(e, BAL, p + ".hp", d.hp)
		_gt(e, BAL, p + ".speed_mps", d.speed_mps)
		_ge(e, BAL, p + ".armor", d.armor)
		_ge(e, BAL, p + ".core_damage", d.core_damage)
		_ge(e, BAL, p + ".attack_period_s", float(d.attack_period_ticks), 1.0, "ticks")
		_ge(e, BAL, p + ".scrap", float(d.scrap))
		_gt(e, EXT, p + ".radius", d.radius)
		_gt(e, EXT, p + ".mass", d.mass)
		_ge(e, EXT, p + ".separation_weight", d.separation_weight)
		_ge(e, EXT, p + ".weave_amp_m", d.weave_amp_m)
		_ge(e, EXT, p + ".weave_period_s", float(d.weave_period_ticks), 1.0, "ticks")
		_ge(e, EXT, p + ".slot_span", float(d.slot_span), 1.0)
		_gt(e, EXT, p + ".visual_height_m", d.visual_height_m)


static func _weapons(e: PackedStringArray, c: ContentSet) -> void:
	if c.weapons.size() != Ids.WEAPONS.size():
		_bad(e, BAL, "$.weapons", "expected %d weapons, got %d" % [Ids.WEAPONS.size(), c.weapons.size()])
		return
	for i: int in c.weapons.size():
		var d: WeaponDef = c.weapons[i]
		var p: String = "$.weapons." + String(Ids.WEAPONS[i])
		_gt(e, BAL, p + ".damage", d.damage)
		_ge(e, BAL, p + ".shots_per_second", float(d.sps_milli), 1.0, "milli-shots")
		_ge(e, BAL, p + ".magazine", float(d.magazine), 1.0)
		_ge(e, BAL, p + ".reload_seconds", float(d.reload_ticks), 0.0, "ticks")
		_gt(e, BAL, p + ".range_m", d.range_m)


static func _upgrades(e: PackedStringArray, c: ContentSet) -> void:
	if c.upgrades.size() != Ids.UPGRADES.size():
		_bad(e, BAL, "$.upgrades", "expected %d upgrades, got %d" % [Ids.UPGRADES.size(), c.upgrades.size()])
		return
	for i: int in c.upgrades.size():
		var d: UpgradeDef = c.upgrades[i]
		var key: String = String(Ids.UPGRADES[i])
		var p: String = "$.upgrades." + key
		var cost_path: String = "$.weapons.smg.unlock_scrap" if i == Ids.UP_SMG else p + ".base_cost"
		_gt(e, BAL, cost_path, float(d.base_cost))  # costs > 0
		_ge(e, BAL, p + ".growth", d.growth, 1.0)
		_ge(e, BAL, p + ".max_level", float(d.max_level), 1.0)
		_ge(e, EXT, "$.upgrades.%s.cap" % key, d.cap)
		if d.cap > 1.0:
			_bad(e, EXT, "$.upgrades.%s.cap" % key, "must be <= 1 (got %s)" % _fmt(d.cap, ""))
		_ge(e, EXT, "$.upgrades.%s.min_wave" % key, float(d.min_wave), 1.0)
		if d.min_wave > WAVE_COUNT:
			_bad(e, EXT, "$.upgrades.%s.min_wave" % key, "must be <= %d (got %d)" % [WAVE_COUNT, d.min_wave])
		match d.kind:
			UpgradeDef.Kind.STAT:
				_gt(e, BAL, p + ".per_level", d.per_level)
			UpgradeDef.Kind.TURRET:
				_gt(e, BAL, p + ".turret_damage", d.turret_damage)
				_ge(e, BAL, p + ".turret_sps", float(d.turret_sps_milli), 1.0, "milli-shots")
				_gt(e, BAL, p + ".turret_range_m", d.turret_range_m)
				_ge(e, EXT, "$.upgrades.%s.lock_seconds" % key, float(d.turret_lock_ticks), 0.0, "ticks")
			UpgradeDef.Kind.WEAPON_UNLOCK:
				if d.weapon_index < 0 or d.weapon_index >= c.weapons.size():
					_bad(e, EXT, "$.upgrades.%s.weapon" % key, "unknown weapon (index %d)" % d.weapon_index)
			_:
				_bad(e, EXT, "$.upgrades.%s.kind" % key, "unknown kind %d" % d.kind)


static func _abilities(e: PackedStringArray, c: ContentSet) -> void:
	if c.abilities.size() != Ids.ABILITIES.size():
		_bad(e, BAL, "$.abilities", "expected %d abilities, got %d" % [Ids.ABILITIES.size(), c.abilities.size()])
		return
	for i: int in c.abilities.size():
		var d: AbilityDef = c.abilities[i]
		var key: String = String(Ids.ABILITIES[i])
		var p: String = "$.abilities." + key
		_ge(e, BAL, p + ".cooldown_s", float(d.cooldown_ticks), 1.0, "ticks")  # cooldowns > 0
		if d.cooldown_start != AbilityDef.CooldownStart.ON_ACTIVATE and d.cooldown_start != AbilityDef.CooldownStart.ON_END:
			_bad(e, EXT, p + ".cooldown_starts", "expected on_activate or on_end")
		match i:
			Ids.AB_EMP:
				_ge(e, BAL, p + ".normal_stun_s", float(d.stun_ticks), 1.0, "ticks")
				_ge(e, BAL, p + ".boss_stun_s", float(d.boss_stun_ticks), 0.0, "ticks")
				_ge(e, EXT, p + ".boss_immunity_s", float(d.boss_immunity_ticks), 0.0, "ticks")
			Ids.AB_SHIELD:
				_gt(e, BAL, p + ".absorb_damage", d.absorb)
				_ge(e, BAL, p + ".duration_s", float(d.duration_ticks), 1.0, "ticks")
			Ids.AB_OVERDRIVE:
				_ge(e, BAL, p + ".fire_rate_multiplier", float(d.fire_rate_mult_milli), 1.0, "milli")
				_ge(e, BAL, p + ".duration_s", float(d.duration_ticks), 1.0, "ticks")


static func _waves(e: PackedStringArray, c: ContentSet) -> void:
	var seen: Dictionary[int, int] = {}  # wave index -> array position of its first use
	var clean: bool = true  # every index unique and in 1..WAVE_COUNT
	for i: int in c.waves.size():
		var w: WaveDef = c.waves[i]
		var p: String = "$.waves[%d]" % i
		if seen.has(w.index):
			var first: int = seen[w.index]
			_bad(e, WAVES, p + ".index", "duplicate wave index %d (first used by $.waves[%d])" % [w.index, first])
			clean = false
		elif w.index < 1 or w.index > WAVE_COUNT:
			_bad(e, WAVES, p + ".index", "must be 1..%d (got %d)" % [WAVE_COUNT, w.index])
			clean = false
		else:
			seen[w.index] = i
		_ge(e, WAVES, p + ".peak_target", float(w.peak_target), 1.0)
		if w.groups.is_empty():
			_bad(e, WAVES, p + ".groups", "must have at least one group")
		for j: int in w.groups.size():
			var g: SpawnGroupDef = w.groups[j]
			var pg: String = "%s.groups[%d]" % [p, j]
			if g.enemy_index < 0 or g.enemy_index >= c.enemies.size():
				_bad(e, WAVES, pg + ".enemy", "unknown enemy id (index %d)" % g.enemy_index)
			_ge(e, WAVES, pg + ".count", float(g.count), 1.0)
			_ge(e, WAVES, pg + ".start_s", float(g.start_tick), 0.0, "ticks")
			_ge(e, WAVES, pg + ".interval_s", float(g.interval_ticks), 1.0, "ticks")
			if c.arena.region(g.region_id) == null:
				_bad(e, WAVES, pg + ".region", "unknown spawn region '%s'" % String(g.region_id))
	if c.waves.size() != WAVE_COUNT:
		var missing: PackedStringArray = PackedStringArray()
		for k: int in range(1, WAVE_COUNT + 1):
			if not seen.has(k):
				missing.append(str(k))
		var msg: String = "expected %d waves, got %d (missing wave index: %s)"
		_bad(e, WAVES, "$.waves", msg % [WAVE_COUNT, c.waves.size(), ", ".join(missing)])
	elif clean:
		for i: int in c.waves.size():
			if c.waves[i].index != i + 1:
				_bad(e, WAVES, "$.waves", "waves must be listed in order 1..%d" % WAVE_COUNT)
				break


static func _inside(a: ArenaDef, x: float, z: float) -> bool:
	return x >= a.min_x and x <= a.max_x and z >= a.min_z and z <= a.max_z


static func _arena(e: PackedStringArray, c: ContentSet) -> void:
	var a: ArenaDef = c.arena
	if not a.min_x < a.max_x or not a.min_z < a.max_z:
		_bad(e, ARENA, "$.bounds", "min must be below max on both axes")
	_gt(e, ARENA, "$.grid.cell_m", a.cell_m)
	_ge(e, ARENA, "$.grid.margin_cells", float(a.margin_cells))
	_gt(e, ARENA, "$.core.radius", a.core_radius)
	_gt(e, ARENA, "$.approach_radius", a.approach_radius, a.core_radius)
	if not _inside(a, a.core_x, a.core_z):
		_bad(e, ARENA, "$.core", "core (%s, %s) is outside the bounds" % [_fmt(a.core_x, ""), _fmt(a.core_z, "")])
	if not _inside(a, a.warden_x, a.warden_z):
		_bad(e, ARENA, "$.warden", "Warden (%s, %s) is outside the bounds" % [_fmt(a.warden_x, ""), _fmt(a.warden_z, "")])
	for i: int in a.turret_pads.size():
		if not _inside(a, a.turret_pads[i].x, a.turret_pads[i].y):
			_bad(e, ARENA, "$.turret_pads[%d]" % i, "turret pad (%s, %s) is outside the bounds" % [_fmt(a.turret_pads[i].x, ""), _fmt(a.turret_pads[i].y, "")])
	var turret: UpgradeDef = c.upgrade(&"auto_turret")
	if turret != null and a.turret_pads.size() < turret.max_level:
		_bad(e, ARENA, "$.turret_pads", "%d pads for a turret max level of %d" % [a.turret_pads.size(), turret.max_level])
	if a.spawn_regions.is_empty():
		_bad(e, ARENA, "$.spawn_regions", "at least one spawn region is required")
	for r: SpawnRegionDef in a.spawn_regions:
		for v: float in [r.x0, r.z0, r.x1, r.z1]:
			_fin(e, ARENA, "$.spawn_regions." + String(r.id), v)
	var need: int = c.mission.enemy_cap + 2
	if a.slot_positions.size() < need or a.slot_ring.size() != a.slot_positions.size():
		var msg: String = "%d attack slots (%d ring entries) for an enemy cap of %d: need at least cap + 2 = %d"
		_bad(e, ARENA, "$.slots", msg % [a.slot_positions.size(), a.slot_ring.size(), c.mission.enemy_cap, need])
	var clear: float = a.approach_radius + 1.0
	var core: Vector2 = Vector2(a.core_x, a.core_z)
	for i: int in a.obstacles.size():
		var o: ObstacleDef = a.obstacles[i]
		var p: String = "$.obstacles[%d]" % i
		_fin(e, ARENA, p + ".x", o.x)
		_fin(e, ARENA, p + ".z", o.z)
		if o.shape == ObstacleDef.Shape.CIRCLE:
			_gt(e, ARENA, p + ".radius", o.radius)
		else:
			_gt(e, ARENA, p + ".size_x", o.size_x)
			_gt(e, ARENA, p + ".size_z", o.size_z)
		var dist: float = Vector2(o.x, o.z).distance_to(core)
		if dist < clear:
			var msg: String = "obstacle '%s' is %.2f m from the core; keep it at least approach_radius + 1 = %s m away"
			_bad(e, ARENA, p, msg % [String(o.id), dist, _fmt(clear, "")])
	e.append_array(reachability_errors(a, build_flow_field(a)))


## FlowField.build(arena) through its script path; null when the script is missing or does not return an object.
static func build_flow_field(a: ArenaDef) -> Object:
	var script: Resource = load(FLOW_FIELD_SCRIPT)
	if script == null:
		return null
	var built: Variant = script.call("build", a)
	if typeof(built) != TYPE_OBJECT:
		return null
	var field: Object = built
	return field


static func _tokens(e: PackedStringArray, t: VisualTokens) -> void:
	for token: StringName in PALETTE:
		if not t.palette.has(token):
			_bad(e, TOKENS, "$.palette." + String(token), "palette token missing")
	_ge(e, TOKENS, "$.ui.top_hud_fraction", t.top_hud_fraction)
	_ge(e, TOKENS, "$.ui.bottom_controls_fraction", t.bottom_controls_fraction)
	if t.top_hud_fraction + t.bottom_controls_fraction >= 1.0:
		_bad(e, TOKENS, "$.ui", "top_hud_fraction + bottom_controls_fraction must be < 1")
	_ge(e, TOKENS, "$.ui.touch_target_min_dp", float(t.touch_target_min_dp), 1.0)
	_ge(e, TOKENS, "$.ui.text_contrast_target", t.text_contrast_target, 1.0)
	_ge(e, TOKENS, "$.camera.down_angle_deg_min", t.down_angle_min_deg)
	_ge(e, TOKENS, "$.camera.down_angle_deg_max", t.down_angle_max_deg, t.down_angle_min_deg)


## Every name the UI shows must resolve through Strings.t.
static func _strings(e: PackedStringArray, c: ContentSet) -> void:
	var needs: Dictionary[String, String] = {c.mission.name_key: "$.mission_name"}
	for d: EnemyDef in c.enemies:
		needs[d.name_key] = "$.enemies." + String(d.id)
	for d: WeaponDef in c.weapons:
		needs[d.name_key] = "$.weapons." + String(d.id)
	for d: UpgradeDef in c.upgrades:
		needs[d.name_key] = "$.upgrades." + String(d.id)
	for d: AbilityDef in c.abilities:
		needs[d.name_key] = "$.abilities." + String(d.id)
	for key: String in Reason.KEYS:
		needs[key] = "Reason"
	for key: String in needs:
		if not c.strings.has(key):
			_bad(e, STRINGS, "$." + key, "missing string (needed by %s)" % needs[key])
