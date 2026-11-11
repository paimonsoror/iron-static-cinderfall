class_name MeshKit
extends RefCounted
## Entry point for building merged meshes: `MeshKit.begin().box(...).cylinder(...).build()`.


static func begin() -> MeshBuilder:
	return MeshBuilder.new()
