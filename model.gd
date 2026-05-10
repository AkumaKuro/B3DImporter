extends Node3D

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

var has_bones: bool

func process_model(buffer: ByteBuffer) -> void:
	var type := buffer.get_type()
	if type != "BB3D": printerr("Wrong magic")
	buffer = buffer.get_sub_buffer()
	var version := buffer.get_int()
	if version != 1: printerr("Unrecognized version")

	while !buffer.eof_reached():
		type = buffer.get_type()
		match type:
			"TEXS":
				buffer.get_sub_buffer()
			"BRUS":
				buffer.get_sub_buffer()
			"NODE":
				process_node(buffer.get_sub_buffer())
			_:
				printerr("Weird type: %s" % type)

func process_node(buffer: ByteBuffer) -> void:
	var node_name := buffer.get_string()
	var tform := buffer.get_tform()

	var node_type := buffer.get_type()

	match node_type:
		"MESH":
			parse_mesh(
				node_name, tform,
				buffer.get_sub_buffer()
			)
		"BONE":
			buffer.get_sub_buffer()
		"PIVO":
			buffer.get_sub_buffer()
		_:
			buffer.cursor -= 4

	while !buffer.eof_reached():
		var type := buffer.get_type()
		match type:
			"KEYS":
				buffer.get_sub_buffer()
			"NODE":
				var n := buffer.get_sub_buffer()
				process_node(n)
			"ANIM":
				buffer.get_sub_buffer()
			"SEQS":
				buffer.get_sub_buffer()
			_:
				printerr("%s not recognized" % type)
				return

func parse_mesh(
	node_name: String,
	tform: Transform3D,
	buffer: ByteBuffer
) -> void:

	var brush_id := buffer.get_int()

	if buffer.get_type() != "VRTS":
		printerr("Not a mesh")

	var st := process_verts(buffer.get_sub_buffer())

	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()

	while !buffer.eof_reached():
		var type := buffer.get_type()
		match type:
			"TRIS":
				var indices := process_tris(
					buffer.get_sub_buffer()
				)
				if indices.size() != 0:
					arrays[Mesh.ARRAY_INDEX] = indices
				else:
					arrays[Mesh.ARRAY_INDEX] = null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			_:
				printerr("NOT TRIS")
				return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	mesh_instance.owner = owner

func process_tris(buffer: ByteBuffer) -> PackedInt32Array:
	var brush_id := buffer.get_int()
	var indices := PackedInt32Array([])

	while !buffer.eof_reached():
		var v0 := buffer.get_int()
		var v1 := buffer.get_int()
		var v2 := buffer.get_int()

		indices.append_array([
			v0, v1, v2
		])

	return indices

func process_verts(buffer: ByteBuffer) -> SurfaceTool:
	var flags := buffer.get_int()

	var tex_coord_sets := buffer.get_int()
	if tex_coord_sets > 2:
		printerr("More than 2 texcoords not supported")

	var tex_coord_set_size := buffer.get_int()
	if tex_coord_set_size != 2:
		printerr("Only 2D UVs implemented")

	var has_normal: bool = flags & 1
	var has_color: bool = flags & 2
	var has_uv: bool = tex_coord_sets > 0
	var has_uv2: bool = tex_coord_sets == 2

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	while !buffer.eof_reached():
		var pos := buffer.get_vec3()
		if has_normal:
			st.set_normal(buffer.get_vec3())
		if has_color:
			st.set_color(buffer.get_color())
		if has_uv:
			st.set_uv(buffer.get_vec2())
		if has_uv2:
			st.set_uv2(buffer.get_vec2())
		st.add_vertex(pos)

	return st
