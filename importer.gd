@tool
extends Node

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

@export_tool_button("Build mesh") var parse_button := parse
@export_global_dir var source: String

static var current_node: Node3D

func find_meshes(src: String) -> PackedStringArray:
	var d := DirAccess.open(src)
	if DirAccess.get_open_error() != OK:
		print("Error: %s" % error_string(DirAccess.get_open_error()))
		return []
	var files := PackedStringArray([])
	for f: String in d.get_files():
		var fd := f.get_extension()
		if fd != "b3d":
			continue
		files.append(src.path_join(f))

	for d2: String in d.get_directories():
		files.append_array(find_meshes(src.path_join(d2)))

	return files

func parse() -> void:
	clear_children()
	var m := find_meshes(source)
	for n: String in m:
		parse_model(n)

func clear_children() -> void:
	for c: Node in get_children():
		c.queue_free()

func parse_model(path: String) -> void:
	print("Parsing: %s" % path)
	var f := FileAccess.get_file_as_bytes(path)
	var buffer := ByteBuffer.new(f)

	current_node = Node3D.new()
	add_child(current_node)
	current_node.owner = self
	current_node.name = path.get_file().split('.')[0]

	process_model(buffer)

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
	current_node.add_child(mesh_instance)
	mesh_instance.owner = self

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
