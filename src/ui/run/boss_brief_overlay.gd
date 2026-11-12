class_name BossBriefOverlay
extends Control
## The boss briefing (VARIETY_SPEC 11.2): one wide card with the boss name, ATTACK and ANSWER lines and CONTINUE. An
## overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_BOSS_BRIEF; sends continue_run. `setup` is the frozen
## contract.
# TODO(V2-E): the stub shows the boss name.

var _api: RunApi
var _content: ContentSet


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	var lines: PackedStringArray = PackedStringArray()
	var name_key: String = api.boss_brief().get("name_key", "")
	if name_key != "":
		lines.append(Strings.t(name_key))
	var _col: VBoxContainer = RunOverlayStub.build(self, "route.header", lines)
