class_name SalvageOverlay
extends Control
## The salvage screen (VARIETY_SPEC 11.3): the recovered weapon against the carried ones; take in a slot, level up or
## scrap. An overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_SALVAGE; sends resolve_salvage. `setup` is
## the frozen contract.
# TODO(V2-E): the stub lists the recovered weapon names.

var _api: RunApi
var _content: ContentSet


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	var lines: PackedStringArray = PackedStringArray()
	var weapons: Array = api.salvage_offer().get("weapons", [])
	for id: Variant in weapons:
		lines.append(Strings.t("weapon.%s.name" % str(id)))
	var _col: VBoxContainer = RunOverlayStub.build(self, "salvage.header", lines)
