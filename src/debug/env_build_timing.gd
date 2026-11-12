extends SceneTree
## One-time build cost of the styled yard (W3-E), in milliseconds: the floor tile, the floor material, the prop and decor meshes, the
## reactor detail and the whole `EnvDress` first apply. Headless, no rendering:
##   Godot --headless --path <project> --script res://src/debug/env_build_timing.gd
## Prints `ENVBUILD name=ms ...` lines; the numbers belong in the boot budget (ARCH 13: cold start to menu 3 s).


func _init() -> void:
	var content: ContentSet = ContentLoader.load_from_dir("res://data").content
	MatLib.configure(content.tokens)
	var arena: ArenaDef = content.arena
	var t0: int = Time.get_ticks_usec()
	var tex: Image = EnvTex.image()
	var t1: int = Time.get_ticks_usec()
	var props: MeshBuilder = MeshKit.begin()
	for ob: ObstacleDef in arena.obstacles:
		EnvProps.add_obstacle(props, ob)
	var props_mesh: ArrayMesh = EnvShapes.finish(props)
	var t2: int = Time.get_ticks_usec()
	var body: MeshBuilder = MeshKit.begin()
	var heads: MeshBuilder = MeshKit.begin()
	EnvDecor.build(arena, body, heads)
	var decor_mesh: ArrayMesh = EnvShapes.finish(body)
	var t3: int = Time.get_ticks_usec()
	var reactor: ArrayMesh = EnvReactor.mesh()
	var t4: int = Time.get_ticks_usec()
	LookDevStyle.set_current(LookDevStyle.Look.STYLISED)
	var view: ArenaView = ArenaView.new()
	view.setup(arena, content.tokens)
	var t5: int = Time.get_ticks_usec()
	print("ENVBUILD tile=%.1f props=%.1f decor=%.1f reactor=%.1f arena_setup_styled=%.1f tris(props)=%d tris(decor)=%d tile_px=%d reactor_surfaces=%d" % [
		_ms(t0, t1), _ms(t1, t2), _ms(t2, t3), _ms(t3, t4), _ms(t4, t5), _tris(props_mesh), _tris(decor_mesh), tex.get_width(), reactor.get_surface_count()
	])
	view.free()
	quit(0)


func _ms(a: int, b: int) -> float:
	return float(b - a) / 1000.0


func _tris(mesh: ArrayMesh) -> int:
	var n: int = 0
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += floori(float(idx.size()) / 3.0)
	return n
