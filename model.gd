extends Node3D

const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

class BBTexture:
	var file: String
	var flags: int
	var blend: int
	var pos: Vector2
	var scl: Vector2
	var rot: float

var textures: Array[BBTexture] = []

enum NodeType {
	PIVOT,
	BONE,
	MESH
}

class BBNode extends Marker3D:
	@export_storage var type: NodeType
	@export_storage var parent: BBNode

	@export_storage var keys: Dictionary[int, Transform3D]


var has_bones: bool
var anim: Animation
var fps: float
var player: AnimationPlayer = AnimationPlayer.new()

func process_texs(buffer: ByteBuffer) -> void:
	while !buffer.eof_reached():
		var tex := BBTexture.new()
		tex.file = buffer.get_string()
		tex.flags = buffer.get_int()
		tex.blend = buffer.get_int()
		tex.pos = buffer.get_vec2()
		tex.scl = buffer.get_vec2()
		tex.rot = buffer.get_float()
		textures.append(tex)
	pass

class BBBrush:
	var name: String
	var color: Color
	var shininess: float
	var blend: int
	var fx: int
	var texture_id: PackedInt32Array

	func _init(n_texs: int) -> void:
		texture_id = []
		texture_id.resize(n_texs)

func process_brush(buffer: ByteBuffer) -> void:
	var n_texs := buffer.get_int()
	var brushes: Array[BBBrush] = []
	while !buffer.eof_reached():
		var brush := BBBrush.new(n_texs)
		brush.name = buffer.get_string()
		brush.color = buffer.get_color()
		brush.shininess = buffer.get_float()
		brush.blend = buffer.get_int()
		brush.fx = buffer.get_int()
		for texture_id: int in n_texs:
			brush.texture_id[texture_id] = buffer.get_int()
		brushes.append(brush)


func process_model(buffer: ByteBuffer) -> void:
	var type := buffer.get_type()
	if type != "BB3D": printerr("Wrong magic")
	buffer = buffer.get_sub_buffer()
	var version := buffer.get_int()
	if version != 1: printerr("Unrecognized version")
	add_child(player)
	player.owner = owner

	while !buffer.eof_reached():
		type = buffer.get_type()
		match type:
			"TEXS":
				process_texs(buffer.get_sub_buffer())
			"BRUS":
				process_brush(buffer.get_sub_buffer())
			"NODE":
				process_node(buffer.get_sub_buffer(), self)
			_:
				printerr("Weird type: %s" % type)

	if anim:
		var lib := AnimationLibrary.new()
		lib.add_animation("main", anim)
		player.add_animation_library("main", lib)
	else:
		player.queue_free()
	hide()

var bones: Array[BBBone] = []

class BBBone:
	var node: BBNode

	# Dict [vertex_id: int, weight: float]
	var bindings: Dictionary[int, float] = {}

func process_bone(buffer: ByteBuffer, parent: BBNode) -> void:
	var bone := BBBone.new()
	bone.node = parent
	while !buffer.eof_reached():
		var vertex_id := buffer.get_int()
		var weight := buffer.get_float()

		bone.bindings[vertex_id] = weight
	bones.append(bone)


func process_node(buffer: ByteBuffer, parent: Node3D) -> void:
	var node := BBNode.new()
	parent.add_child(node)
	node.owner = owner

	node.name = buffer.get_string()
	node.transform = buffer.get_tform()

	var type := buffer.get_type()

	match type:
		"MESH":
			node.type = NodeType.MESH
			parse_mesh(node, buffer.get_sub_buffer())
		"BONE":
			node.type = NodeType.BONE
			process_bone(buffer.get_sub_buffer(), node)
		"PIVO":
			node.type = NodeType.PIVOT
			buffer.get_sub_buffer()
		_:
			node.type = NodeType.PIVOT
			buffer.cursor -= 4

	while !buffer.eof_reached():
		type = buffer.get_type()
		match type:
			"KEYS":
				process_keys(buffer.get_sub_buffer(), node)
			"NODE":
				var n := buffer.get_sub_buffer()
				process_node(n, node)
			"ANIM":
				process_anim(buffer.get_sub_buffer())
			"SEQS":
				buffer.get_sub_buffer()
			_:
				printerr("%s not recognized" % type)
				return

func process_keys(buffer: ByteBuffer, node: BBNode) -> void:
	var flags := buffer.get_int()

	var has_pos := flags & 1
	var has_scl := flags & 2
	var has_rot := flags & 4

	var pos_track: int
	var scl_track: int
	var rot_track: int

	if has_pos:
		pos_track = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, player.get_parent().get_path_to(node))

	if has_scl:
		scl_track = anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(scl_track, player.get_parent().get_path_to(node))

	if has_rot:
		rot_track = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, player.get_parent().get_path_to(node))

	while !buffer.eof_reached():
		var frame := buffer.get_int()
		var time := frame / fps
		if has_pos:
			var pos := buffer.get_vec3()
			anim.track_insert_key(pos_track, time, pos)

		if has_scl:
			var scl := buffer.get_vec3()
			anim.track_insert_key(scl_track, time, scl)

		if has_rot:
			var rot := buffer.get_quat()
			anim.track_insert_key(rot_track, time, rot)

func process_anim(buffer: ByteBuffer) -> void:
	var flags := buffer.get_int()
	var frames := buffer.get_int()
	fps = buffer.get_float()

	if anim != null:
		printerr("Only one anim block per file supported")

	anim = Animation.new()
	anim.length = frames / fps

func parse_mesh(
	node: Node3D,
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
	mesh_instance.mesh = mesh
	node.add_child(mesh_instance)
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
