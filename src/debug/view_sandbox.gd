extends Node
## BattleView + SimPuppet (ARCH 11). `--scenario=hold<N>` / `--scenario=boss` pick the puppet's crowd.
## Works inside the game, in the main window, and inside the capture SubViewport.

var _view: BattleView
var _puppet: SimPuppet
var _content: ContentSet


func _ready() -> void:
	_content = Content.db
	var packed: PackedScene = load("res://src/view/battle_view.tscn") as PackedScene
	_view = packed.instantiate() as BattleView
	add_child(_view)
	_view.setup(_content)
	var args: DebugArgs = DebugArgs.from_os()
	var count: int = args.scenario_n if args.scenario_n > 0 else 50
	_puppet = SimPuppet.new()
	add_child(_puppet)
	_puppet.setup(_content, count, args.run_seed if args.has_seed else 1, args.scenario == "boss")
	_view.bind(_puppet.world)
	get_viewport().size_changed.connect(_refit)
	_refit()


func _process(delta: float) -> void:
	var alpha: float = _puppet.advance(delta)
	_view.render(alpha, delta)


func _refit() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var top: float = HudLayout.top_band_px(size, Vector4.ZERO, _content.tokens)
	var bottom: float = HudLayout.bottom_band_px(size, Vector4.ZERO, _content.tokens)
	_view.fit_camera(size, top, bottom)
