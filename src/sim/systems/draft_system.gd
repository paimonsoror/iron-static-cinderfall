class_name DraftSystem
extends RefCounted
## Directive offers and the draft commands (VARIETY_SPEC 4.3, 4.4; CONTENT 3.7). The only writer of DraftState.
## Each command function returns a Reason.Id and pushes its own success events (DIRECTIVE_PICKED, DRAFT_REROLLED); a
## refusal is answered once by CommandSystem with COMMAND_REJECTED. The offer itself is rolled by DraftOffer from the
## stream `draft:<n>` (n = the 0-based ordinal of the offer in the run); a reroll goes on with the same stream.
##
## Buy-out takes the bought slot at once (the slot becomes -1, DIRECTIVE_PICKED is pushed) and the draft stays open for
## the pick. The draft closes when its last pick is made, when nothing is left to pick, or on a skip; it then releases
## the DRAFT await (AWAIT_CHANGED) so that PhaseSystem goes on to the next step of the intermission in the same tick.

const NO_BREATHER_FLAG: StringName = &"no_breather"


## Opens a draft at wave clear: generates the offer, pushes DRAFT_OFFERED(ordinal, slots). Called by PhaseSystem, which
## sets the DRAFT await itself. A world without a run definition (the legacy content) has no drafts.
static func open(world: SimWorld) -> void:
	if world.content.run == null:
		return
	var d: DraftState = world.draft
	var ordinal: int = d.offer_ordinal
	d.open = true
	d.bought_out = false
	d.picks_left = 2 if d.next_double else 1
	d.next_double = false
	d.reroll_locked = breather_denied(world)
	d.offer_ordinal = ordinal + 1
	d.offer = generate_offer(world)
	d.next_rare = false
	_note_offer(world, d.offer)
	world.events.push(SimEventKind.Id.DRAFT_OFFERED, ordinal, d.offer.size())


## The offer for the current state (steps 1 to 4 of 4.3), directive indices per slot. It draws from the stream of the
## offer that is open (`draft:<offer_ordinal - 1>`) and changes no field of the DraftState.
static func generate_offer(world: SimWorld) -> PackedInt32Array:
	if world.content.run == null:
		return PackedInt32Array()
	var n: int = maxi(0, world.draft.offer_ordinal - 1)
	var rng: RandomNumberGenerator = world.rng.stream(StringName("draft:%d" % n))
	return DraftOffer.roll(world, rng, world.draft.next_rare)


## PICK_DIRECTIVE: takes the directive of `slot`. The draft closes after its last pick (two with rw_double_pick).
static func pick(world: SimWorld, _command_id: int, slot: int) -> int:
	if not _is_open(world):
		return Reason.Id.NOT_AWAITING
	var d: DraftState = world.draft
	if slot < 0 or slot >= d.offer.size() or d.offer[slot] < 0:
		return Reason.Id.INVALID_CHOICE
	_take(world, slot)
	d.picks_left -= 1
	if d.picks_left <= 0 or d.slots_left() == 0:
		_close(world)
	return Reason.Id.OK


## SKIP_DRAFT: closes the draft. +skip_scrap Scrap when nothing was taken in it (no pay after a buy-out or a first pick).
static func skip(world: SimWorld, _command_id: int) -> int:
	if not _is_open(world):
		return Reason.Id.NOT_AWAITING
	if world.draft.taken_count() == 0:
		world.add_scrap(world.content.run.draft_skip_scrap)
	_close(world)
	return Reason.Id.OK


## REROLL: a free charge first, else Scrap. Redraws every slot. Refused after a directive was taken in this draft.
static func reroll(world: SimWorld, _command_id: int) -> int:
	if not _is_open(world):
		return Reason.Id.NOT_AWAITING
	var d: DraftState = world.draft
	if d.reroll_locked:
		return Reason.Id.LOCKED_BY_EVENT
	if d.taken_count() > 0:
		return Reason.Id.INVALID_CHOICE
	var paid: int = 0
	if d.free_rerolls > 0:
		d.free_rerolls -= 1
	else:
		paid = reroll_cost(world)
		if world.scrap < paid:
			return Reason.Id.INSUFFICIENT_SCRAP
		world.add_scrap(-paid)
		d.rerolls_paid += 1
	d.offer = generate_offer(world)
	_note_offer(world, d.offer)
	world.events.push(SimEventKind.Id.DRAFT_REROLLED, d.offer_ordinal - 1, paid)
	return Reason.Id.OK


## BUY_OUT: also take the directive of `slot` for Scrap (once per draft); the pick of another slot follows.
static func buy_out(world: SimWorld, _command_id: int, slot: int) -> int:
	if not _is_open(world):
		return Reason.Id.NOT_AWAITING
	var d: DraftState = world.draft
	if slot < 0 or slot >= d.offer.size() or d.offer[slot] < 0 or d.bought_out or d.slots_left() < 2:
		return Reason.Id.INVALID_CHOICE
	var cost: int = buyout_cost(world)
	if world.scrap < cost:
		return Reason.Id.INSUFFICIENT_SCRAP
	world.add_scrap(-cost)
	d.buyouts += 1
	d.bought_out = true
	_take(world, slot)
	return Reason.Id.OK


## PATCH_CORE: repairs patch_frac of the core maximum for Scrap; the price grows with every use this run.
static func patch_core(world: SimWorld, _command_id: int) -> int:
	if not _is_open(world):
		return Reason.Id.NOT_AWAITING
	var d: DraftState = world.draft
	if d.reroll_locked:
		return Reason.Id.LOCKED_BY_EVENT
	if world.core_hp >= world.core_max_hp:
		return Reason.Id.INVALID_CHOICE
	var cost: int = patch_cost(world)
	if world.scrap < cost:
		return Reason.Id.INSUFFICIENT_SCRAP
	world.add_scrap(-cost)
	d.patches += 1
	ModSystem.repair_core(world, world.content.run.patch_frac * world.core_max_hp)
	return Reason.Id.OK


## Scrap price of the next reroll (0 while a free charge is left): reroll_base + reroll_step * paid rerolls, times the
## reroll_cost_mul of the build.
static func reroll_cost(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null or world.draft.free_rerolls > 0:
		return 0
	var base: int = run.reroll_base + run.reroll_step * world.draft.rerolls_paid
	return maxi(0, roundi(float(base) * world.mods.reroll_cost_mul))


static func buyout_cost(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null:
		return 0
	return run.buyout_base + run.buyout_step * world.draft.buyouts


static func patch_cost(world: SimWorld) -> int:
	var run: RunDef = world.content.run
	if run == null:
		return 0
	return run.patch_base + run.patch_step * world.draft.patches


## Tag name -> stacks held with that tag (the build chips of the HUD), in directive order.
static func build_tags(world: SimWorld) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for def: DirectiveDef in world.content.directives:
		var held: int = mini(world.draft.stacks_of(def.index), def.max_stacks)  # HookMemory counts are not stacks
		if held <= 0:
			continue
		for tag: StringName in def.tags:
			var before: int = out.get(tag, 0)
			out[tag] = before + held
	return out


## Adds one stack of a directive outside a pick (a kit, a reward): stacks, DIRECTIVE_PICKED, the ops of the directive.
## False when the directive is unknown or already at its maximum.
static func grant_stack(world: SimWorld, directive_index: int) -> bool:
	if directive_index < 0 or directive_index >= world.content.directives.size():
		return false
	if world.draft.stacks_of(directive_index) >= world.content.directives[directive_index].max_stacks:
		return false
	_add_stack(world, directive_index)
	return true


## +n free reroll charges (route reward rw_reroll, a directive, a kit).
static func add_free_rerolls(world: SimWorld, n: int) -> void:
	world.draft.free_rerolls = maxi(0, world.draft.free_rerolls + n)


## rw_rare_draft: slot 1 of the next draft is rare or better.
static func arm_next_rare(world: SimWorld) -> void:
	world.draft.next_rare = true


## rw_double_pick: the next draft keeps two of its offer.
static func arm_next_double(world: SimWorld) -> void:
	world.draft.next_double = true


static func _is_open(world: SimWorld) -> bool:
	return (
		world.content.run != null
		and world.phase_state.awaiting == PhaseState.Await.DRAFT
		and world.draft.open
	)


## Takes the directive of `slot` (slot becomes -1) and applies it.
static func _take(world: SimWorld, slot: int) -> void:
	var index: int = world.draft.offer[slot]
	world.draft.offer[slot] = -1
	_add_stack(world, index)


static func _add_stack(world: SimWorld, directive_index: int) -> void:
	var d: DraftState = world.draft
	var def: DirectiveDef = world.content.directives[directive_index]
	d.stacks[directive_index] += 1
	world.events.push(SimEventKind.Id.DIRECTIVE_PICKED, directive_index, d.stacks[directive_index])
	ModSystem.on_directive_added(world, def)
	if def.hook == ModSystem.HOOK_PLAN_PATCH:
		RunPlanSystem.patch(world, directive_index)


## The draft is over: what was offered and not taken feeds the repeat penalty of the next one; the DRAFT await ends.
static func _close(world: SimWorld) -> void:
	var d: DraftState = world.draft
	var left: PackedInt32Array = PackedInt32Array()
	for index: int in d.offer:
		if index >= 0:
			left.append(index)
	d.last_offer = left
	d.offer = PackedInt32Array()
	d.open = false
	d.picks_left = 0
	d.reroll_locked = false
	if world.phase_state.awaiting == PhaseState.Await.DRAFT:
		world.phase_state.awaiting = PhaseState.Await.NONE
		world.events.push(SimEventKind.Id.AWAIT_CHANGED, PhaseState.Await.NONE, PhaseState.Await.DRAFT)


## Pity bookkeeping for an offer that was just made (the first one or a reroll).
static func _note_offer(world: SimWorld, offer: PackedInt32Array) -> void:
	var d: DraftState = world.draft
	var rare: bool = false
	var turret_index: int = world.content.directive_index(DraftOffer.TURRET_PITY_ID)
	for index: int in offer:
		var rarity: int = world.content.directives[index].rarity
		if rarity == DirectiveDef.Rarity.RARE or rarity == DirectiveDef.Rarity.PROTOTYPE:
			rare = true
		if index == turret_index:
			d.turret_offered = true
	d.offers_without_rare = 0 if rare else d.offers_without_rare + 1


## mod_no_breather: the wave that was just cleared carried it (the flag of the build, or the modifier of its route).
static func breather_denied(world: SimWorld) -> bool:
	if world.mods.has_flag(NO_BREATHER_FLAG):
		return true
	var run: RunDef = world.content.run
	if world.plan == null:
		return false
	var option: RouteOption = world.plan.option(world.wave)
	if option == null or option.modifier_index < 0 or option.modifier_index >= run.modifiers.size():
		return false
	for op: OpDef in run.modifiers[option.modifier_index].ops:
		if op.kind == OpDef.Kind.FLAG and op.target == NO_BREATHER_FLAG:
			return true
	return false
