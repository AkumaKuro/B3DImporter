const BlitzNode := preload("res://blitz_node.gd").BlitzNode


class BlitzBoneNode extends BlitzNode:
	var bones: Dictionary[int, float]

	func to_dict() -> Dictionary:
		var d := super.to_dict()
		d["bones"] = bones
		return d

	static func process_bone(buffer: ByteBuffer) -> BlitzBoneNode:
		buffer = buffer.get_sub_buffer()

		var bones: Dictionary[int, float] = {}
		while !buffer.eof_reached():
			var vertex_id := buffer.get_int()
			var weight := buffer.get_float()
			# TODO clamp weights??
			bones[vertex_id] = weight

		var node := BlitzBoneNode.new()
		node.bones = bones
		return node
