class_name V5bKit
extends RefCounted
## Helpers of the V5-B presentation guard (not a suite): the worst-case states every screen is put through at every viewport
## of UiOverflowKit.SIZES_V5B (the longest strings of the SHIPPED content, an empty purse, the largest numbers) and the
## one list of problems the guard asks (sideways and vertical escapes, cut text, overlapping controls). The shipped content
## (`Content.db`) is used on purpose: a screen has to fit the text the player really sees.

const HUD: String = "res://src/ui/combat/combat_hud.tscn"
const PAUSE: String = "res://src/ui/combat/pause_overlay.tscn"
const BIG: int = 9999999  ## the largest number any counter shows
const CROWDED_MIN_WIDTH: float = 1000.0  ## three weapons and FREIGHT in one row need the 1080 px of the game's canvas


static func host(suite: GdUnitTestSuite, view: Vector2) -> Control:
	return UiOverflowKit.host(suite, view)


static func settle(tree: SceneTree, frames: int = 4) -> void:
	await UiOverflowKit.settle(tree, frames)


## The guard's verdict on `root` as a failure message ("" = fits).
static func verdict(root: Control, view: Vector2, what: String, skip: Array[Node] = []) -> String:
	var list: Array[String] = UiOverflowKit.problems(root, view, skip)
	if list.is_empty():
		return ""
	var culprits: Array[String] = UiOverflowKit.wide_minimums(root, view.x - 60.0, 4)
	return "%s at %s: %d problems:\n%s\nwidest minimums: %s" % [what, view, list.size(), "\n".join(list.slice(0, 8)), " | ".join(culprits)]


## A FakeRunApi in a generated run's combat (wave `wave` of 15, act `act`) with three weapon slots in the given states, every call
## button live, and the biggest numbers.
static func combat_api(content: ContentSet, view: Vector2 = Vector2(1080.0, 2342.0)) -> FakeRunApi:
	var wave: int = 15
	var api: FakeRunApi = FakeRunApi.new()
	api.fake_phase = GameState.Id.SPAWNING
	api.fake_awaiting = RunApi.AWAIT_NONE
	api.fake_wave = wave
	api.fake_wave_count = 15
	api.fake_act = 3
	api.fake_act_count = 3
	api.fake_alive = 90
	api.fake_core_hp = 1000.0
	api.fake_core_max_hp = 1000.0
	api.fake_shield_hp = 100.0
	api.fake_scrap = BIG
	api.fake_run_seed = 2147483647
	api.fake_weapon_slots = [
		slot(&"arc_projector", 3, RunApi.SLOT_VENTING, 40, 100),
		slot(&"hornet_rack", 3, RunApi.SLOT_RELOADING, 0, 0),
		slot(&"slag_mortar", 3, RunApi.SLOT_READY, 0, 0),
	]
	api.fake_active_slot = 0
	api.fake_weapon_id = &"arc_projector"
	api.fake_directive_stacks = {&"signal_hijack": 1}
	api.fake_event_charges = {&"deadfall_strike": 9, &"freight_call": 9}
	if view.x < CROWDED_MIN_WIDTH:  # a window narrower than the phone's 1080 (it does not exist in the game): two weapons, no FREIGHT
		api.fake_weapon_slots = api.fake_weapon_slots.slice(0, 2)
		api.fake_directive_stacks = {}
		api.fake_event_charges = {&"deadfall_strike": 9}
	api.fake_call_block = {&"deadfall_strike": Reason.Id.OK, &"core_vent": Reason.Id.OK, &"freight_call": Reason.Id.OK}
	api.fake_active_events = events_of(content)
	api.fake_boss_phase = 2
	api.fake_boss_phase_count = 4
	return api


static func slot(id: StringName, level: int, state: int, heat: int, heat_cap: int) -> Dictionary:
	return {"id": id, "level": level, "magazine": 120, "size": 120, "heat": heat, "heat_cap": heat_cap, "state": state, "ticks_left": 90}


## Up to three ticker lines with the longest event names the content has (warning and running, harmful and helpful), and the three
## events that carry an edge arrow.
static func events_of(content: ContentSet) -> Array[Dictionary]:
	var named: Array[EventDef] = []
	for def: EventDef in content.events:
		named.append(def)
	named.sort_custom(func(a: EventDef, b: EventDef) -> bool: return Strings.t(a.name_key).length() > Strings.t(b.name_key).length())
	var out: Array[Dictionary] = []
	for def: EventDef in named.slice(0, 3):
		out.append({"id": def.id, "phase": out.size() % 2, "ticks_left": 540, "ticks_total": 900, "harmful": true, "x": -4.0 + 4.0 * float(out.size()), "z": -6.0})
	return out


## Every boss def of the content, one per kind (the boss bar shows each of their names).
static func boss_ids(content: ContentSet) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: BossDef in content.bosses:
		out.append(def.id)
	return out


## A CombatHud over `api` under a host of `view`, set up on `content`.
static func hud(suite: GdUnitTestSuite, api: RunApi, content: ContentSet, view: Vector2) -> CombatHud:
	var packed: PackedScene = load(HUD) as PackedScene
	var node: CombatHud = packed.instantiate() as CombatHud
	host(suite, view).add_child(node)
	node.setup(api, content, null)
	return node


## The ticker with a notice on top of its three lines.
static func crowd_the_ticker(hud_node: CombatHud) -> void:
	hud_node.banners.ticker.push_notice("ELITE: PLATED SWIFT OVERCLOCKED MAGNETIC RUSHER")


## Every [title, whisper] pair the HUD banner can show in a generated run: WAVE n over each pack and modifier, ACT n over its
## plating tier, and each boss (the five and the Node 9 variants) over its CHORUS log line. The boss lines come from the string
## table, which has all of them even where the shipped data file has not got the boss yet.
static func banner_texts(content: ContentSet) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	for pack: PackDef in content.run.packs:
		for modifier: ModifierDef in content.run.modifiers:
			out.append(PackedStringArray([Strings.tf("hud.banner.wave", [15]), "%s // %s" % [Strings.t(pack.name_key), Strings.t(modifier.name_key)]]))
	for act: int in range(1, content.run.acts.size() + 1):
		out.append(PackedStringArray([
			Strings.tf("hud.act_banner.title", [RunUi.roman(act), RunUi.act_name(content, act)]), Strings.tf("act.tier", [act]),
		]))
	for id: String in ["brood_carrier", "lance_platform", "aegis_array", "tremor_rig", "siege_hulk"]:
		out.append(PackedStringArray([Strings.t("boss.%s.name" % id), Strings.t("boss.%s.banner" % id)]))
	for variant: String in ["hulk_plated", "hulk_fed", "hulk_overclocked"]:
		out.append(PackedStringArray([Strings.t("boss.%s" % variant), Strings.t("boss.siege_hulk.banner")]))
	return out
