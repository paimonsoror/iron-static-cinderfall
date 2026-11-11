class_name Replay
extends RefCounted
## Re-runs a command log. TODO(W2-D).

@warning_ignore_start("unused_parameter")

## Re-submits each logged command at its tick and steps to `max_ticks` or the end of the run.
static func run(config: SimConfig, log: CommandLog, max_ticks: int) -> SimWorld:
	# TODO(W2-D)
	return SimWorld.new(config)
