class_name DirectiveCard
extends RunSelectable
## One offered directive of the draft screen (VARIETY_SPEC 11.1): rarity word and category mark, the tag glyph on its
## rarity frame, name, stack counter ("2 -> 3 / 5"), effect, tags and, for a corrupted directive, the PRICE line as large as
## the gain on a red frame. BUY-OUT ("KEEP ALSO 250") is a staged choice shown on the unselected cards after a selection.
## A taken slot (`def == null`) is a dimmed plate that ignores taps.

signal buyout_toggled

var slot: int = 0
var def: DirectiveDef
var buyout_button: Button
var price_label: Label
var desc_label: Label
var name_label: Label
var stack_label: Label
var rarity_label: Label
var tag_labels: Array[Label] = []
var icon_block: Control  ## the rarity frame with its tag glyph; a near-square window leaves it out (room for the BUY-OUT row)
var _buyout_on: bool = false


## `held` = stacks already held; `narrow` = 4 offers (the cards are 250 px wide and the name is 32 px).
func build(card_slot: int, directive: DirectiveDef, held: int, narrow: bool) -> void:
	slot = card_slot
	def = directive
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	add_child(col)
	if def == null:
		enabled = false
		rim_color = RunUi.rarity_rim(DirectiveDef.Rarity.COMMON)
		var taken: Label = RunUi.center(RunUi.label(Strings.t("draft.kept"), UiTheme.FONT_BODY, &"dim", true))
		taken.size_flags_vertical = Control.SIZE_EXPAND_FILL
		taken.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label = taken
		col.add_child(taken)
		restyle()
		set_dimmed(true)
		return
	rim_color = RunUi.rarity_rim(def.rarity)
	var corrupted: bool = def.rarity == DirectiveDef.Rarity.CORRUPTED
	col.add_child(_top_row())
	icon_block = _icon_block()
	col.add_child(icon_block)
	name_label = RunUi.label(Strings.t(def.name_key), 32 if narrow else UiTheme.FONT_BODY, &"body", true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(RunUi.wrap(name_label, 3))
	stack_label = RunUi.center(RunUi.label(_stack_text(held), RunUi.MIN_TEXT, &"accent", true))
	col.add_child(stack_label)
	var desc_size: int = 34 if corrupted else RunUi.MIN_TEXT
	desc_label = RunUi.label(Strings.t(def.desc_key), desc_size, &"body", corrupted)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(RunUi.wrap(desc_label, 6))
	if corrupted:
		col.add_child(_price_block())
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_tag_row())
	buyout_button = RunUi.button("", false, RunUi.MIN_TEXT)
	buyout_button.visible = false
	buyout_button.pressed.connect(_on_buyout)
	col.add_child(buyout_button)
	RunUi.ignore_mouse_except_buttons(self)
	restyle()


## Shows or hides the BUY-OUT button; `cost` is its price, `on` whether this slot is the staged buy-out.
func set_buyout(available: bool, cost: int, on: bool, affordable: bool) -> void:
	if buyout_button == null:
		return
	buyout_button.visible = available
	_buyout_on = on
	buyout_button.text = Strings.t("draft.buyout_on") if on else Strings.tf("draft.buyout", [cost])
	buyout_button.theme_type_variation = UiTheme.BUTTON_SEGMENT
	buyout_button.toggle_mode = true
	buyout_button.set_pressed_no_signal(on)
	buyout_button.modulate = Color(1.0, 1.0, 1.0, 1.0 if affordable or on else 0.6)


## A near-square window drops the icon block, so the card with its BUY-OUT row still fits the height.
func set_compact(compact: bool) -> void:
	if icon_block != null:
		icon_block.visible = not compact


func is_corrupted() -> bool:
	return def != null and def.rarity == DirectiveDef.Rarity.CORRUPTED


func _top_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	rarity_label = RunUi.label(Strings.t("directive.rarity.%s" % DirectiveDef.RARITY_NAMES[def.rarity]), RunUi.MIN_TEXT, &"body", true)
	rarity_label.add_theme_color_override(&"font_color", rim_color if def.rarity != DirectiveDef.Rarity.COMMON else RunUi.text_color(&"dim"))
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(rarity_label)
	var mark: TextureRect = RunUi.icon(StringName("cat_%s" % DirectiveDef.CATEGORY_NAMES[def.category]), 36.0, rim_color)
	mark.tooltip_text = Strings.t("directive.cat.%s" % DirectiveDef.CATEGORY_NAMES[def.category])
	row.add_child(mark)
	return row


func _icon_block() -> Control:
	var box: Control = Control.new()
	box.custom_minimum_size = Vector2(0.0, 104.0)
	var frame: TextureRect = RunUi.icon(StringName("frame_%s" % DirectiveDef.RARITY_NAMES[def.rarity]), 104.0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -52.0
	frame.offset_right = 52.0
	frame.offset_top = -52.0
	frame.offset_bottom = 52.0
	box.add_child(frame)
	if not def.tags.is_empty():
		var glyph: TextureRect = RunUi.icon(StringName("tag_%s" % String(def.tags[0])), 60.0)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		glyph.offset_left = -30.0
		glyph.offset_right = 30.0
		glyph.offset_top = -30.0
		glyph.offset_bottom = 30.0
		box.add_child(glyph)
	return box


## The price of a corrupted directive, printed as large as its gain (the effect line above is 34 px bold too).
func _price_block() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", RunUi.box(UiTheme.alpha(UiTheme.color(&"chorus_red"), 0.16), rim_color, 2, 8))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	panel.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	head.add_child(RunUi.icon(&"ticker_warn", 34.0))
	head.add_child(RunUi.label(Strings.t("directive.price_label"), RunUi.MIN_TEXT, &"danger", true))
	col.add_child(head)
	price_label = RunUi.label(Strings.t("directive.%s.price" % String(def.id)), 34, &"danger", true)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(RunUi.wrap(price_label, 3))
	return panel


func _tag_row() -> Control:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override(&"h_separation", 8)
	flow.add_theme_constant_override(&"v_separation", 4)
	for tag: StringName in def.tags:
		var chip: PanelContainer = PanelContainer.new()
		chip.add_theme_stylebox_override(&"panel", RunUi.chip_box())
		var l: Label = RunUi.label(RunUi.tag_name(tag), RunUi.MIN_TEXT, &"dim", true)
		tag_labels.append(l)
		chip.add_child(l)
		flow.add_child(chip)
	return flow


func _stack_text(held: int) -> String:
	if def.max_stacks > 1 or held > 0:
		return Strings.tf("directive.stacks", [held, mini(held + 1, def.max_stacks), def.max_stacks])
	return Strings.t("directive.new")


func _on_buyout() -> void:
	buyout_toggled.emit()
