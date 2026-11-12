class_name Reason
extends RefCounted
## Command outcomes (ARCH 4). Append only (VARIETY_SPEC 13.2): the first LEGACY_COUNT values are the original ones.

enum Id {
	OK,
	WRONG_STATE,
	UNKNOWN_ID,
	MAX_LEVEL,
	INSUFFICIENT_SCRAP,
	PREREQ_NOT_MET,
	DUPLICATE_COMMAND,
	ON_COOLDOWN,
	ALREADY_ACTIVE,
	PAUSED,
	NOT_AWAITING,
	INVALID_CHOICE,
	NO_CHARGES,
	LOCKED_BY_EVENT,
	SHOP_CLOSED,
}

const KEYS: PackedStringArray = [
	"reason.ok",
	"reason.wrong_state",
	"reason.unknown_id",
	"reason.max_level",
	"reason.insufficient_scrap",
	"reason.prereq_not_met",
	"reason.duplicate_command",
	"reason.on_cooldown",
	"reason.already_active",
	"reason.paused",
	"reason.not_awaiting",
	"reason.invalid_choice",
	"reason.no_charges",
	"reason.locked_by_event",
	"reason.shop_closed",
]

## The reasons that existed before the variety milestone (their strings are in every string table, the legacy one too).
const LEGACY_COUNT := 10


## String-table key for a reason, e.g. "reason.insufficient_scrap".
static func string_key(id: int) -> String:
	if id < 0 or id >= KEYS.size():
		return "reason.unknown_id"
	return KEYS[id]
