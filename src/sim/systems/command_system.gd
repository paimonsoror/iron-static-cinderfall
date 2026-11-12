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
	# A resolved salvage emptied its offer but cannot release its own await: move the intermission on (idempotent).
	PhaseSystem.advance_await(world)


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
			_apply_variety(world, cmd)


## The commands of the variety milestone (VARIETY_SPEC 13.2). Each goes to the system that owns it and returns a
## Reason.Id; a refusal is answered here, once, with COMMAND_REJECTED(command id, reason). The five draft commands
## (PICK_DIRECTIVE, SKIP_DRAFT, REROLL, BUY_OUT, PATCH_CORE) are legal only while a draft is open and awaited: DraftSystem
## answers NOT_AWAITING otherwise, INVALID_CHOICE for a slot that is not offered, INSUFFICIENT_SCRAP for a price.
static func _apply_variety(world: SimWorld, cmd: SimCommand) -> void:
	var reason: int = Reason.Id.UNKNOWN_ID
	match cmd.kind:
		SimCommand.Kind.PICK_DIRECTIVE:
			reason = DraftSystem.pick(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.SKIP_DRAFT:
			reason = DraftSystem.skip(world, cmd.command_id)
		SimCommand.Kind.REROLL:
			reason = DraftSystem.reroll(world, cmd.command_id)
		SimCommand.Kind.BUY_OUT:
			reason = DraftSystem.buy_out(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.PATCH_CORE:
			reason = DraftSystem.patch_core(world, cmd.command_id)
		SimCommand.Kind.PICK_ROUTE:
			reason = PhaseSystem.pick_route(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.SALVAGE:
			reason = SalvageSystem.resolve(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.SWAP_WEAPON:
			reason = ArsenalSystem.swap(world, cmd.command_id, cmd.arg)
		SimCommand.Kind.CALL_EVENT:
			reason = EventSystem.call_event(world, cmd.command_id, cmd.arg)
	if reason != Reason.Id.OK:
		world.events.push(SimEventKind.Id.COMMAND_REJECTED, cmd.command_id, reason)


## The refusal for a repeated id or a second purchase of one upgrade in one tick. Nothing else changes.
static func _answer_duplicate(world: SimWorld, cmd: SimCommand) -> void:
	match cmd.kind:
		SimCommand.Kind.PURCHASE:
			world.events.push(SimEventKind.Id.PURCHASE_RESOLVED, cmd.command_id, Reason.Id.DUPLICATE_COMMAND, cmd.arg)
		SimCommand.Kind.ABILITY:
			world.events.push(SimEventKind.Id.ABILITY_REJECTED, cmd.arg, Reason.Id.DUPLICATE_COMMAND, cmd.command_id)
		SimCommand.Kind.SKIP_INTERMISSION:
			pass
		_:
			world.events.push(SimEventKind.Id.COMMAND_REJECTED, cmd.command_id, Reason.Id.DUPLICATE_COMMAND)
