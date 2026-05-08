const BlitzNode := preload("res://blitz_node.gd").BlitzNode


class BlitzBoneNode extends BlitzNode:
	static var skeleton: Skeleton3D

	var bones: Dictionary[int, float]
	var id: int

	func to_dict() -> Dictionary:
		var d := super.to_dict()
		d["bones"] = bones
		return d

	func _init(bone_name: String, tform: Transform3D) -> void:
		type = Type.BONE
		id = skeleton.add_bone(bone_name)
		skeleton.set_bone_pose(id, tform)

		if parent.type == Type.BONE:
			var p_id: int = parent.id
			skeleton.set_bone_parent(id, p_id)


	static func process_bone(buffer: ByteBuffer, bone_name: String, tform: Transform3D) -> BlitzBoneNode:
		if skeleton == null:
			skeleton = Skeleton3D.new()

		buffer = buffer.get_sub_buffer()

		var bones: Dictionary[int, float] = {}
		while !buffer.eof_reached():
			var vertex_id := buffer.get_int()
			var weight := buffer.get_float()
			# TODO clamp weights??
			bones[vertex_id] = weight

		var node := BlitzBoneNode.new(bone_name, tform)
		node.bones = bones
		return node
