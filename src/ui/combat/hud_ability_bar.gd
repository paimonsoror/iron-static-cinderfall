class_name HudAbilityBar
extends HBoxContainer
## The three ability buttons. A tap on a READY button mints one command id and issues one activate_ability;
## a tap while cooling, active, offline or on standby issues nothing and shakes the button (GDD 10.1).

var buttons: Dictionary[StringName, HudAbilityButton] = {}
var _api: RunApi


func _init() -> void:
	add_theme_constant_override(&"separation", HudStyle.GAP)
	for id: StringName in Ids.ABILITIES:
		var b: HudAbilityButton = HudAbilityButton.new(id)
		b.tapped.connect(_on_tapped)
		add_child(b)
		buttons[id] = b


func setup(api: RunApi) -> void:
	_api = api
	refresh()


func refresh() -> void:
	if _api == null:
		return
	for id: StringName in Ids.ABILITIES:
		_update(id)


## READY, ACTIVE, COOLING or STANDBY for one ability, from the queries alone.
func state_for(id: StringName) -> int:
	if _api.ability_active_left(id) > 0:
		return HudAbilityButton.State.ACTIVE
	if _api.ability_block_reason(id) == Reason.Id.LOCKED_BY_EVENT:
		return HudAbilityButton.State.OFFLINE  # a Static Front: cooldowns freeze, nothing can be started
	if _api.ability_cooldown_left(id) > 0:
		return HudAbilityButton.State.COOLING
	var reason: int = _api.ability_block_reason(id)
	match reason:
		Reason.Id.OK:
			return HudAbilityButton.State.READY
		Reason.Id.ON_COOLDOWN:
			return HudAbilityButton.State.COOLING
		Reason.Id.ALREADY_ACTIVE:
			return HudAbilityButton.State.ACTIVE
		_:
			return HudAbilityButton.State.STANDBY


func _update(id: StringName) -> void:
	var b: HudAbilityButton = buttons[id]
	var st: int = state_for(id)
	var secs: int = 0
	var sweep: float = 0.0
	var bar_fraction: float = 1.0
	match st:
		HudAbilityButton.State.ACTIVE:
			var left: int = _api.ability_active_left(id)
			var total: int = maxi(_api.ability_active_total(id), maxi(left, 1))
			secs = HudStyle.secs(left)
			sweep = float(left) / float(total)
			bar_fraction = sweep
		HudAbilityButton.State.COOLING:
			var left: int = _api.ability_cooldown_left(id)
			var total: int = maxi(_api.ability_cooldown_total(id), maxi(left, 1))
			secs = HudStyle.secs(left)
			sweep = float(left) / float(total)
			bar_fraction = 1.0 - sweep
	b.show_state(st, secs, sweep, bar_fraction)


func _on_tapped(id: StringName) -> void:
	if _api == null:
		return
	var b: HudAbilityButton = buttons[id]
	if state_for(id) != HudAbilityButton.State.READY:
		b.play_deny()
		Sfx.play(&"ui_deny")
		return
	Sfx.play(&"ui_tap")
	_api.activate_ability(_api.next_command_id(), id)


## Events.ability_activated: a small pulse on the pressed button.
func on_activated(id: StringName) -> void:
	if buttons.has(id):
		buttons[id].play_pulse()
	refresh()


## Events.ability_rejected: shake and deny sound (the HUD blocks most taps itself, so this is the rare race).
func on_rejected(id: StringName, _reason: int) -> void:
	if buttons.has(id):
		buttons[id].play_deny()
	Sfx.play(&"ui_deny")
	refresh()
