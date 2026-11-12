class_name DraftSystem
extends RefCounted
## Directive offers and the draft commands (VARIETY_SPEC 4.3, 4.4; CONTENT 3.7). The only writer of DraftState.
## Every command function returns a Reason.Id and pushes its event (DIRECTIVE_PICKED, DRAFT_REROLLED, or
## COMMAND_REJECTED with the reason). Offers draw from the stream `draft:<offer_ordinal>` in the order of 4.3.
# TODO(V2-B): the stub refuses every command with NOT_AWAITING and draws from no stream.


## Opens a draft at wave clear: generates the offer, pushes DRAFT_OFFERED. Called by PhaseSystem.
static func open(_world: SimWorld) -> void:
	pass


## The offer for the current state (steps 1 to 4 of 4.3), directive indices per slot.
static func generate_offer(_world: SimWorld) -> PackedInt32Array:
	return PackedInt32Array()


static func pick(_world: SimWorld, _command_id: int, _slot: int) -> int:
	return Reason.Id.NOT_AWAITING


static func skip(_world: SimWorld, _command_id: int) -> int:
	return Reason.Id.NOT_AWAITING


static func reroll(_world: SimWorld, _command_id: int) -> int:
	return Reason.Id.NOT_AWAITING


static func buy_out(_world: SimWorld, _command_id: int, _slot: int) -> int:
	return Reason.Id.NOT_AWAITING


static func patch_core(_world: SimWorld, _command_id: int) -> int:
	return Reason.Id.NOT_AWAITING


## Scrap price of the next reroll (0 while a free charge is left).
static func reroll_cost(_world: SimWorld) -> int:
	return 0


static func buyout_cost(_world: SimWorld) -> int:
	return 0


static func patch_cost(_world: SimWorld) -> int:
	return 0


## Tag name -> stacks held with that tag (the build chips of the HUD).
static func build_tags(_world: SimWorld) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	return out
