class_name FakeRunPresets
extends RefCounted
## Ready-made FakeRunApi states for the HUD sandbox and UI tests (VARIETY_SPEC 11.1 to 11.4): a draft of three
## directives, a route choice, a boss briefing, a salvage choice and the two-weapon combat HUD. Ids come from
## `content` when it has the variety data and fall back to the slice ids, so the presets also work on the legacy
## fixture. Each preset sets the query state and emits the signals the real flow emits at that moment.

const STATES: PackedStringArray = ["draft", "route", "boss_brief", "salvage", "combat2"]


## Applies the preset `state` (one of STATES). False for an unknown name.
static func apply(api: FakeRunApi, content: ContentSet, state: String) -> bool:
	match state:
		"draft":
			draft(api, content)
		"route":
			route(api)
		"boss_brief":
			boss_brief(api)
		"salvage":
			salvage(api)
		"combat2":
			combat2(api)
		_:
			return false
	return true


static func _intermission(api: FakeRunApi, awaiting: int) -> void:
	api.fake_phase = GameState.Id.INTERMISSION
	api.fake_phase_ticks_left = 0
	api.fake_wave = 2
	api.fake_wave_count = 5
	api.fake_act = 1
	api.fake_alive = 0
	api.fake_core_hp = 640.0
	api.fake_scrap = 410
	api.fake_awaiting = awaiting
	api.fake_build_tags = {&"bullet": 2, &"tempo": 1}
	api.fake_directive_stacks = {&"hot_loads": 2, &"emp_capacitor": 1}
	_two_weapons(api)
	Events.wave_cleared.emit(api.fake_wave)
	Events.core_changed.emit(api.fake_core_hp, api.fake_core_max_hp)
	Events.scrap_changed.emit(api.fake_scrap)
	Events.await_changed.emit(awaiting)


static func _two_weapons(api: FakeRunApi) -> void:
	api.fake_weapon_slots = [
		{"id": &"arc_projector", "level": 2, "magazine": 0, "size": 0, "heat": 56, "heat_cap": 100,
			"state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"smg", "level": 1, "magazine": 30, "size": 30, "heat": 0, "heat_cap": 0,
			"state": RunApi.SLOT_READY, "ticks_left": 0},
	]
	api.fake_active_slot = 0
	api.fake_weapon_id = &"arc_projector"


## Three offers: a rare, a stackable common (2 of 5 held) and the corrupted one.
static func draft(api: FakeRunApi, content: ContentSet) -> void:
	_intermission(api, RunApi.AWAIT_DRAFT)
	api.fake_draft_ids = [&"incendiary_tips", &"hot_loads", &"glass_cannon"]
	api.fake_draft_offer = PackedInt32Array()
	for i: int in api.fake_draft_ids.size():
		var index: int = content.directive_index(api.fake_draft_ids[i]) if content != null else -1
		api.fake_draft_offer.append(index if index >= 0 else i)
	api.fake_draft_reroll_cost = 60
	api.fake_draft_buyout_cost = 250
	api.fake_patch_cost = 180
	api.fake_free_rerolls = 0
	Events.draft_offered.emit(api.fake_draft_ids)


## A standard and a hot option before wave 3.
static func route(api: FakeRunApi) -> void:
	_intermission(api, RunApi.AWAIT_ROUTE)
	api.fake_route_options = [
		{"pack": &"pack_column", "name_key": "pack.column.name", "counts": {&"hollow_warden": 8, &"skitter": 21}, "total": 29,
			"modifier": &"", "modifier_key": "", "elites": 1, "hot": false,
			"reward": &"rw_scrap", "reward_key": "reward.scrap.name", "reward_amount": 120},
		{"pack": &"pack_powder", "name_key": "pack.powder.name", "counts": {&"burster": 10, &"skitter": 26, &"mote": 29},
			"total": 65, "modifier": &"mod_volatile", "modifier_key": "modifier.volatile.name", "elites": 1, "hot": true,
			"reward": &"rw_crate", "reward_key": "reward.crate.name", "reward_amount": 0},
	]
	Events.route_offered.emit()


static func boss_brief(api: FakeRunApi) -> void:
	_intermission(api, RunApi.AWAIT_BOSS_BRIEF)
	api.fake_wave = 4
	api.fake_boss_brief = {
		"id": &"siege_hulk", "name_key": "boss.siege_hulk.name", "variant": &"", "banner_key": "boss.siege_hulk.banner",
		"attack_key": "lore.threat.siege_hulk", "answer_key": "",
	}


## A new weapon against the two carried ones.
static func salvage(api: FakeRunApi) -> void:
	_intermission(api, RunApi.AWAIT_SALVAGE)
	api.fake_weapon_slots = [
		{"id": &"smg", "level": 2, "magazine": 30, "size": 30, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
		{"id": &"pistol", "level": 1, "magazine": 12, "size": 12, "heat": 0, "heat_cap": 0, "state": RunApi.SLOT_READY, "ticks_left": 0},
	]
	api.fake_weapon_id = &"smg"
	api.fake_salvage_offer = {"weapons": [&"arc_projector"], "tiers": [5], "level_up_slot": [-1], "boss": false, "scrap_value": 80}
	Events.salvage_offered.emit()


## Combat with two weapons (heat weapon active), two Deadfall charges and a strike warning on the ticker.
static func combat2(api: FakeRunApi) -> void:
	api.fake_phase = GameState.Id.SPAWNING
	api.fake_awaiting = RunApi.AWAIT_NONE
	api.fake_wave = 3
	api.fake_wave_count = 5
	api.fake_act = 1
	api.fake_alive = 31
	api.fake_core_hp = 640.0
	api.fake_scrap = 410
	_two_weapons(api)
	api.fake_event_charges = {&"deadfall_strike": 2}
	api.fake_call_block = {&"deadfall_strike": Reason.Id.OK, &"core_vent": Reason.Id.WRONG_STATE}
	api.fake_active_events = [
		{"id": &"deadfall_strike", "phase": 0, "ticks_left": 90, "ticks_total": 120, "harmful": false, "x": 2.0, "z": -3.0},
	]
	Events.wave_started.emit(api.fake_wave)
	Events.core_changed.emit(api.fake_core_hp, api.fake_core_max_hp)
	Events.scrap_changed.emit(api.fake_scrap)
	Events.weapon_swapped.emit(0, &"arc_projector")
	Events.charges_changed.emit(&"deadfall_strike", 2)
	Events.event_warned.emit(&"deadfall_strike", 90, 2.0, -3.0)
