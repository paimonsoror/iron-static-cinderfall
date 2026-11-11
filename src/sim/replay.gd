class_name Replay
extends RefCounted
## Re-runs a command log on a fresh world (ARCH 6.7). The log is the whole external input of a run, so the same
## config plus the same log gives the same state_hash() and event_hash (ARCH 6.1).


## Re-submits each logged command at its tick (a command logged at tick T was applied by step T, so it is submitted
## before that step) and steps until `max_ticks` or the end of the run. The log's own commands are copied, never
## mutated. Events are drained every tick (nobody reads them here); `events.event_hash` and `events.total` still
## cover every event, so replays compare by hash.
static func run(config: SimConfig, log: CommandLog, max_ticks: int) -> SimWorld:
	var world: SimWorld = SimWorld.new(config)
	var next_entry: int = 0
	var rows: Array[SimCommand] = _sorted_by_tick(log.entries)
	while not world.is_over() and world.tick < max_ticks:
		var due: int = world.tick + 1
		while next_entry < rows.size() and rows[next_entry].tick <= due:
			world.submit(_copy(rows[next_entry]))
			next_entry += 1
		world.step()
		world.events.drain()
	return world


static func _copy(c: SimCommand) -> SimCommand:
	var out: SimCommand = SimCommand.new()
	out.command_id = c.command_id
	out.kind = c.kind
	out.arg = c.arg
	return out


## Stable insertion sort by tick, so a log that was merged out of order still replays in submission order.
static func _sorted_by_tick(entries: Array[SimCommand]) -> Array[SimCommand]:
	var out: Array[SimCommand] = []
	for c: SimCommand in entries:
		out.append(c)
	for a: int in range(1, out.size()):
		var moving: SimCommand = out[a]
		var b: int = a - 1
		while b >= 0 and out[b].tick > moving.tick:
			out[b + 1] = out[b]
			b -= 1
		out[b + 1] = moving
	return out
