class_name HudWeaponBar
extends Control
## The weapon bar of the bottom band (VARIETY_SPEC 11.4, GDD 9): one card per carried weapon (the active one 400 x 150, a
## holstered one 300 x 150, scaled to fit), then STRIKE and VENT (150 x 150) and, with signal_hijack, a smaller FREIGHT. A tap
## on a holstered card issues swap_weapon(slot); a tap on a call button issues call_event(id) when the RunApi says the call is
## legal (call_block_reason == OK), else it shakes and issues nothing. Everything shown comes from the RunApi queries.

const STRIKE: StringName = &"deadfall_strike"
const VENT: StringName = &"core_vent"
const FREIGHT: StringName = &"freight_call"
const ACTIVE_W: float = 400.0
const HOLSTERED_W: float = 300.0
const VENT_COST_FRAC: float = 0.08  ## CONTENT 6 (the EventDef may carry `core_cost_frac`)

var cards: Array[HudWeaponCard] = []
var strike: HudCallButton
var vent: HudCallButton
var freight: HudCallButton
var _api: RunApi
var _content: ContentSet
var _sig: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike = HudCallButton.new(STRIKE, &"call_strike", "hud.call.strike")
	vent = HudCallButton.new(VENT, &"call_vent", "hud.call.vent")
	freight = HudCallButton.new(FREIGHT, &"call_freight", "hud.call.freight")
	for b: HudCallButton in [strike, vent, freight]:
		b.called.connect(_on_call)
		add_child(b)
	strike.custom_minimum_size = Vector2(HudCallButton.SIZE, HudCallButton.SIZE)
	vent.custom_minimum_size = Vector2(HudCallButton.SIZE, HudCallButton.SIZE)
	freight.visible = false


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	refresh()


## The bar is `w` wide and `h` tall (150); the bottom panel sets its position.
func place(w: float, h: float) -> void:
	size = Vector2(w, h)
	_sig = ""
	_layout()


func refresh() -> void:
	if _api == null:
		return
	_ensure_cards()
	var count: int = cards.size()
	var active: int = _api.active_slot()
	var infos: Array[Dictionary] = []
	for i: int in count:
		infos.append(_api.weapon_slot(i))
	var hint: bool = _swap_would_help(infos, active)
	for i: int in count:
		cards[i].show_slot(infos[i], i == active, hint and i == active)
	_refresh_calls()
	_layout()


## Active card reloading or venting while a holstered one is ready (a hint, never an automatic swap).
func _swap_would_help(infos: Array[Dictionary], active: int) -> bool:
	if active < 0 or active >= infos.size():
		return false
	var state: int = infos[active].get("state", RunApi.SLOT_READY)
	if state != RunApi.SLOT_RELOADING and state != RunApi.SLOT_VENTING:
		return false
	for i: int in infos.size():
		var other: int = infos[i].get("state", RunApi.SLOT_EMPTY)
		var id: StringName = infos[i].get("id", &"")
		if i != active and id != &"" and other == RunApi.SLOT_READY:
			return true
	return false


func _ensure_cards() -> void:
	var want: int = maxi(_api.weapon_slot_count(), 1)
	while cards.size() < want:
		var card: HudWeaponCard = HudWeaponCard.new(cards.size())
		card.tapped.connect(_on_card)
		add_child(card)
		move_child(card, cards.size())
		cards.append(card)
	while cards.size() > want:
		var extra: HudWeaponCard = cards.pop_back()
		remove_child(extra)
		extra.queue_free()


func _refresh_calls() -> void:
	var charges: int = _api.event_charges(STRIKE)
	_show_call(strike, Strings.tf("hud.call.charges", [charges]))
	_show_call(vent, Strings.tf("hud.call.vent_price", [roundi(_vent_frac() * 100.0)]))
	var has_freight: bool = _api.directive_stacks(&"signal_hijack") > 0 or _api.event_charges(FREIGHT) > 0
	freight.visible = has_freight
	if has_freight:
		_show_call(freight, Strings.tf("hud.call.charges", [_api.event_charges(FREIGHT)]))


func _show_call(button: HudCallButton, value: String) -> void:
	var reason: int = _api.call_block_reason(button.event_id)
	var offline: bool = reason == Reason.Id.LOCKED_BY_EVENT
	button.show_state(reason == Reason.Id.OK, value, Strings.t("hud.ability.offline") if offline else "")
	if not offline:
		button.set_name_text(Strings.t("hud.call.%s" % _call_word(button.event_id)))


static func _call_word(id: StringName) -> String:
	match id:
		STRIKE:
			return "strike"
		VENT:
			return "vent"
	return "freight"


func _vent_frac() -> float:
	var def: EventDef = _content.event_def(VENT) if _content != null else null
	return def.param(&"core_cost_frac", VENT_COST_FRAC) if def != null else VENT_COST_FRAC


## Card and call-button rects: the cards scale to what the call buttons leave (400 / 300 ideal widths).
func _layout() -> void:
	var calls: Array[HudCallButton] = [strike, vent]
	if freight.visible:
		calls.append(freight)
	var sig: String = "%d|%d|%d|%d|%d" % [roundi(size.x), roundi(size.y), cards.size(), calls.size(), _api.active_slot() if _api != null else 0]
	if sig == _sig or size.x < 10.0:
		return
	_sig = sig
	var gap: float = float(HudStyle.GAP)
	var call_w: float = 0.0
	for b: HudCallButton in calls:
		call_w += HudCallButton.SIZE if b != freight else HudCallButton.SMALL
	var active: int = _api.active_slot() if _api != null else 0
	var ideal: float = 0.0
	for i: int in cards.size():
		ideal += ACTIVE_W if i == active else HOLSTERED_W
	var room: float = size.x - call_w - gap * float(cards.size() + calls.size() - 1)
	var scale_by: float = room / maxf(ideal, 1.0)
	var x: float = 0.0
	for i: int in cards.size():
		var w: float = (ACTIVE_W if i == active else HOLSTERED_W) * scale_by
		cards[i].position = Vector2(x, 0.0)
		cards[i].size = Vector2(w, size.y)
		cards[i].set_card_width(w)
		x += w + gap
	for b: HudCallButton in calls:
		var side: float = HudCallButton.SMALL if b == freight else HudCallButton.SIZE
		b.position = Vector2(x, (size.y - side) * 0.5)
		b.size = Vector2(side, side)
		x += side + gap


func _on_card(slot: int) -> void:
	if _api == null or slot == _api.active_slot():
		return
	var info: Dictionary = _api.weapon_slot(slot)
	var id: StringName = info.get("id", &"")
	if id == &"" or slot >= cards.size():
		Sfx.play(&"ui_deny")
		return
	Sfx.play(&"ui_tap")
	_api.swap_weapon(_api.next_command_id(), slot)


func _on_call(id: StringName) -> void:
	if _api == null:
		return
	var button: HudCallButton = strike if id == STRIKE else (vent if id == VENT else freight)
	if not button.ready_now:
		button.play_deny()
		Sfx.play(&"ui_deny")
		return
	Sfx.play(&"ui_tap")
	_api.call_event(_api.next_command_id(), id)
