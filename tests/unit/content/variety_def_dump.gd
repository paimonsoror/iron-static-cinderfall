class_name VarietyDefDump
extends RefCounted
## Test helper (V1-S). A canonical text of the LEGACY fields of a ContentSet (the field lists as they were before the
## variety scaffold) and its sha256. The golden value in test_variety_legacy_content.gd was recorded on main 9705a77,
## so it proves that the legacy fixture still produces exactly the content it produced before the scaffold.

const MISSION: PackedStringArray = [
	"id", "name_key", "core_max_hp", "ticks_per_second", "enemy_cap", "intermission_ticks", "prepare_ticks",
	"target_duration_min_s", "target_duration_max_s", "reward_victory_base", "reward_core_hp_divisor",
	"reward_defeat_per_wave", "lock_ticks", "eta_bucket_ticks", "max_spawns_per_tick", "stuck_ticks", "stuck_min_progress_m",
]
const ENEMY: PackedStringArray = [
	"id", "index", "name_key", "hp", "speed_mps", "armor", "core_damage", "attack_period_ticks", "scrap", "radius", "mass",
	"separation_weight", "weave_amp_m", "weave_period_ticks", "direct_seek", "is_boss", "priority_class", "slot_span",
	"visual_id", "visual_height_m",
]
const WEAPON: PackedStringArray = ["id", "index", "name_key", "damage", "sps_milli", "magazine", "reload_ticks", "range_m"]
const UPGRADE: PackedStringArray = [
	"id", "index", "name_key", "kind", "base_cost", "growth", "max_level", "per_level", "cap", "min_wave", "weapon_index",
	"turret_damage", "turret_sps_milli", "turret_range_m", "turret_lock_ticks",
]
const ABILITY: PackedStringArray = [
	"id", "index", "name_key", "cooldown_ticks", "duration_ticks", "cooldown_start", "stun_ticks", "boss_stun_ticks",
	"boss_immunity_ticks", "absorb", "fire_rate_mult_milli",
]
const GROUP: PackedStringArray = ["enemy_index", "count", "start_tick", "interval_ticks", "region_id"]
const ARENA: PackedStringArray = [
	"id", "min_x", "max_x", "min_z", "max_z", "cell_m", "margin_cells", "core_x", "core_z", "core_radius", "warden_x",
	"warden_z", "turret_pads", "approach_radius", "slot_positions", "slot_ring", "pitch_down_deg", "yaw_deg",
	"frame_margin_m", "decor_yaw_deg",
]
const REGION: PackedStringArray = ["id", "x0", "z0", "x1", "z1"]
const OBSTACLE: PackedStringArray = ["id", "shape", "x", "z", "radius", "size_x", "size_z", "rot_deg", "visual"]
## sha256 of every file of tests/fixtures/data_baseline at main 9705a77 (the fixture must stay byte-identical).
const BASELINE_FILE_HASHES: Dictionary[String, String] = {
	"arena.json": "d36f237e7a6e9abf815a728ad366ea36efc31dd58e9e2ef889baf5ba3c87c599",
	"content_ext.json": "2a5a5bcb6f3918bc1aa055e3b1a33315318faf59af780dba7f3d1235c6ebf029",
	"vertical_slice_balance.json": "f04927c5b68d7ab586c32824eee12860f8bde8608b0d9517aecbb6f75e69eee4",
	"visual_tokens.json": "268416a7d8d5fc63f7ff8adf7c57e359fb8322c1aef580434ceee8d3ad966ed7",
	"waves.json": "e5e9b7f9f948daacf57f99b8e6957c748150a443de2a0e879f5188828d94fb2e",
	"strings/combat_en.json": "f66e1b75a57279bbc5c18bdd94255395e8802ded253152c7597d3fe41c1dccea",
	"strings/content_en.json": "3610191d67ae6f875d8bf525624d439f7451f967d1852a1131b977378bdd1509",
	"strings/lore_en.json": "b451cd8918943eee1867adae610914f47c1ab99ea4af2cd1d2d18347c384e622",
	"strings/screens_en.json": "81e3b66082312874c6fa2eb7f61264e2d39180cea33200d8336438a6af6a1a50",
}
const TOKENS: PackedStringArray = [
	"palette", "top_hud_fraction", "bottom_controls_fraction", "touch_target_min_dp", "text_contrast_target",
	"down_angle_min_deg", "down_angle_max_deg",
]


static func legacy_hash(c: ContentSet) -> String:
	return legacy_text(c).sha256_text()


static func legacy_text(c: ContentSet) -> String:
	var out: PackedStringArray = PackedStringArray()
	_obj(out, "mission", c.mission, MISSION)
	for d: EnemyDef in c.enemies:
		_obj(out, "enemy", d, ENEMY)
	for d: WeaponDef in c.weapons:
		_obj(out, "weapon", d, WEAPON)
	for d: UpgradeDef in c.upgrades:
		_obj(out, "upgrade", d, UPGRADE)
	for d: AbilityDef in c.abilities:
		_obj(out, "ability", d, ABILITY)
	for w: WaveDef in c.waves:
		out.append("wave %d %d" % [w.index, w.peak_target])
		for g: SpawnGroupDef in w.groups:
			_obj(out, "group", g, GROUP)
	_obj(out, "arena", c.arena, ARENA)
	for r: SpawnRegionDef in c.arena.spawn_regions:
		_obj(out, "region", r, REGION)
	for o: ObstacleDef in c.arena.obstacles:
		_obj(out, "obstacle", o, OBSTACLE)
	_obj(out, "tokens", c.tokens, TOKENS)
	var keys: Array = c.strings.keys()
	keys.sort()
	for k: String in keys:
		out.append("string %s=%s" % [k, c.strings[k]])
	return "\n".join(out)


static func _obj(out: PackedStringArray, label: String, o: Object, fields: PackedStringArray) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for f: String in fields:
		parts.append("%s=%s" % [f, var_to_str(o.get(f))])
	out.append("%s {%s}" % [label, ", ".join(parts)])
