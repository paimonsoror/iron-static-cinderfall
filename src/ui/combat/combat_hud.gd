class_name CombatHud
extends Control
## The whole combat interface, driven only by RunApi and Events. Wave 0 stub: a title, the Scrap count and
## a pause button. TODO(W1-G): top bar, upgrade drawer, ability bar, intermission panel (ARCH 7.2, 9).

signal pause_requested

var _api: RunApi
var _content: ContentSet
var _built: bool = false
var _scrap_label: Label


func _ready() -> void:
	_ensure_built()


@warning_ignore("unused_parameter")
func setup(api: RunApi, content: ContentSet, view: BattleView) -> void:
	_ensure_built()
	_api = api
	_content = content
	refresh()


## Re-reads the queries. The real HUD does this at 10 Hz and on signals.
func refresh() -> void:
	if _api != null and _scrap_label != null:
		_scrap_label.text = "%d" % _api.scrap()


func is_drawer_open() -> bool:
	# TODO(W1-G)
	return false


func close_drawer() -> void:
	# TODO(W1-G)
	pass


## Height of the band the HUD reserves at the top (the camera fits below it).
func top_band_px() -> float:
	if _content == null:
		return 0.0
	return HudLayout.top_band_px(get_viewport_rect().size, Vector4.ZERO, _content.tokens)


func bottom_band_px() -> float:
	if _content == null:
		return 0.0
	return HudLayout.bottom_band_px(get_viewport_rect().size, Vector4.ZERO, _content.tokens)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	var col: VBoxContainer = UiKit.stub_layout(self, "hud.title")
	_scrap_label = Label.new()
	col.add_child(_scrap_label)
	var pause: Button = UiKit.button("hud.pause")
	pause.pressed.connect(func() -> void: pause_requested.emit())
	col.add_child(pause)
