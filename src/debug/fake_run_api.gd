class_name FakeRunApi
extends FakeVarietyApi
## RunApi with public state for every query, recording every command in `calls` and emitting the matching
## Events signals, so the HUD can be built and tested with no simulation (ARCH 7.2).
##
## Query state lives in `fake_*` vars (a var cannot share a name with its query method):
##   fake_paused, fake_phase, fake_wave, fake_wave_count, fake_phase_ticks_left, fake_core_hp, fake_core_max_hp,
##   fake_shield_hp, fake_shield_max, fake_scrap, fake_weapon_id, fake_magazine, fake_magazine_size,
##   fake_reload_ticks_left, fake_alive, fake_pending, fake_boss_hp, fake_boss_max_hp, and the per-id
##   dictionaries fake_upgrade_level, fake_upgrade_max, fake_upgrade_cost, fake_purchase_block,
##   fake_ability_block, fake_ability_cooldown_left, fake_ability_cooldown_total, fake_ability_active_left,
##   fake_ability_active_total (keys are the StringName ids of Ids.UPGRADES / Ids.ABILITIES).
## Commands append {"cmd": "purchase_upgrade" | "activate_ability" | "skip_intermission" | "pause" | "resume",
## "command_id": int, "id": StringName} to `calls`. While paused a purchase or ability emits
## Events.purchase_resolved(id, false, Reason.Id.PAUSED) / Events.ability_rejected(id, Reason.Id.PAUSED) and
## nothing else. Otherwise a purchase resolves with fake_purchase_block[id] (Reason.Id.OK = success; the state
## is NOT changed, tests set it themselves).
## The queries and commands of the variety milestone (draft, route, salvage, weapon slots, events) are in the parent
## class FakeVarietyApi; their calls land in the same `calls` list with an extra "arg" entry.

var calls: Array[Dictionary] = []

var fake_paused: bool = false
var fake_phase: int = GameState.Id.SPAWNING
var fake_wave: int = 1
var fake_wave_count: int = 5
var fake_phase_ticks_left: int = 0
var fake_core_hp: float = 1000.0
var fake_core_max_hp: float = 1000.0
var fake_shield_hp: float = 0.0
var fake_shield_max: float = 100.0
var fake_scrap: int = 0
var fake_weapon_id: StringName = &"pistol"
var fake_magazine: int = 12
var fake_magazine_size: int = 12
var fake_reload_ticks_left: int = 0
var fake_alive: int = 0
var fake_pending: int = 0
var fake_boss_hp: float = -1.0
var fake_boss_max_hp: float = 2800.0
var fake_upgrade_level: Dictionary = {}
var fake_upgrade_max: Dictionary = {}
var fake_upgrade_cost: Dictionary = {}
var fake_purchase_block: Dictionary = {}
var fake_ability_block: Dictionary = {}
var fake_ability_cooldown_left: Dictionary = {}
var fake_ability_cooldown_total: Dictionary = {}
var fake_ability_active_left: Dictionary = {}
var fake_ability_active_total: Dictionary = {}


func _init() -> void:
	var max_levels: Array[int] = [5, 5, 5, 2, 1]
	var first_costs: Array[int] = [175, 150, 200, 350, 300]
	for i: int in Ids.UPGRADES.size():
		var u: StringName = Ids.UPGRADES[i]
		fake_upgrade_level[u] = 0
		fake_upgrade_max[u] = max_levels[i]
		fake_upgrade_cost[u] = first_costs[i]
		fake_purchase_block[u] = Reason.Id.OK
	var cooldowns: Array[int] = [2100, 3000, 3600]
	var durations: Array[int] = [0, 480, 360]
	for i: int in Ids.ABILITIES.size():
		var a: StringName = Ids.ABILITIES[i]
		fake_ability_block[a] = Reason.Id.OK
		fake_ability_cooldown_left[a] = 0
		fake_ability_cooldown_total[a] = cooldowns[i]
		fake_ability_active_left[a] = 0
		fake_ability_active_total[a] = durations[i]


# --- helpers for tests and sandboxes ---


func set_scrap(value: int) -> void:
	fake_scrap = value
	Events.scrap_changed.emit(value)


func set_core(hp: float) -> void:
	fake_core_hp = hp
	Events.core_changed.emit(hp, fake_core_max_hp)


func clear_calls() -> void:
	calls.clear()


func _record(entry: Dictionary) -> void:
	calls.append(entry)


# --- commands ---


func purchase_upgrade(command_id: int, upgrade_id: StringName) -> void:
	calls.append({"cmd": "purchase_upgrade", "command_id": command_id, "id": upgrade_id})
	if fake_paused:
		Events.purchase_resolved.emit(command_id, false, Reason.Id.PAUSED)
		return
	var reason: int = _reason(fake_purchase_block, upgrade_id)
	Events.purchase_resolved.emit(command_id, reason == Reason.Id.OK, reason)


func activate_ability(command_id: int, ability_id: StringName) -> void:
	calls.append({"cmd": "activate_ability", "command_id": command_id, "id": ability_id})
	if fake_paused:
		Events.ability_rejected.emit(ability_id, Reason.Id.PAUSED)
		return
	var reason: int = _reason(fake_ability_block, ability_id)
	if reason == Reason.Id.OK:
		Events.ability_activated.emit(ability_id)
	else:
		Events.ability_rejected.emit(ability_id, reason)


func skip_intermission() -> void:
	calls.append({"cmd": "skip_intermission", "command_id": 0, "id": &""})


func pause() -> void:
	calls.append({"cmd": "pause", "command_id": 0, "id": &""})
	fake_paused = true
	fake_variety_paused = true


func resume() -> void:
	calls.append({"cmd": "resume", "command_id": 0, "id": &""})
	fake_paused = false
	fake_variety_paused = false


# --- queries ---


func is_paused() -> bool:
	return fake_paused


func phase() -> int:
	return fake_phase


func wave() -> int:
	return fake_wave


func wave_count() -> int:
	return fake_wave_count


func phase_ticks_left() -> int:
	return fake_phase_ticks_left


func core_hp() -> float:
	return fake_core_hp


func core_max_hp() -> float:
	return fake_core_max_hp


func shield_hp() -> float:
	return fake_shield_hp


func shield_max() -> float:
	return fake_shield_max


func scrap() -> int:
	return fake_scrap


func upgrade_level(id: StringName) -> int:
	return _int(fake_upgrade_level, id, 0)


func upgrade_max_level(id: StringName) -> int:
	return _int(fake_upgrade_max, id, 0)


func upgrade_cost(id: StringName) -> int:
	return _int(fake_upgrade_cost, id, -1)


func purchase_block_reason(id: StringName) -> int:
	return _reason(fake_purchase_block, id)


func ability_block_reason(id: StringName) -> int:
	return _reason(fake_ability_block, id)


func ability_cooldown_left(id: StringName) -> int:
	return _int(fake_ability_cooldown_left, id, 0)


func ability_cooldown_total(id: StringName) -> int:
	return _int(fake_ability_cooldown_total, id, 0)


func ability_active_left(id: StringName) -> int:
	return _int(fake_ability_active_left, id, 0)


func ability_active_total(id: StringName) -> int:
	return _int(fake_ability_active_total, id, 0)


func weapon_id() -> StringName:
	return fake_weapon_id


func magazine() -> int:
	return fake_magazine


func magazine_size() -> int:
	return fake_magazine_size


func reload_ticks_left() -> int:
	return fake_reload_ticks_left


func alive_count() -> int:
	return fake_alive


func pending_spawn_count() -> int:
	return fake_pending


func boss_hp() -> float:
	return fake_boss_hp


func boss_max_hp() -> float:
	return fake_boss_max_hp


func _int(d: Dictionary, id: StringName, fallback: int) -> int:
	if not d.has(id):
		return fallback
	var v: int = d[id]
	return v


func _reason(d: Dictionary, id: StringName) -> int:
	if not d.has(id):
		return Reason.Id.UNKNOWN_ID
	var v: int = d[id]
	return v
