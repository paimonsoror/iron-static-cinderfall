class_name DraftOverlay
extends Control
## The draft screen (VARIETY_SPEC 11.1): 1 of 3 directives, reroll, patch, skip, buy-out, two-tap confirm. An overlay
## inside INTERMISSION while RunApi.awaiting() == AWAIT_DRAFT; it reads the offer from the RunApi and sends
## pick_directive, skip_draft, reroll_draft, buy_out and patch_core. `setup` is the frozen contract.
# TODO(V2-E): the stub lists the offered directive names.

var _api: RunApi
var _content: ContentSet


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	var lines: PackedStringArray = PackedStringArray()
	for index: int in api.draft_offer():
		if index >= 0 and index < content.directives.size():
			lines.append(Strings.t(content.directives[index].name_key))
	var _col: VBoxContainer = RunOverlayStub.build(self, "draft.header", lines)
