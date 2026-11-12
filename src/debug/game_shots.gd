class_name GameShots
extends Node
## The screenshot run of the REAL game (V3-I; not part of the game). It boots a second instance of the `Game` script
## inside a SubViewport of the requested size (so the HUD, the overlays and the camera fit lay out for that size, on a
## desktop whose screen is smaller than a phone's), lets the bot of `--autoplay` play one whole run, and saves a PNG of
## every moment the owner should see: each choice overlay, the two-weapon HUD in combat, a burster going off, the
## Deadfall Strike warning and impact, a crate on the field, the boss wave, the results.
##
## Why not tools/capture.ps1 on scenes/main.tscn: main.gd reads the same `--capture-scene` argument, so the main scene
## starts a capture runner of its own inside the capture and the run never ends (the old timeout). This scene is the
## process's main scene instead:
##   Godot --path . res://src/debug/game_shots.tscn -- --shots=<dir> --autoplay=balanced --seed=1 --mute
##     [--capture-size=1080x2400] [--quality=0|1|2] [--high-contrast]
## Output: "SHOT SAVED <path>" per PNG and "SHOTS DONE <n>" last; exit 0. "SHOTS FAILED ..." and exit 1 otherwise.
##
## The run is the bot's run with three exceptions made for the pictures: the bot is held while a choice is on screen
## (the sim holds its tick while it waits, so that changes nothing), the Warden is swapped to the second weapon once,
## and a Deadfall Strike is called once when it is legal. Between pictures the run is fast-forwarded.

const GAME_SCRIPT: GDScript = preload("res://src/core/game.gd")
const DT: float = 1.0 / 60.0
const FAST_TICKS: int = 8  ## sim ticks per rendered frame while nothing is about to be photographed
const CHOICE_FRAMES: int = 24  ## frames a choice overlay is left to lay out before its picture
const MAX_FRAMES: int = 40000
const STRIKE: StringName = &"deadfall_strike"
const KIND_STRIKE: int = 1  ## HazardState.K_STRIKE
const AWAIT_NAMES: Dictionary[int, String] = {
	RunApi.AWAIT_SALVAGE: "salvage", RunApi.AWAIT_DRAFT: "draft", RunApi.AWAIT_ROUTE: "route", RunApi.AWAIT_BOSS_BRIEF: "boss_brief",
}

var saved: PackedStringArray = PackedStringArray()

var _args: DebugArgs
var _viewport: SubViewport
var _game: Node
var _dir: String = ""
var _frames: int = 0
var _timers: Dictionary[String, int] = {}  ## picture name -> frames until it is taken (the run plays at 1x meanwhile)
var _counts: Dictionary[String, int] = {}  ## picture name -> pictures taken under that name
var _held_bot: PolicyBot = null
var _hold_left: int = 0
var _hold_name: String = ""
var _blast_ticks: PackedInt32Array = PackedInt32Array()
var _swapped: bool = false
var _struck: bool = false
var _busy: bool = false
var _finishing: bool = false


func _ready() -> void:
	_args = DebugArgs.from_os()
	_dir = _args.shots if _args.shots != "" else "user://shots"
	if _args.autoplay == "":
		_args.autoplay = "balanced"
	_args.mute = true
	_args.quit_after_run = false
	DirAccess.make_dir_recursive_absolute(_dir)
	Save.use_fs(MemorySaveFs.new())  # a fresh profile in memory: the screenshot run never touches the player's files
	Save.load_profile()
	_viewport = SubViewport.new()
	_viewport.size = _args.capture_size  # --capture-size=1080x2400 (default 1080x1920)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var host: Node = Node.new()
	host.name = "Main"
	_viewport.add_child(host)
	_game = GAME_SCRIPT.new()
	_game.set(&"args", _args)
	_game.set(&"content", Content.db)
	_game.set(&"results_delay_s", 0.0)
	host.add_child(_game)
	_game.call(&"boot", host)
	Events.area_blast.connect(_on_area_blast)
	Events.burster_armed.connect(_arm.bind("burster_fuse", 40).unbind(1))
	Events.event_warned.connect(_on_event_warned)
	Events.crate_dropped.connect(_arm.bind("crate_on_field", 90).unbind(2))
	Events.boss_spawned.connect(_arm.bind("boss_wave", 300).unbind(2))
	Events.chain_arc.connect(_arm.bind("arc_chain", 2).unbind(2))
	Log.info("Shots", "screenshot run size=%dx%d autoplay=%s dir=%s" % [_viewport.size.x, _viewport.size.y, _args.autoplay, _dir])


func _process(_delta: float) -> void:
	_frames += 1
	if _busy or _finishing:
		return
	var rc: RunController = _run()
	if rc == null or rc.sim == null or _frames > MAX_FRAMES:
		_fail("no run to photograph after %d frames" % _frames)
		return
	rc.set_process(false)  # this scene steps the run
	if rc.sim.is_over():
		_finish()
		return
	if _hold_left > 0:
		_hold_step(rc)
		return
	var kind: int = rc.api.awaiting()
	var pictures: int = _counts.get(AWAIT_NAMES.get(kind, ""), 0)
	if AWAIT_NAMES.has(kind) and pictures < 4 and rc.sim.command_queue.is_empty() and _held_bot == null:
		_hold_name = AWAIT_NAMES[kind]
		_hold_left = CHOICE_FRAMES
		_held_bot = rc.bot
		rc.bot = null  # the choice stays on screen: the sim waits and its tick does not move
		return
	_combat_pictures(rc)
	var ticks: int = 1 if not _timers.is_empty() else FAST_TICKS
	for _k: int in ticks:
		rc.step_frame(DT)
		if rc.sim == null or rc.sim.is_over() or rc.api.awaiting() != RunApi.AWAIT_NONE:
			break
	_run_timers()


## One frame of a held choice; the picture is taken on the last one and the bot goes back to work.
func _hold_step(rc: RunController) -> void:
	rc.step_frame(DT)
	_hold_left -= 1
	if _hold_left > 0:
		return
	var bot: PolicyBot = _held_bot
	await _save(_hold_name)
	if is_instance_valid(rc):
		rc.bot = bot
		rc.step_frame(DT)  # the bot answers; a second choice in a row is seen on the next frame
	_held_bot = null


## The pictures that need a nudge: the two-weapon HUD (and one swap to the second weapon), one Deadfall Strike.
func _combat_pictures(rc: RunController) -> void:
	var sim: SimWorld = rc.sim
	if not GameState.is_combat(sim.phase):
		return
	var wave_ticks: int = sim.tick - sim.stats.wave_start_tick[sim.wave] if sim.wave < sim.stats.wave_start_tick.size() else 0
	if sim.wave == 1 and wave_ticks == 900:
		_arm("combat_wave_1", 1)
	if sim.arsenal.slot_weapon[1] >= 0 and not _swapped and wave_ticks > 420 and sim.alive_count() >= 12:
		_swapped = true
		_arm("combat_two_weapons", 2)
		rc.api.swap_weapon(rc.api.next_command_id(), 1 - sim.arsenal.active)
		_arm("combat_second_weapon", 150)
	if not _struck and sim.wave >= 2 and sim.alive_count() >= 14 and rc.api.call_block_reason(STRIKE) == Reason.Id.OK:
		_struck = true
		rc.api.call_event(rc.api.next_command_id(), STRIKE)


func _on_event_warned(id: StringName, _ticks: int, _x: float, _z: float) -> void:
	if id == STRIKE:
		_arm("strike_warning", 30)


func _on_area_blast(kind: int, _x: float, _z: float, _radius: float) -> void:
	var rc: RunController = _run()
	if rc == null or rc.sim == null:
		return
	if kind == KIND_STRIKE:
		_arm("strike_impact", 3)
		return
	_blast_ticks.append(rc.sim.tick)
	var recent: int = 0
	for t: int in _blast_ticks:
		if rc.sim.tick - t <= 40:
			recent += 1
	_arm("blast_chain" if recent >= 2 else "blast", 4)


## Asks for the picture `shot` in `frames` frames (the first three of a name are kept; a pending one is not restarted).
func _arm(shot: String, frames: int) -> void:
	var taken: int = _counts.get(shot, 0)
	if taken < 3 and not _timers.has(shot):
		_timers[shot] = maxi(frames, 1)


func _run_timers() -> void:
	var due: PackedStringArray = PackedStringArray()
	for shot: String in _timers:
		_timers[shot] -= 1
		if _timers[shot] <= 0:
			due.append(shot)
	for shot: String in due:
		_timers.erase(shot)
	if not due.is_empty():
		_save_all(due)


func _save_all(names: PackedStringArray) -> void:
	for shot: String in names:
		await _save(shot)


func _finish() -> void:
	_finishing = true
	for _n: int in 100:  # the results screen counts the reward up
		await get_tree().process_frame
	await _save("results")
	print("SHOTS DONE %d" % saved.size())
	get_tree().quit(0)


## Saves the SubViewport as <dir>/<name>_<n>.png after the frame is drawn.
func _save(shot: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var taken: int = _counts.get(shot, 0)
	_counts[shot] = taken + 1
	var path: String = "%s/%s_%d.png" % [_dir, shot, taken + 1]
	var img: Image = _viewport.get_texture().get_image()
	if img == null or img.is_empty() or img.save_png(path) != OK:
		_busy = false
		_fail("cannot save %s" % path)
		return
	saved.append(path)
	print("SHOT SAVED %s tick=%d" % [path, _run().sim.tick if _run() != null and _run().sim != null else -1])
	_busy = false


func _run() -> RunController:
	var o: Object = _game.get(&"run") if is_instance_valid(_game) else null
	return o as RunController


func _fail(text: String) -> void:
	_finishing = true
	print("SHOTS FAILED %s" % text)
	get_tree().quit(1)
