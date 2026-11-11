class_name GameFeedback
extends RefCounted
## Event-driven player feedback for one run: the three first-run hints (GDD 10.4, once per profile) and the haptic
## ticks (GDD A20). The HUD shows `Strings.t(key)` for every `Events.hint_requested` without checking whether the
## hint was seen, so this class is the only emitter of that signal and it filters through `Save.has_seen_hint`.
##
##   hint.tap_upgrades  first time Scrap reaches the price of the cheapest upgrade
##   hint.core_hit      first core hit
##   hint.intermission  first intermission
##
## `attach` connects Events; `detach` disconnects every connection (the run's teardown must leave none behind).

const HINT_TAP_UPGRADES: String = "hint.tap_upgrades"
const HINT_CORE_HIT: String = "hint.core_hit"
const HINT_INTERMISSION: String = "hint.intermission"
## Scrap for the first hint when the content has no upgrades to price (GDD 10.4: "first 150 Scrap").
const DEFAULT_HINT_SCRAP: int = 150

var scrap_threshold: int = DEFAULT_HINT_SCRAP

var _bindings: Array = []  ## [Signal, Callable] pairs


func attach(content: ContentSet) -> void:
	detach()
	scrap_threshold = _cheapest_upgrade(content)
	_bind(Events.scrap_changed, _on_scrap_changed)
	_bind(Events.core_hit, _on_core_hit)
	_bind(Events.intermission_started, _on_intermission_started)
	_bind(Events.purchase_resolved, _on_purchase_resolved)
	_bind(Events.boss_spawned, _on_boss_spawned)


func detach() -> void:
	for pair: Array in _bindings:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	_bindings.clear()


func connection_count() -> int:
	return _bindings.size()


## Shows `key` through the HUD unless this profile has seen it; remembers it. True when it was requested.
func request_hint(key: String) -> bool:
	if Save.has_seen_hint(key):
		return false
	Save.mark_hint_seen(key)
	Events.hint_requested.emit(key)
	return true


func _bind(sig: Signal, handler: Callable) -> void:
	sig.connect(handler)
	_bindings.append([sig, handler])


func _on_scrap_changed(value: int) -> void:
	if value >= scrap_threshold:
		request_hint(HINT_TAP_UPGRADES)


func _on_core_hit(_enemy_id: int, _kind: StringName, _hp_damage: float, _absorbed: float) -> void:
	request_hint(HINT_CORE_HIT)
	Haptics.tick()


func _on_intermission_started(_wave_cleared: int, _ticks: int) -> void:
	request_hint(HINT_INTERMISSION)


func _on_purchase_resolved(_command_id: int, success: bool, _reason: int) -> void:
	if success:
		Haptics.tick()


func _on_boss_spawned(_id: int, _kind: StringName) -> void:
	Haptics.tick(40)


## The lowest base price among the upgrades: the first moment the player can afford something.
static func _cheapest_upgrade(content: ContentSet) -> int:
	var best: int = 0
	for u: UpgradeDef in content.upgrades:
		if u.base_cost > 0 and (best == 0 or u.base_cost < best):
			best = u.base_cost
	return best if best > 0 else DEFAULT_HINT_SCRAP
