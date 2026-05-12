@tool
extends Node

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

const Model := preload("res://model.gd")


@export_tool_button("Build mesh") var parse_button := parse
@export_global_dir var source: String

static var current_model: Model

func _ready() -> void:
	parse()

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
	for n: String in m.slice(10, 15):
		parse_model(n)

func clear_children() -> void:
	for c: Node in get_children():
		c.queue_free()

func parse_model(path: String) -> void:
	print("Parsing: %s" % path)
	var f := FileAccess.get_file_as_bytes(path)
	var buffer := ByteBuffer.new(f)

	current_model = Model.new()
	add_child(current_model)
	current_model.owner = self
	current_model.name = path.get_file().split('.')[0]

	current_model.process_model(buffer)
