@tool
class_name Main
extends Node3D

const Classes := preload("res://blitz_classes.gd")

const BlitzNode := preload("res://blitz_node.gd").BlitzNode
const BlitzMeshNode := preload("res://blitz_mesh.gd").BlitzMeshNode
const BlitzBoneNode := preload("res://blitz_bone_node.gd").BlitzBoneNode
const BlitzTexture := preload("res://blitz_texture.gd").BlitzTexture
const BlitzBrush := preload("res://blitz_brush.gd").BlitzBrush

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

@export_tool_button("Build Mesh") var parse_button := parse

@export_file_path() var path: String = "res://examples/03.txt"

static var model: BlitzModel
static var animator: AnimationPlayer
static var animation: Animation
static var animation_tracks: Dictionary[BlitzNode, int]

func _ready() -> void:
	parse()



func parse() -> void:

	var buffer := ByteBuffer.file_as_buffer(path)
	animator = AnimationPlayer.new()
	animation = Animation.new()
	animation_tracks = {}

	var magic := buffer.get_type()
	assert(magic == "BB3D", "File not recognized")

	buffer = buffer.get_sub_buffer()

	var version: int = buffer.get_int()
	parse_version(version)

	parse_file(buffer)

	_clear_children()
	var m := MeshInstance3D.new()
	m.mesh = BlitzMeshNode.mesh
	add_child(m)
	m.owner = self

	var n := model.node.to_node()
	add_child(n)
	add_to_owner(n)

func add_to_owner(n: Node3D) -> void:
	n.owner = self

	for c: Node3D in n.get_children():
		add_to_owner(c)


class BlitzModel:
	var texs: Array[BlitzTexture] = []
	var brus: Array[BlitzBrush] = []
	var node: BlitzNode

	func to_dict() -> Dictionary:
		var t := texs.map(
			func(s: BlitzTexture) -> Dictionary:
				return s.to_dict()
		)
		return {
			"texs": t,
			"brus": brus,
			"node": node.to_dict()
		}


func parse_file(buffer: ByteBuffer) -> void:

	model = BlitzModel.new()

	while !buffer.eof_reached():
		var block_type: String
		block_type = buffer.get_type()

		match block_type:
			"TEXS":
				model.texs = BlitzTexture.process_texs(buffer)
			"BRUS":
				model.brus = BlitzBrush.process_brush(buffer)
			"NODE":
				model.node = BlitzNode.process_node(buffer)
			_:
				printerr("Type %s not implemented" % block_type)
	print("Parsing complete.")
	#print(JSON.stringify(model.to_dict(), "\t"))











func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()


func parse_version(version: int) -> void:
	var minor: int = version % 100
	var major: int = floori(version / 100.0)

	var version_str: String = "%d.%d" % [major, minor]
	if major > 0: printerr("Version %s not supported" % version_str)
	if minor != 1: print("Version %s might not import correctly" % version_str)

	print("Parsing version %s" % version_str)
