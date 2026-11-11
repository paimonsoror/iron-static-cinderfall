class_name HudUpgradeDrawer
extends PanelContainer
## The upgrade drawer: five cards in a row (Damage, Fire Rate, Armor Piercing, Turret, SMG). A tap on a buyable
## card mints one command id and issues one purchase_upgrade; a tap on a blocked card issues nothing, shakes the
## card and shows the reason (GDD 5.2, 9, 10.1). The HUD decides when the drawer is shown.

var cards: Dictionary[StringName, HudUpgradeCard] = {}
var _api: RunApi
var _content: ContentSet
var _pending: Dictionary[int, StringName] = {}  ## command id -> upgrade id, for the resolved feedback


func _init() -> void:
	var sb: StyleBoxFlat = HudStyle.panel(
		HudStyle.alpha(HudStyle.color(&"obsidian"), 0.95), HudStyle.alpha(HudStyle.color(&"warden_cyan"), 0.8), 0, 3)
	sb.content_margin_left = float(HudStyle.EDGE)
	sb.content_margin_right = float(HudStyle.EDGE)
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	add_theme_stylebox_override(&"panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	for id: StringName in Ids.UPGRADES:
		var card: HudUpgradeCard = HudUpgradeCard.new(id)
		card.tapped.connect(_on_card_tapped)
		row.add_child(card)
		cards[id] = card


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	refresh()


## The height the drawer needs (cards plus padding).
func needed_height() -> float:
	return get_combined_minimum_size().y


func refresh() -> void:
	if _api == null:
		return
	for id: StringName in Ids.UPGRADES:
		var cost: int = _api.upgrade_cost(id)
		var level: int = _api.upgrade_level(id)
		var max_level: int = _api.upgrade_max_level(id)
		var maxed: bool = cost < 0 or (max_level > 0 and level >= max_level)
		cards[id].show_state(level, max_level, cost, reason_for(id), effect_text(id, level, max_level), maxed)


## How many cards can be bought right now.
func affordable_count() -> int:
	if _api == null:
		return 0
	var n: int = 0
	for id: StringName in Ids.UPGRADES:
		if reason_for(id) == Reason.Id.OK:
			n += 1
	return n


## The API's block reason, plus a local Scrap check so the card never looks buyable when it is not.
func reason_for(id: StringName) -> int:
	var reason: int = _api.purchase_block_reason(id)
	if reason != Reason.Id.OK:
		return reason
	var cost: int = _api.upgrade_cost(id)
	if cost < 0:
		return Reason.Id.MAX_LEVEL
	if _api.scrap() < cost:
		return Reason.Id.INSUFFICIENT_SCRAP
	return Reason.Id.OK


## The exact effect of the next level, e.g. "+20% damage" or "Deploy turret 1/2".
func effect_text(id: StringName, level: int, max_level: int) -> String:
	var key: String = "hud.effect.%s" % String(id)
	var def: UpgradeDef = _content.upgrade(id) if _content != null else null
	if def == null:
		return Strings.t("hud.effect.done")
	match def.kind:
		UpgradeDef.Kind.TURRET:
			return Strings.tf(key, [mini(level + 1, max_level), max_level])
		UpgradeDef.Kind.WEAPON_UNLOCK:
			return Strings.t(key)
		_:
			return Strings.tf(key, [roundi(def.per_level * 100.0)])


func _on_card_tapped(id: StringName) -> void:
	if _api == null:
		return
	var card: HudUpgradeCard = cards[id]
	var reason: int = reason_for(id)
	if reason != Reason.Id.OK:
		card.play_deny(Strings.t(Reason.string_key(reason)))
		Sfx.play(&"ui_deny")
		return
	var command_id: int = _api.next_command_id()
	_pending[command_id] = id
	Sfx.play(&"ui_tap")
	_api.purchase_upgrade(command_id, id)


## Events.purchase_resolved: pulse on success, shake with the reason on failure (only for taps made here).
func on_purchase_resolved(command_id: int, success: bool, reason: int) -> void:
	if not _pending.has(command_id):
		return
	var id: StringName = _pending[command_id]
	_pending.erase(command_id)
	var card: HudUpgradeCard = cards[id]
	if success:
		card.play_pulse()
		Sfx.play(&"ui_purchase")
	else:
		card.play_deny(Strings.t(Reason.string_key(reason)))
		Sfx.play(&"ui_deny")
	refresh()
