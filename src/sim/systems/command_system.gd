class_name CommandSystem
extends RefCounted
## Applies queued commands in submission order (tick step 2). Every dequeued command gets `tick` set and is appended
## to command_log, including rejected ones and duplicates, so a replay of the log reproduces events and hashes.
##
## Idempotency: a command_id seen before is answered with DUPLICATE_COMMAND and changes nothing. Ids <= 0 are not
## tracked (the contract says ids are > 0); they are processed every time. Double taps: at most one successful
## PURCHASE per upgrade per tick, a second one is answered with DUPLICATE_COMMAND too.


## Dedups command_id (DUPLICATE_COMMAND); one PURCHASE per upgrade per tick; logs applied commands with their tick.
static func apply_queued(world: SimWorld) -> void:
	if world.command_queue.is_empty():
		return
	var queue: Array[SimCommand] = world.command_queue
	world.command_queue = []
	var bought_this_tick: Dictionary[int, bool] = {}
	for cmd: SimCommand in queue:
		cmd.tick = world.tick
		world.command_log.entries.append(cmd)
		if cmd.command_id > 0:
			if world.phase_state.has_seen(cmd.command_id):
				_answer_duplicate(world, cmd)
				continue
			world.phase_state.mark_seen(cmd.command_id)
		_apply(world, cmd, bought_this_tick)


static func _apply(world: SimWorld, cmd: SimCommand, bought_this_tick: Dictionary[int, bool]) -> void:
	match cmd.kind:
		SimCommand.Kind.PURCHASE:
			if bought_this_tick.has(cmd.arg):
				_answer_duplicate(world, cmd)
				return
			if EconomySystem.purchase(world, cmd.command_id, cmd.arg) == Reason.Id.OK:
				bought_this_tick[cmd.arg] = true
		SimCommand.Kind.ABILITY:
			AbilitySystem.activate(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.SKIP_INTERMISSION:
			PhaseSystem.skip_intermission(world)
		_:
			pass


## The refusal for a repeated id or a second purchase of one upgrade in one tick. Nothing else changes.
static func _answer_duplicate(world: SimWorld, cmd: SimCommand) -> void:
	match cmd.kind:
		SimCommand.Kind.PURCHASE:
			world.events.push(SimEventKind.Id.PURCHASE_RESOLVED, cmd.command_id, Reason.Id.DUPLICATE_COMMAND, cmd.arg)
		SimCommand.Kind.ABILITY:
			world.events.push(SimEventKind.Id.ABILITY_REJECTED, cmd.arg, Reason.Id.DUPLICATE_COMMAND, cmd.command_id)
		_:
			pass
