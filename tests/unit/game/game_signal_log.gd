class_name GameSignalLog
extends RefCounted
## Test helper (W2-A): records every signal declared in the Events script, in order, with its arguments.
## `attach()` connects, `detach()` disconnects; call detach in after_test so no connection leaks into other suites.

## Each row: {"name": StringName, "args": Array}.
var rows: Array[Dictionary] = []

var _connected: Array = []  ## [StringName, Callable]


func attach() -> void:
	detach()
	var script: Script = Events.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var sig_name: StringName = info["name"]
		var arg_list: Array = info["args"]
		var cb: Callable = Callable(self, "_rec%d" % arg_list.size()).bind(sig_name)
		Events.connect(sig_name, cb)
		_connected.append([sig_name, cb])


func detach() -> void:
	for pair: Array in _connected:
		var sig_name: StringName = pair[0]
		var cb: Callable = pair[1]
		if Events.is_connected(sig_name, cb):
			Events.disconnect(sig_name, cb)
	_connected.clear()


func clear() -> void:
	rows.clear()


## Signal names in order of arrival.
func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in rows:
		var n: StringName = r["name"]
		out.append(n)
	return out


func count(sig_name: StringName) -> int:
	var n: int = 0
	for r: Dictionary in rows:
		if r["name"] == sig_name:
			n += 1
	return n


## Arguments of the first / last recorded emission of `sig_name` (empty when never emitted).
func first_args(sig_name: StringName) -> Array:
	for r: Dictionary in rows:
		if r["name"] == sig_name:
			var a: Array = r["args"]
			return a
	return []


func last_args(sig_name: StringName) -> Array:
	for i: int in range(rows.size() - 1, -1, -1):
		if rows[i]["name"] == sig_name:
			var a: Array = rows[i]["args"]
			return a
	return []


## Index of the first emission of `sig_name`, or -1.
func index_of(sig_name: StringName) -> int:
	for i: int in rows.size():
		if rows[i]["name"] == sig_name:
			return i
	return -1


## Total connections on all Events signals (leak checks).
static func events_connection_count() -> int:
	var total: int = 0
	var script: Script = Events.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var sig_name: StringName = info["name"]
		total += Events.get_signal_connection_list(sig_name).size()
	return total


func _push(sig_name: StringName, arg_list: Array) -> void:
	rows.append({"name": sig_name, "args": arg_list})


func _rec0(sig_name: StringName) -> void:
	_push(sig_name, [])


func _rec1(a: Variant, sig_name: StringName) -> void:
	_push(sig_name, [a])


func _rec2(a: Variant, b: Variant, sig_name: StringName) -> void:
	_push(sig_name, [a, b])


func _rec3(a: Variant, b: Variant, c: Variant, sig_name: StringName) -> void:
	_push(sig_name, [a, b, c])


func _rec4(a: Variant, b: Variant, c: Variant, d: Variant, sig_name: StringName) -> void:
	_push(sig_name, [a, b, c, d])


func _rec5(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, sig_name: StringName) -> void:
	_push(sig_name, [a, b, c, d, e])
