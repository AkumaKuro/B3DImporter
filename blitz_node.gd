const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer
const BlitzAnim := preload("res://blitz_anim.gd").BlitzAnim
const BlitzBoneNode := preload("res://blitz_bone_node.gd").BlitzBoneNode
const BlitzMeshNode := preload("res://blitz_mesh.gd").BlitzMeshNode
const BlitzSequence := preload("res://blitz_sequence.gd").BlitzSequence

class BlitzNode:

	var name: String
	var tform: Transform3D
	var children: Array[BlitzNode] = []

	var parent: BlitzNode

	var anim: BlitzAnim


	static func process_node(buffer: ByteBuffer, parents: BlitzNode) -> BlitzNode:
		buffer = buffer.get_sub_buffer()

		var node: BlitzNode
		var node_name: String = buffer.get_string()

		var tform := buffer.get_tform()

		var node_type := buffer.get_type()
		match node_type:
			"BONE":
				node = BlitzBoneNode.process_bone(buffer)
			"MESH":
				node = BlitzMeshNode.process_mesh(buffer)
			_:
				print("NodeType %s not found, default to pivot" % node_type)
				node = BlitzNode.new()

		node.name = node_name
		node.tform = tform
		if parents:
			node.parent = parents

		node.node_process(buffer)

		return node

	func get_path() -> PackedStringArray:
		var p := PackedStringArray([])

		if parent != null:
			p.append_array(parent.get_path())

		p.append(name)

		return p

	func node_process(buffer: ByteBuffer) -> void:
		while !buffer.eof_reached():
			var type: String = buffer.get_type()

			match type:
				"ANIM":
					BlitzAnim.process_anim(buffer)
				"SEQS":
					BlitzSequence.process_seqs(buffer)
				"NODE":
					var n := process_node(buffer, self)

					#node_parents.remove_at(node_parents.size() - 1)
					add_child(n)
				"KEYS":
					BlitzAnim.process_keys(buffer, self)
				_:
					printerr("%s not implemented" % type)
					break


	func add_child(child: BlitzNode) -> void:
		self.children.append(child)

	func to_node() -> Marker3D:
		var m := Marker3D.new()
		m.name = name
		m.transform = tform

		for c: BlitzNode in children:
			m.add_child(c.to_node())

		return m

	func to_dict() -> Dictionary:
		var c := children.map(
			func(ch: BlitzNode) -> Dictionary:
				return ch.to_dict()
		)
		return {
			"name": name,
			"tform": tform,
			"children": c
		}
