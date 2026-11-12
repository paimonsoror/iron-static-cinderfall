class_name DraftState
extends RefCounted
## Directive stacks and the draft in progress (VARIETY_SPEC 4.3, 4.4, 13.2). Written by DraftSystem only; hashed.
# TODO(V2-B): the stub holds the neutral state.

const FIELDS: PackedStringArray = [
	"stacks", "offer", "last_offer", "offer_ordinal", "open", "picks_left", "rerolls_paid", "free_rerolls", "buyouts",
	"bought_out", "patches", "offers_without_rare", "turret_offered", "next_rare", "next_double", "reroll_locked",
]

var stacks: PackedInt32Array = PackedInt32Array()  ## per directive index: how many the build holds
var offer: PackedInt32Array = PackedInt32Array()  ## directive index per slot; -1 = slot already taken
var last_offer: PackedInt32Array = PackedInt32Array()  ## the previous offer (repeat penalty)
var offer_ordinal: int = 0  ## n of the `draft:<n>` stream: offers made so far in this run
var open: bool = false
var picks_left: int = 0  ## 2 after rw_double_pick, else 1
var rerolls_paid: int = 0  ## this run (the price grows)
var free_rerolls: int = 0
var buyouts: int = 0  ## this run (the price grows)
var bought_out: bool = false  ## a buy-out was used in this draft
var patches: int = 0  ## this run (the price grows)
var offers_without_rare: int = 0  ## rare pity counter
var turret_offered: bool = false  ## turret pity: turret_deploy was offered at least once
var next_rare: bool = false  ## rw_rare_draft
var next_double: bool = false  ## rw_double_pick
var reroll_locked: bool = false  ## mod_no_breather


func _init(directive_count: int = 0) -> void:
	stacks.resize(directive_count)


func stacks_of(directive_index: int) -> int:
	if directive_index < 0 or directive_index >= stacks.size():
		return 0
	return stacks[directive_index]


func hash_into(h: StateHasher) -> void:
	SnapUtil.hash_fields(h, self, FIELDS)


func to_dict() -> Dictionary:
	return SnapUtil.to_dict(self, FIELDS)


func from_dict(d: Dictionary) -> void:
	SnapUtil.from_dict(self, FIELDS, d)
