class_name RunHintLine
extends PanelContainer
## One first-run hint on a choice screen (GDD 10.4, VARIETY_SPEC 11.7): a single line of at least 30 px in a cyan-rimmed plate
## with a help mark, so the hint is shape, word and colour. It is information only (it never takes a tap). The choice screens
## cover the combat HUD's hint banner, so the draft, the route and the corrupted offer show theirs here, once per profile
## (`due` asks the profile; `RunOverlayBase.add_hint` marks it seen).

const SIZE: int = 30

var key: String = ""
var label: Label


## True when `key` has a text and this profile has not seen the hint.
static func due(hint_key: String) -> bool:
	return RunUi.has_key(hint_key) and not Save.has_seen_hint(hint_key)


func _init(hint_key: String = "") -> void:
	key = hint_key
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim: Color = UiTheme.rim(&"warden_cyan", RunUi.hc())
	var sb: StyleBoxFlat = RunUi.box(UiTheme.alpha(UiTheme.inset_fill(RunUi.hc()), 0.96), rim, 2, 12)
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	add_theme_stylebox_override(&"panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var mark: TextureRect = RunUi.icon(&"ticker_help", 40.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	label = RunUi.label(Strings.t(hint_key) if hint_key != "" else "", SIZE, &"body", true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
