class_name RouteOverlay
extends Control
## The route screen (VARIETY_SPEC 11.2): 1 of 2 threats with pack, counts, modifier, elites, risk tag and reward. An
## overlay inside INTERMISSION while RunApi.awaiting() == AWAIT_ROUTE; sends pick_route. `setup` is the frozen contract.
# TODO(V2-E): the stub lists the pack names.

var _api: RunApi
var _content: ContentSet


func setup(api: RunApi, content: ContentSet) -> void:
	_api = api
	_content = content
	var lines: PackedStringArray = PackedStringArray()
	for i: int in api.route_option_count():
		var name_key: String = api.route_option(i).get("name_key", "")
		lines.append(Strings.t(name_key))
	var _col: VBoxContainer = RunOverlayStub.build(self, "route.header", lines)
