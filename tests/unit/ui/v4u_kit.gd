class_name V4uKit
extends RefCounted
## Helpers shared by the V4-U UI tests (the Archive, the kit selector, the results additions, the ticker and edge arrows, the
## first-run hints, the menu and pause additions). Not a suite. Everything runs on TestContent.variety() with the Archive of
## CONTENT 12 filled in (the slice fixture holds only five armory rows) and a fresh in-memory profile.

const ARCHIVE: String = "res://src/ui/screens/archive_screen.tscn"
const SIZES: Array[Vector2] = [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0), Vector2(1080.0, 1280.0)]
const NARROW: Vector2 = Vector2(1080.0, 2640.0)  ## a 9:21.6 phone
## [id, branch, tier, cost, grants] of CONTENT 12 (the five armory rows of the slice are already in the fixture).
const UNLOCKS: Array = [
	["u_w_hornet", 0, 1, 80, ["hornet_rack"]], ["u_w_lmg", 0, 1, 120, ["lmg"]], ["u_w_mortar", 0, 2, 160, ["slag_mortar"]],
	["u_w_torch", 0, 2, 220, ["cutting_torch"]], ["u_w_rail", 0, 3, 300, ["rail_lance"]], ["u_w_arc", 0, 3, 400, ["arc_projector"]],
	["u_p_blast", 1, 1, 100, ["overpressure", "aftershock"]], ["u_p_arc", 1, 1, 100, ["shock_rounds", "emp_tether"]],
	["u_p_fortress", 1, 2, 150, ["reactive_plating"]], ["u_p_gunline", 1, 2, 150, ["overwatch"]],
	["u_p_ledger", 1, 2, 200, ["compound_interest"]], ["u_p_corrupted", 1, 3, 250, ["borrowed_time"]], ["u_p_proto", 1, 3, 300, ["twin_link"]],
	["k_breacher", 2, 1, 150, ["k_breacher"]], ["k_signal", 2, 1, 150, ["k_signal"]], ["k_gunline", 2, 2, 250, ["k_gunline"]],
	["k_ledger", 2, 2, 250, ["k_ledger"]], ["k_gambler", 2, 3, 350, ["k_gambler"]],
	["u_f_reroll", 3, 1, 120, ["free_reroll"]], ["u_f_boss_intel", 3, 1, 150, ["boss_intel"]], ["u_f_preview", 3, 2, 200, ["route_preview"]],
	["u_f_turret_arc", 3, 2, 300, ["turret_arc"]], ["u_f_turret_mortar", 3, 3, 300, ["turret_mortar"]], ["u_f_third_sling", 3, 3, 500, ["third_slot"]],
]
const KITS: Array = [["k_breacher", 150], ["k_signal", 150], ["k_gunline", 250], ["k_ledger", 250], ["k_gambler", 350]]


## The variety fixture with every unlock and kit of the full Archive.
static func content() -> ContentSet:
	var cs: ContentSet = TestContent.variety()
	for row: Array in UNLOCKS:
		var key: String = row[0]
		var id: StringName = StringName(key)
		if cs.unlock(id) != null:
			continue
		var def: UnlockDef = UnlockDef.new()
		def.id = id
		def.index = cs.unlocks.size()
		def.name_key = "archive.%s.name" % key
		var branch: int = row[1]
		var tier: int = row[2]
		var cost: int = row[3]
		def.branch = branch
		def.tier = tier
		def.cost = cost
		var grants: Array = row[4]
		for g: Variant in grants:
			var granted: String = g
			def.grants.append(StringName(granted))
		cs.unlocks.append(def)
	for row: Array in KITS:
		var key: String = row[0]
		var id: StringName = StringName(key)
		if cs.kit(id) != null:
			continue
		var kit: KitDef = KitDef.new()
		kit.id = id
		kit.index = cs.kits.size()
		kit.name_key = "kit.%s.name" % key.trim_prefix("k_")
		var price: int = row[1]
		kit.cost = price
		cs.kits.append(kit)
	return cs


## A Profile with `data` Recovered Data and the unlock ids `owned`.
static func profile(data: int, owned: Array[String] = []) -> Profile:
	var p: Profile = Profile.defaults()
	p.data = data
	for id: String in owned:
		p.unlocks.append(id)
	return p


## The nth unlock of a branch (ArchiveModel order).
static func unlock_ids(cs: ContentSet, branch: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var model: ArchiveModel = ArchiveModel.new(cs, ArchiveBank.new(Profile.defaults(), cs))
	for def: UnlockDef in model.rows(branch):
		out.append(def.id)
	return out


static func host(suite: GdUnitTestSuite, view_size: Vector2) -> Control:
	var node: Control = Control.new()
	suite.auto_free(node)
	node.size = view_size
	suite.add_child(node)
	return node


## An Archive screen on `bank` under a `view_size` host, set up on `cs`.
static func archive(suite: GdUnitTestSuite, cs: ContentSet, bank: ArchiveBank, view_size: Vector2 = SIZES[1]) -> ArchiveScreen:
	var packed: PackedScene = load(ARCHIVE) as PackedScene
	var screen: ArchiveScreen = packed.instantiate() as ArchiveScreen
	host(suite, view_size).add_child(screen)
	screen.setup(cs, bank)
	return screen


static func settle(tree: SceneTree, frames: int = 3) -> void:
	for i: int in frames:
		await tree.process_frame


## A RunSummary of a generated run on `cs`: kills, core damage by type, harmful events, directives and weapons.
static func summary(cs: ContentSet, result: int = RunResult.Id.DEFEAT) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = "v4u"
	s.run_seed = 48211
	s.result = result
	s.waves_completed = 3
	s.act_reached = 1
	s.core_hp = 0
	s.core_max_hp = 1000
	s.duration_ticks = 34920
	s.kills_by_type.resize(cs.enemies.size())
	s.kills_by_type[Ids.EN_SKITTER] = 120
	s.kills_by_type[Ids.EN_MOTE] = 140
	s.core_damage_by_type.resize(cs.enemies.size())
	s.core_damage_by_type[Ids.EN_HOLLOW] = 260.0
	s.core_damage_by_type[Ids.EN_SKITTER] = 412.0
	s.core_damage_by_type[Ids.EN_BURSTER] = 90.0
	s.core_damage_by_type[Ids.EN_MOTE] = 12.0
	s.events_seen.resize(cs.events.size())
	s.directives.resize(cs.directives.size())
	s.directives[cs.directive_index(&"hot_loads")] = 3
	s.directives[cs.directive_index(&"cyclic_tuning")] = 2
	s.weapons = PackedInt32Array([Ids.WEAPONS.find(&"arc_projector"), Ids.WEAPONS.find(&"pistol"), -1])
	s.data_reward = 72
	return s
