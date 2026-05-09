@tool
extends Node

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

@export_tool_button("Build mesh") var parse_button := parse
@export_global_dir var source: String

static var model_count: int
static var bone_count: int
static var anims: int

func find_meshes(src: String) -> PackedStringArray:
	var d := DirAccess.open(src)
	if DirAccess.get_open_error() != OK:
		print("Error: %s" % error_string(DirAccess.get_open_error()))
		return []
	var files := PackedStringArray([])
	for f: String in d.get_files():
		var fd := f.split(".")
		if fd.size() < 2:
			continue
		if fd[fd.size() - 1] != "b3d":
			continue
		files.append(src.path_join(f))

	for d2: String in d.get_directories():
		files.append_array(find_meshes(src.path_join(d2)))

	return files

func parse() -> void:
	var m := find_meshes(source)
	for n: String in m:
		parse_model(n)

func parse_model(path: String) -> void:
	print("Parsing: %s" % path)
	var f := FileAccess.get_file_as_bytes(path)
	var buffer := ByteBuffer.new(f)
	model_count = 0
	bone_count = 0
	anims = 0
	process_model(buffer)
	print("Mesh: %d, Bone: %d" % [model_count, bone_count])
	if model_count > 1 and bone_count > 0:
		printerr("BANANA")

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
			model_count += 1
			buffer.get_sub_buffer()
		"BONE":
			bone_count += 1
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
				anims += 1
				if anims > 1:
					printerr("Manim")
				buffer.get_sub_buffer()
			"SEQS":
				buffer.get_sub_buffer()
			_:
				printerr("%s not recognized" % type)
				return
