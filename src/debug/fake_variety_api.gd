class_name FakeVarietyApi
extends RunApi
## The variety half of FakeRunApi (VARIETY_SPEC 13.4): public `fake_*` state for every RunApi query added by the
## variety milestone, and its commands. FakeRunApi extends this class, so `FakeRunApi.new()` has everything; the split
## only keeps both files under the line cap.
##
## Commands append {"cmd": <RunApi method name>, "command_id": int, "id": StringName, "arg": int} to `calls` (through
## `_record`, which FakeRunApi implements). While paused a command emits Events.command_rejected(id, Reason.Id.PAUSED)
## and nothing else. Otherwise it emits the signal a successful command causes; like purchases, the fake state is NOT
## changed (tests and sandboxes set it themselves), with one exception: `swap_weapon` moves `fake_active_slot`.
## Dictionary shapes are the ones documented on RunApi. FakeRunPresets fills this state for the HUD sandbox.

var fake_awaiting: int = RunApi.AWAIT_NONE
var fake_act: int = 1
var fake_act_count: int = 3
var fake_draft_offer: PackedInt32Array = PackedInt32Array()  ## directive indices
var fake_draft_ids: Array[StringName] = []  ## the ids of fake_draft_offer, slot by slot (for the emitted signals)
var fake_draft_reroll_cost: int = 60
var fake_draft_buyout_cost: int = 250
var fake_patch_cost: int = 180
var fake_free_rerolls: int = 0
var fake_route_options: Array[Dictionary] = []
var fake_boss_brief: Dictionary = {}
var fake_salvage_offer: Dictionary = {}
var fake_weapon_slots: Array[Dictionary] = []  ## empty = the base-class slot built from the legacy weapon queries
var fake_active_slot: int = 0
var fake_event_charges: Dictionary = {}  ## event id -> charges
var fake_call_block: Dictionary = {}  ## event id -> Reason.Id (missing = UNKNOWN_ID)
var fake_active_events: Array[Dictionary] = []
var fake_directive_stacks: Dictionary = {}  ## directive id -> stacks
var fake_build_tags: Dictionary = {}  ## tag -> stacks
var fake_boss_phase: int = 0
var fake_boss_phase_count: int = 1
var fake_run_seed: int = 48211
var fake_variety_paused: bool = false  ## FakeRunApi keeps it equal to fake_paused
var fake_buyout_used: bool = false
var fake_draft_locked: bool = false
var fake_crate_status: Dictionary = {}  ## the shape of RunApi.crate_status(); empty = no crate on the field


## Implemented by FakeRunApi: appends the entry to `calls`.
func _record(_entry: Dictionary) -> void:
	pass


# --- commands ---


func pick_directive(command_id: int, slot: int) -> void:
	var id: StringName = _draft_id(slot)
	_record({"cmd": "pick_directive", "command_id": command_id, "id": id, "arg": slot})
	if not _blocked(command_id):
		var stacks: int = fake_directive_stacks.get(id, 0)
		Events.directive_picked.emit(id, stacks + 1)


func skip_draft(command_id: int) -> void:
	_record({"cmd": "skip_draft", "command_id": command_id, "id": &"", "arg": 0})
	var _b: bool = _blocked(command_id)


func reroll_draft(command_id: int) -> void:
	_record({"cmd": "reroll_draft", "command_id": command_id, "id": &"", "arg": 0})
	if not _blocked(command_id):
		Events.draft_offered.emit(fake_draft_ids)


func buy_out(command_id: int, slot: int) -> void:
	var id: StringName = _draft_id(slot)
	_record({"cmd": "buy_out", "command_id": command_id, "id": id, "arg": slot})
	if not _blocked(command_id):
		var stacks: int = fake_directive_stacks.get(id, 0)
		Events.directive_picked.emit(id, stacks + 1)


func patch_core(command_id: int) -> void:
	_record({"cmd": "patch_core", "command_id": command_id, "id": &"", "arg": 0})
	var _b: bool = _blocked(command_id)


func pick_route(command_id: int, option: int) -> void:
	_record({"cmd": "pick_route", "command_id": command_id, "id": &"", "arg": option})
	if not _blocked(command_id):
		Events.route_picked.emit(option)


func resolve_salvage(command_id: int, choice: int, action: int) -> void:
	_record({"cmd": "resolve_salvage", "command_id": command_id, "id": &"", "arg": choice * 16 + action})
	var _b: bool = _blocked(command_id)


func swap_weapon(command_id: int, slot: int) -> void:
	var id: StringName = &""
	if slot >= 0 and slot < fake_weapon_slots.size():
		id = fake_weapon_slots[slot].get("id", &"")
	_record({"cmd": "swap_weapon", "command_id": command_id, "id": id, "arg": slot})
	if _blocked(command_id):
		return
	if slot < 0 or slot >= weapon_slot_count():
		Events.command_rejected.emit(command_id, Reason.Id.INVALID_CHOICE)
		return
	fake_active_slot = slot
	Events.weapon_swapped.emit(slot, id)


func call_event(command_id: int, event_id: StringName) -> void:
	_record({"cmd": "call_event", "command_id": command_id, "id": event_id, "arg": 0})
	if _blocked(command_id):
		return
	var reason: int = call_block_reason(event_id)
	if reason == Reason.Id.OK:
		Events.event_warned.emit(event_id, 120, 0.0, 0.0)
	else:
		Events.command_rejected.emit(command_id, reason)


func continue_run() -> void:
	_record({"cmd": "continue_run", "command_id": 0, "id": &"", "arg": 0})


# --- queries ---


func awaiting() -> int:
	return fake_awaiting


func act() -> int:
	return fake_act


func act_count() -> int:
	return fake_act_count


func draft_offer() -> PackedInt32Array:
	return fake_draft_offer


func draft_reroll_cost() -> int:
	return 0 if fake_free_rerolls > 0 else fake_draft_reroll_cost


func draft_buyout_cost() -> int:
	return fake_draft_buyout_cost


func patch_cost() -> int:
	return fake_patch_cost


func free_rerolls() -> int:
	return fake_free_rerolls


func route_option_count() -> int:
	return fake_route_options.size()


func route_option(i: int) -> Dictionary:
	return fake_route_options[i] if i >= 0 and i < fake_route_options.size() else {}


func boss_brief() -> Dictionary:
	return fake_boss_brief


func salvage_offer() -> Dictionary:
	return fake_salvage_offer


func weapon_slot_count() -> int:
	return fake_weapon_slots.size() if not fake_weapon_slots.is_empty() else super.weapon_slot_count()


func weapon_slot(i: int) -> Dictionary:
	if fake_weapon_slots.is_empty():
		return super.weapon_slot(i)
	return fake_weapon_slots[i] if i >= 0 and i < fake_weapon_slots.size() else {}


func active_slot() -> int:
	return fake_active_slot


func event_charges(id: StringName) -> int:
	var n: int = fake_event_charges.get(id, 0)
	return n


func call_block_reason(id: StringName) -> int:
	var reason: int = fake_call_block.get(id, Reason.Id.UNKNOWN_ID)
	return reason


func active_events() -> Array[Dictionary]:
	return fake_active_events


func directive_stacks(id: StringName) -> int:
	var n: int = fake_directive_stacks.get(id, 0)
	return n


func build_tags() -> Dictionary:
	return fake_build_tags


func boss_phase() -> int:
	return fake_boss_phase


func boss_phase_count() -> int:
	return fake_boss_phase_count


func run_seed() -> int:
	return fake_run_seed


func draft_buyout_used() -> bool:
	return fake_buyout_used


func draft_actions_locked() -> bool:
	return fake_draft_locked


func crate_status() -> Dictionary:
	return fake_crate_status


func _draft_id(slot: int) -> StringName:
	return fake_draft_ids[slot] if slot >= 0 and slot < fake_draft_ids.size() else &""


## True (and the PAUSED refusal is emitted) while the fake is paused.
func _blocked(command_id: int) -> bool:
	if fake_variety_paused:
		Events.command_rejected.emit(command_id, Reason.Id.PAUSED)
	return fake_variety_paused
