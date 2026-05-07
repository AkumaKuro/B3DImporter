const BlitzNode := preload("res://blitz_node.gd").BlitzNode

class BlitzMeshNode extends BlitzNode:
	static var mesh: ArrayMesh
	var brush_id: int

	func to_dict() -> Dictionary:
		var d := super.to_dict()
		d["brush_id"] = brush_id
		d["mesh"] = mesh
		return d



	static func process_mesh(buffer: ByteBuffer) -> BlitzMeshNode:
		if mesh == null:
			mesh = ArrayMesh.new()

		buffer = buffer.get_sub_buffer()

		var node := BlitzMeshNode.new()

		node.brush_id = buffer.get_int()

		var mesh_array: Array
		var indices: PackedInt32Array

		while !buffer.eof_reached():
			var type: String = buffer.get_type()
			match type:
				"VRTS":
					mesh_array = process_vrts(buffer)
				"TRIS":
					process_tris(buffer, mesh_array)
				_:
					printerr("%s not implemented" % type)
					return

		node.mesh = mesh
		return node

	static func process_tris(buffer: ByteBuffer, array: Array) -> void:
		buffer = buffer.get_sub_buffer()

		var brush_id: int = buffer.get_int()
		var tris: PackedInt32Array = []
		while !buffer.eof_reached():
			var v0 := buffer.get_int()
			var v1 := buffer.get_int()
			var v2 := buffer.get_int()
			var triangle: PackedInt32Array = [
				v0, v1, v2
			]
			tris.append_array(triangle)

		array[Mesh.ARRAY_INDEX] = tris
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)


	static func process_vrts(buffer: ByteBuffer) -> Array:
		buffer = buffer.get_sub_buffer()

		var flags: int = buffer.get_int()
		var normal_present: bool = bool(flags & 0b01)
		var color_present: bool = bool(flags & 0b10)

		var tex_coord_sets: int = buffer.get_int()
		if tex_coord_sets > 1:
			printerr("Multiple UVs not supported")
		var set_size: int = buffer.get_int()
		if set_size != 2:
			printerr("Only 2D UV coordinates supported")

		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		while !buffer.eof_reached():
			var pos: Vector3 = buffer.get_vec3()
			if normal_present:
				st.set_normal(buffer.get_vec3())
			if color_present:
				st.set_color(buffer.get_color())
			st.set_uv(buffer.get_vec2())
			st.add_vertex(pos)

		var mesh_array: Array = st.commit_to_arrays()
		return mesh_array
