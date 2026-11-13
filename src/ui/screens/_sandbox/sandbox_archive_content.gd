class_name SandboxArchiveContent
extends RefCounted
## Capture sandboxes only: the whole Archive of CONTENT 12 and the six kits on top of the loaded content, so the Archive and the
## kit selector can be photographed before the data files hold them (the slice has five armory rows and one kit). A row or kit
## the content already has is left alone, so this does nothing once the full tree is in `data/unlocks.json`.

## [id, branch, tier, cost, grants]
const ROWS: Array = [
	["u_w_hornet", 0, 1, 80, ["hornet_rack"]], ["u_w_lmg", 0, 1, 120, ["lmg"]], ["u_w_mortar", 0, 2, 160, ["slag_mortar"]],
	["u_w_torch", 0, 2, 220, ["cutting_torch"]], ["u_w_rail", 0, 3, 300, ["rail_lance"]], ["u_w_arc", 0, 3, 400, ["arc_projector"]],
	["u_p_blast", 1, 1, 100, ["overpressure"]], ["u_p_arc", 1, 1, 100, ["shock_rounds"]], ["u_p_fortress", 1, 2, 150, ["reactive_plating"]],
	["u_p_gunline", 1, 2, 150, ["overwatch"]], ["u_p_ledger", 1, 2, 200, ["compound_interest"]], ["u_p_corrupted", 1, 3, 250, ["borrowed_time"]],
	["u_p_proto", 1, 3, 300, ["twin_link"]],
	["k_breacher", 2, 1, 150, ["k_breacher"]], ["k_signal", 2, 1, 150, ["k_signal"]], ["k_gunline", 2, 2, 250, ["k_gunline"]],
	["k_ledger", 2, 2, 250, ["k_ledger"]], ["k_gambler", 2, 3, 350, ["k_gambler"]],
	["u_f_reroll", 3, 1, 120, ["free_reroll"]], ["u_f_boss_intel", 3, 1, 150, ["boss_intel"]], ["u_f_preview", 3, 2, 200, ["route_preview"]],
	["u_f_turret_arc", 3, 2, 300, ["turret_arc"]], ["u_f_turret_mortar", 3, 3, 300, ["turret_mortar"]], ["u_f_third_sling", 3, 3, 500, ["third_slot"]],
]
const KITS: Array = [["k_breacher", 150], ["k_signal", 150], ["k_gunline", 250], ["k_ledger", 250], ["k_gambler", 350]]


static func extend(content: ContentSet) -> void:
	for row: Array in ROWS:
		var key: String = row[0]
		var id: StringName = StringName(key)
		if content.unlock(id) != null:
			continue
		var def: UnlockDef = UnlockDef.new()
		def.id = id
		def.index = content.unlocks.size()
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
		content.unlocks.append(def)
	for row: Array in KITS:
		var key: String = row[0]
		var id: StringName = StringName(key)
		if content.kit(id) != null:
			continue
		var kit: KitDef = KitDef.new()
		kit.id = id
		kit.index = content.kits.size()
		kit.name_key = "kit.%s.name" % key.trim_prefix("k_")
		var price: int = row[1]
		kit.cost = price
		content.kits.append(kit)
	if content.run != null and content.run.tier_gates.is_empty():
		content.run.tier_gates = PackedInt32Array([3, 8])
