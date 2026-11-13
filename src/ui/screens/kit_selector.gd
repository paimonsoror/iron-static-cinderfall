class_name KitSelector
extends VBoxContainer
## The kit selector of the briefing (GDD 8.5, 10.2; ARCH 9): a "STARTING KIT" heading, a horizontal list of kit cards (scrolls
## sideways when they do not fit) and the rules of the kit in focus in a line below. A tap on an owned kit selects it and
## writes the choice through the bank (`Save.set_kit`), then emits `kit_selected(id)`; a tap on a locked kit only reads
## its Archive hint. It shows only when the content has more than the standard kit (a generated run).

signal kit_selected(id: StringName)

var cards: Array[KitCard] = []
var heading: Label
var rules_label: Label
var scroll: ScrollContainer
var selected_id: StringName = &""
var _bank: ArchiveBank
var _content: ContentSet
var _row: HBoxContainer


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	heading = UiKit.label_text(Strings.t("briefing.kit"), UiTheme.LABEL_ACCENT, UiTheme.FONT_SMALL + 2)
	add_child(heading)
	scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # a drag scrolls; the next card peeking in is the cue
	scroll.custom_minimum_size = Vector2(0.0, KitCard.HEIGHT + 24.0)  # room for the lifted card and its halo
	add_child(scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 14)
	scroll.add_child(_row)
	rules_label = UiKit.label_text("", UiTheme.LABEL_DIM, RunUi.MIN_TEXT)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size.y = 2.0 * 40.0
	add_child(rules_label)


## `bank` is for sandboxes and tests; by default the profile in `Save` is read and written.
func setup(profile: Profile, content: ContentSet, bank: ArchiveBank = null) -> void:
	_content = content
	if bank != null:
		_bank = bank
	elif profile == Save.profile:
		_bank = SaveArchiveBank.new(content)
	else:
		_bank = ArchiveBank.new(profile, content)
	visible = content != null and content.kits.size() > 1
	_build_cards()
	var chosen: StringName = _bank.kit()
	if not _is_owned(content.kit(chosen)):
		chosen = &"k_standard"
	select(chosen, false)


## Selects the kit `id` when it is owned. `write` false only shows the choice (the setup does that).
func select(id: StringName, write: bool = true) -> bool:
	var card: KitCard = card_of(id)
	if card == null:
		return false
	if not card.owned:
		rules_label.text = card.rules_text()
		return false
	selected_id = id
	for other: KitCard in cards:
		other.show_state(other == card)
	rules_label.text = card.rules_text()
	if write:
		_bank.set_kit(id)
		kit_selected.emit(id)
	return true


func card_of(id: StringName) -> KitCard:
	for card: KitCard in cards:
		if card.kit.id == id:
			return card
	return null


func _build_cards() -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	cards.clear()
	if _content == null:
		return
	for def: KitDef in _content.kits:
		var card: KitCard = KitCard.new()
		card.build(def, _content, _is_owned(def))
		card.tapped.connect(_on_card.bind(def.id))
		_row.add_child(card)
		cards.append(card)


func _is_owned(def: KitDef) -> bool:
	return def != null and (def.cost <= 0 or _bank.owns(def.id))


func _on_card(id: StringName) -> void:
	var card: KitCard = card_of(id)
	if card != null and not card.owned:
		Sfx.play(&"ui_deny")
	else:
		Sfx.play(&"ui_tap")
	var _ok: bool = select(id)
