class_name RunController
extends Node
## Owns one run: ticks the sim, drains its events into Events in order, renders the view (ARCH 7.3). It is the only
## emitter of the gameplay signals. When the sim pushes RUN_FINISHED it grants the Recovered Data (GameRewards) and
## only then emits `Events.run_finished`; no UI code grants. The sim does not know about pausing: a paused run is
## simply not stepped, so its state hash and every cooldown stay exactly as they were.
##
## Variety milestone (VARIETY_SPEC 2.8, 13.4): the controller keeps the run file current through `files` (a snapshot at
## the start and at every wave clear, the command tail after a choice, `resume_tick` on a pause), deletes it when the
## run ends, and `start_resumed` continues a run from that file. The stepping is unchanged: the sim holds its own
## tick while it waits for a choice.

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
## Keeps the run file; null when this run writes none (`write_run_file` off, or a debug scenario, whose spawns are not
## commands and so cannot be replayed).
var files: RunFileWriter = null
var write_run_file: bool = true
## RunResume.Mode of the run `start_resumed` continued (FAILED when it could not); -1 for a run that started fresh.
var resume_mode: int = -1

## The controller whose run is live (MobileShell writes its run file when the app is paused).
static var active: RunController = null

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
	resume_mode = -1
	_adopt(SimWorld.new(config), run_id_value, view)
	if write_run_file and scenario == null:
		files = RunFileWriter.new()
		files.begin(sim, run_id)
	Events.run_started.emit(run_id, config.run_seed)
	_drain()


## Continues the run of a run file (`Save.load_run()`): rebuilds its world (RunResume: snapshot plus tail, else a full
## replay) and goes on from there, not paused (Game pauses it and shows the pause overlay). When the run cannot be
## rebuilt it is closed (paid once as a defeat at the last saved wave, the file deleted) and `sim` stays null.
## `content` defaults to `Content.db`; `prepared` is the result of a rebuild the caller has already done.
func start_resumed(doc: Dictionary, view: BattleView, content: ContentSet = null, prepared: RunResumeResult = null) -> void:
	_release()
	var set_used: ContentSet = content if content != null else Content.db
	var r: RunResumeResult = prepared if prepared != null else RunResume.rebuild(doc, set_used)
	resume_mode = r.mode
	if not r.ok():
		Log.warn("RunController", "run %s cannot be resumed: %s" % [r.run_id, r.reason])
		RunResume.close(doc, set_used)
		return
	Log.info("RunController", "run %s resumed at tick %d mode=%s" % [r.run_id, r.world.tick, RunResume.Mode.keys()[r.mode]])
	_adopt(r.world, r.run_id, view)
	if write_run_file and scenario == null:
		files = RunFileWriter.new()
		files.adopt(doc, sim)
	Events.run_started.emit(run_id, sim.config.run_seed)
	if sim.is_over():
		finalize()  # the file was written before the end and the process died before it was deleted


## Takes `world` as the run: the relay, the driver, the view. For a resumed world the command id counter moves past
## every id the run has seen, and the relay learns the enemies that are already alive, so their deaths carry a type.
func _adopt(world: SimWorld, run_id_value: String, view: BattleView) -> void:
	run_id = run_id_value
	paused = false
	summary = null
	reward_granted = false
	_finalized = false
	_tick_usec = 0
	_tick_count = 0
	last_frame_ticks = 0
	api.bind(self)
	sim = world
	_relay = GameEventRelay.new(world.content)
	_relay.world = sim
	for seen_id: int in sim.phase_state.seen_command_ids:
		api._next_command_id = maxi(api._next_command_id, seen_id)  # a resumed run never mints an id it used before
	for i: int in sim.enemies.high_water:
		if sim.enemies.alive[i] == 1:
			var e: SimEvent = SimEvent.new()
			e.kind = SimEventKind.Id.ENEMY_SPAWNED
			e.tick = sim.tick
			e.a = sim.enemies.id[i]
			e.b = sim.enemies.type[i]
			e.f = sim.enemies.x[i]
			e.g = sim.enemies.z[i]
			_relay.relay(e)
	driver = TickDriver.new()
	driver.before_tick = _before_tick
	_view = view
	if _view != null:
		_view.bind(sim)
	active = self
	set_process(true)


## Pausing is refused once the run is over. Emits `paused_changed` on a real change only.
func set_paused(value: bool) -> void:
	if value == paused or sim == null or (value and sim.is_over()):
		return
	paused = value
	if value and files != null:
		files.on_pause(sim)
	paused_changed.emit(value)


## Unbinds the view, frees the sim. Safe to call twice. The run file stays (the process may be going down; a run that
## is given up on purpose ends with `abandon`).
func stop() -> void:
	_release()
	bot = null
	scenario = null


## The player gave the run up (restart, quit to the menu): its run file is deleted, then `stop`.
func abandon() -> void:
	if files != null:
		files.finish()
	stop()


## Writes the run file of the live run with `resume_tick` (the app is leaving the foreground). False when no run file
## was written.
static func save_active_on_pause() -> bool:
	if not is_instance_valid(active) or active.sim == null or active.files == null:
		return false
	return active.files.on_pause(active.sim)


## Unbinds the view and drops the sim and the relay (a run that is about to start keeps its bot and scenario).
func _release() -> void:
	if _view != null and is_instance_valid(_view):
		_view.unbind()
	_view = null
	sim = null
	_relay = null
	files = null
	paused = false
	if active == self:
		active = null
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
		if files != null and sim != null:
			files.after_frame(sim)
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


## The commands of the variety milestone (SimCommand.Kind from PICK_DIRECTIVE on). `arg` < 0 is an id the caller
## could not resolve. A refusal here (paused, run over, unknown id) is answered with `Events.command_rejected`, as the
## sim answers its own refusals.
func submit_variety(command_id: int, kind: int, arg: int) -> void:
	var reason: int = _refusal(arg >= 0)
	if reason != Reason.Id.OK:
		Events.command_rejected.emit(command_id, reason)
		return
	var cmd: SimCommand = SimCommand.new()
	cmd.command_id = command_id
	cmd.kind = kind
	cmd.arg = arg
	sim.submit(cmd)


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
	if files != null:
		files.check_boundary(world)
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
	if files != null:
		files.finish()
	Events.run_finished.emit(summary.result, run_id)
	return reward_granted
