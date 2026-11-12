class_name RunFileWriter
extends RefCounted
## Keeps the run file of one live run current (VARIETY_SPEC 2.8). RunController calls it; it decides when to write:
##
##  1. `begin` (the start of the run) and every wave clear: a new boundary snapshot, its `state_hash`, an empty tail.
##     The wave clear is seen before the next tick runs (`before_tick`) or at the end of the frame, so the snapshot is
##     the state of exactly the tick that cleared the wave.
##  2. after a command outside combat (the draft, route and salvage choices, a purchase in the intermission): the tail
##     grows. Commands given during a wave are not written one by one (no disk work in a combat frame);
##  3. `on_pause` (the pause button, the back gesture, the app going to the background): the tail including the
##     running wave's commands, and `resume_tick`.
##
## The file is deleted when the run ends (`finish`). A failed write is logged and the previous file stays; the next
## occasion writes again.

var writes: int = 0  ## successful writes
var failed_writes: int = 0
var boundaries: int = 0  ## snapshots taken

var _head: Dictionary = {}
var _boundary: Dictionary = {}
var _waves: int = -1  ## waves_completed at the boundary held
var _logged: int = 0  ## command log size at the last write
var _last_key: String = ""  ## what the last successful write held (a repeat is skipped)
var _open: bool = false


## A fresh run: the snapshot of the start (wave 0) and the first file.
func begin(world: SimWorld, run_id: String) -> void:
	_head = RunFile.header(world.config, run_id)
	_open = true
	_take_boundary(world)


## A resumed run: `doc` is the file it was rebuilt from, so its header and boundary are kept as they are.
func adopt(doc: Dictionary, world: SimWorld) -> void:
	_head = {}
	for key: Variant in doc:
		if key != "boundary" and key != "log" and key != "tail" and key != "resume_tick":
			_head[key] = doc[key]
	_boundary = RunFile.boundary_of(doc)
	_waves = RunFile.waves_cleared(doc)
	_logged = world.command_log.entries.size()
	_open = true
	check_boundary(world)


## Called before every tick and after every frame: takes the snapshot of a wave clear.
func check_boundary(world: SimWorld) -> void:
	if _open and world.waves_completed != _waves and not world.is_over():
		_take_boundary(world)


## Called after the ticks of a frame.
func after_frame(world: SimWorld) -> void:
	if not _open or world.is_over():
		return
	check_boundary(world)
	if world.command_log.entries.size() != _logged and not GameState.is_combat(world.phase):
		write(world, -1)


## The run was paused or the app left the foreground.
func on_pause(world: SimWorld) -> bool:
	return write(world, world.tick)


## Writes the file now. `resume_tick` < 0 = without one. False when nothing was written.
func write(world: SimWorld, resume_tick: int) -> bool:
	if not _open or world == null or world.is_over() or _boundary.is_empty():
		return false
	var count: int = world.command_log.entries.size()
	var key: String = "%d|%d|%d" % [RunFile.whole(_boundary.get("tick"), 0), count, resume_tick]
	if key == _last_key:
		return true
	_logged = count
	if not Save.save_run(RunFile.compose(_head, _boundary, world.command_log.to_dicts(), resume_tick)):
		failed_writes += 1
		Log.warn("RunFile", "run file not written at tick %d; the previous one stays" % world.tick)
		return false
	_last_key = key
	writes += 1
	return true


## The run ended (finished or abandoned): the file goes.
func finish() -> void:
	if _open:
		_open = false
		Save.clear_run()


func _take_boundary(world: SimWorld) -> void:
	_waves = world.waves_completed
	_boundary = RunFile.boundary(world)
	boundaries += 1
	write(world, -1)
