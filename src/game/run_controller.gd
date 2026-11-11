class_name RunController
extends Node
## Owns one run: ticks the sim, drains its events into Events in order, renders the view (ARCH 7.3). It is the only
## emitter of the gameplay signals. When the sim pushes RUN_FINISHED it grants the Recovered Data (GameRewards) and
## only then emits `Events.run_finished`; no UI code grants. The sim does not know about pausing: a paused run is
## simply not stepped, so its state hash and every cooldown stay exactly as they were.

## The sim moved to another run phase. Game mirrors it into the application state machine (and `Events.state_changed`).
signal phase_changed(previous: int, current: int)
## Pause state flipped (by `set_paused`, which `RunApi.pause()` and `resume()` call).
signal paused_changed(is_paused: bool)

var sim: SimWorld
var api: SimRunApi
var run_id: String
var paused: bool = false
var bot: PolicyBot = null  ## set by --autoplay
var scenario: GameHoldScenario = null  ## set by --scenario=hold<N>
var driver: TickDriver = TickDriver.new()
var summary: RunSummary = null  ## set when the run ended
var reward_granted: bool = false  ## true when this run's end granted Data (false for a repeat)
var last_frame_ticks: int = 0  ## ticks the last frame ran
## Optional `func(usec: float) -> void`, called after every frame that ran ticks with the average microseconds one tick
## of that frame took (Game points it at `PerfHud.record_tick_usec` for --debug-perf).
var tick_sink: Callable = Callable()

var _view: BattleView
var _relay: GameEventRelay
var _finalized: bool = false
var _tick_usec: int = 0
var _tick_count: int = 0


func _init() -> void:
	api = SimRunApi.new()
	api.bind(self)


func start(config: SimConfig, run_id_value: String, view: BattleView) -> void:
	_release()
	run_id = run_id_value
	paused = false
	summary = null
	reward_granted = false
	_finalized = false
	_tick_usec = 0
	_tick_count = 0
	last_frame_ticks = 0
	api.bind(self)
	sim = SimWorld.new(config)
	_relay = GameEventRelay.new(config.content)
	driver = TickDriver.new()
	driver.before_tick = _before_tick
	_view = view
	if _view != null:
		_view.bind(sim)
	set_process(true)
	Events.run_started.emit(run_id, config.run_seed)
	_drain()


## Pausing is refused once the run is over. Emits `paused_changed` on a real change only.
func set_paused(value: bool) -> void:
	if value == paused or sim == null or (value and sim.is_over()):
		return
	paused = value
	paused_changed.emit(value)


## Unbinds the view, frees the sim. Safe to call twice.
func stop() -> void:
	_release()
	bot = null
	scenario = null


## Unbinds the view and drops the sim and the relay (a run that is about to start keeps its bot and scenario).
func _release() -> void:
	if _view != null and is_instance_valid(_view):
		_view.unbind()
	_view = null
	sim = null
	_relay = null
	paused = false
	set_process(false)


func _exit_tree() -> void:
	stop()


## If not paused: driver.advance; drain events -> Events; view.render(alpha).
func _process(delta: float) -> void:
	step_frame(delta)


## One frame of the run. Returns the ticks it ran. A paused run does nothing at all (the view stays as it was).
func step_frame(delta: float) -> int:
	if sim == null or paused:
		return 0
	var ran: int = 0
	if not sim.is_over():
		var t0: int = Time.get_ticks_usec()
		ran = driver.advance(sim, delta)
		var spent: int = Time.get_ticks_usec() - t0
		_tick_usec += spent
		_tick_count += ran
		if ran > 0 and tick_sink.is_valid():
			tick_sink.call(float(spent) / float(ran))
		_drain()
	last_frame_ticks = ran
	if _view != null and sim != null:
		_view.render(1.0 if sim.is_over() else driver.alpha(), delta)
	return ran


## Average sim tick time in milliseconds since the run started (PerfHud).
func avg_tick_ms() -> float:
	if _tick_count == 0:
		return 0.0
	return float(_tick_usec) / float(_tick_count) / 1000.0


# --- commands (RunApi forwards here; nothing reaches the sim while paused or after the end) ---


func submit_purchase(command_id: int, upgrade_id: StringName) -> void:
	var index: int = Ids.upgrade_index(upgrade_id)
	var reason: int = _refusal(index >= 0)
	if reason != Reason.Id.OK:
		Events.purchase_resolved.emit(command_id, false, reason)
		return
	sim.submit(SimCommand.purchase(command_id, index))


func submit_ability(command_id: int, ability_id: StringName) -> void:
	var index: int = Ids.ability_index(ability_id)
	var reason: int = _refusal(index >= 0)
	if reason != Reason.Id.OK:
		Events.ability_rejected.emit(ability_id, reason)
		return
	sim.submit(SimCommand.ability(command_id, index))


func submit_skip() -> void:
	if _refusal(true) == Reason.Id.OK:
		sim.submit(SimCommand.skip(api.next_command_id()))


## Why a command cannot be queued right now (Reason.Id.OK when it can).
func _refusal(id_known: bool) -> int:
	if paused:
		return Reason.Id.PAUSED
	if sim == null or sim.is_over():
		return Reason.Id.WRONG_STATE
	if not id_known:
		return Reason.Id.UNKNOWN_ID
	return Reason.Id.OK


# --- events ---


func _before_tick(world: SimWorld) -> void:
	if scenario != null:
		scenario.act(world)
	if bot != null:
		bot.act(world)


## Emits everything the sim has pushed, in order.
func _drain() -> void:
	if sim == null:
		return
	for e: SimEvent in sim.events.drain():
		if sim == null:
			return  # a handler stopped the run
		match e.kind:
			SimEventKind.Id.PHASE_CHANGED:
				phase_changed.emit(e.a, e.b)
			SimEventKind.Id.RUN_FINISHED:
				finalize()
			_:
				_relay.relay(e)


## Grants the reward (once), then emits `Events.run_finished`. A second call does nothing and returns the first
## outcome. Also the entry point for tests that end a run by hand.
func finalize() -> bool:
	if _finalized or sim == null:
		return reward_granted
	_finalized = true
	summary = sim.summary(run_id)
	reward_granted = GameRewards.grant(summary)
	Events.run_finished.emit(summary.result, run_id)
	return reward_granted
