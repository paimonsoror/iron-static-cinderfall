class_name EconomySystem
extends RefCounted
## Upgrade purchases. TODO(W1-C).

@warning_ignore_start("unused_parameter")

## Returns a Reason.Id; always pushes PURCHASE_RESOLVED.
static func purchase(world: SimWorld, command_id: int, upgrade_index: int) -> int:
	# TODO(W1-C)
	return Reason.Id.WRONG_STATE


static func block_reason(world: SimWorld, upgrade_index: int) -> int:
	# TODO(W1-C)
	return Reason.Id.WRONG_STATE


## -1 at max level. SimWorld.upgrade_cost already implements this; W1-C may keep the delegation.
static func cost(world: SimWorld, upgrade_index: int) -> int:
	return world.upgrade_cost(upgrade_index)
