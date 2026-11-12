class_name RouteOverlay
extends RunOverlayBase
## The route screen (VARIETY_SPEC 11.2): 1 of 2 threats with pack, counts, modifier, elites, risk tag and reward. An
## overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_ROUTE; sends pick_route. A tap on a card selects it,
## CONFIRM sends; a long press shows what the pack is made of. The act banner (name, plating tier) and the act strip sit
## above, information only. `setup` is the frozen contract.

var cards: Array[RouteCard] = []
var selected: int = -1
var title_label: Label
var quiet_label: Label
var strip: RouteActStrip
var _cards_row: HBoxContainer


func setup(api: RunApi, content: ContentSet) -> void:
	_open(api, content)


## The number of the wave the player is choosing for.
func next_wave() -> int:
	return _api.wave() + 1


func _next_act() -> int:
	if _content.run != null:
		var slot: WaveSlotDef = _content.run.wave_slot(next_wave())
		if slot != null:
			return slot.act
	return _api.act()


func _populate() -> void:
	cards.clear()
	selected = -1
	_add_act_band(_next_act(), next_wave())
	strip = RouteActStrip.new()
	strip.setup(_api.wave_count(), next_wave(), _content)
	header.add_child(strip)
	title_label = RunUi.label(Strings.t("route.header"), 44, &"body", true)
	header.add_child(title_label)
	quiet_label = null
	if _both_hot():
		quiet_label = RunUi.label(Strings.t("route.none_quiet"), RunUi.MIN_TEXT + 4, &"danger", true)
		header.add_child(quiet_label)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override(&"separation", 28)
	controls.add_child(_cards_row)
	confirm_button = RunUi.button("", true)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)
	_build_cards()


func _both_hot() -> bool:
	var count: int = _api.route_option_count()
	if count < 2:
		return false
	for i: int in count:
		var hot: bool = _api.route_option(i).get("hot", false)
		if not hot:
			return false
	return true


func _build_cards() -> void:
	for child: Node in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	cards.clear()
	for i: int in _api.route_option_count():
		var card: RouteCard = RouteCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.build(i, _api.route_option(i))
		card.tapped.connect(_on_card.bind(i))
		card.long_pressed.connect(_on_long.bind(i))
		_cards_row.add_child(card)
		cards.append(card)
	selected = -1
	_relayout()
	_sync()


func _relayout() -> void:
	if _cards_row == null:
		return
	var h: float = size.y if size.y > 2.0 else 1920.0
	for card: RouteCard in cards:
		card.custom_minimum_size.y = clampf(h * 0.36, 540.0, 700.0)


func _sync() -> void:
	for card: RouteCard in cards:
		var on: bool = card.index == selected
		card.set_selected(on)
		card.set_dimmed(selected != -1 and not on)
	confirm_button.text = _confirm_text()
	confirm_button.disabled = selected == -1


## "CONFIRM: HOT"; the pack name when both options carry the same risk word.
func _confirm_text() -> String:
	if selected < 0 or selected >= cards.size():
		return Strings.t("draft.confirm_none")
	var card: RouteCard = cards[selected]
	var word: String = card.risk_word()
	var pack_key: String = card.option.get("name_key", "")
	for other: RouteCard in cards:
		if other != card and other.risk_word() == word:
			word = Strings.t(pack_key)
	return Strings.tf("route.confirm", [word])


func _on_card(i: int) -> void:
	_tap_sound()
	selected = i
	_sync()


func _on_confirm() -> void:
	if selected < 0:
		deny(confirm_button)
		return
	_tap_sound()
	_api.pick_route(_next_id(), selected)
	selected = -1
	_sync()


func _on_long(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	var card: RouteCard = cards[i]
	var extra: PackedStringArray = PackedStringArray()
	var counts: Dictionary = card.option.get("counts", {})
	for id: StringName in RouteCard.top_enemies(counts, counts.size()):
		var n: int = counts[id]
		extra.append("%s  %s" % [Strings.t("enemy.%s.name" % String(id)), Strings.tf("route.glyph_count", [n])])
	var total: int = card.option.get("total", 0)
	var body: String = Strings.tf("route.hostiles", [total])
	var mod_key: String = card.option.get("modifier_key", "")
	if mod_key != "":
		extra.append("%s: %s" % [Strings.t(mod_key), RunUi.opt(mod_key.trim_suffix(".name") + ".desc")])
	extra.append("%s: %s" % [Strings.t("route.reward"), RouteCard.reward_text(card.option)])
	var pack_key: String = card.option.get("name_key", "")
	var panel: RunDetailPanel = RunDetailPanel.new()
	panel.show_detail(Strings.t(pack_key), card.risk_word(), body, extra, card.rim_color)
	open_modal(panel)


func _bind_events() -> void:
	super._bind_events()
	_bind(Events.route_offered, _build_cards)
