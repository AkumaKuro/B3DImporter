const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer
const BlitzNode := preload("res://blitz_node.gd").BlitzNode

class BlitzAnim:
	static var anim: BlitzAnim
	static var animation: Animation

	var flags: int
	var frames: int
	var fps: float

	# Anim [frame: int, tform: Transform3D]
	# Dict [node: BlitzNode, keys: Anim]
	var tracks: Dictionary[BlitzNode, Dictionary]

	func to_dict() -> Dictionary:
		return {
			"flags": flags,
			"frames": frames,
			"fps": fps,
			"tracks": tracks
		}

	static func process_anim(buffer: ByteBuffer) -> BlitzAnim:
		buffer = buffer.get_sub_buffer()

		if anim != null: printerr("Only one anim supported")
		anim = BlitzAnim.new()
		animation = Animation.new()
		anim.flags = buffer.get_int()
		anim.frames = buffer.get_int()
		anim.fps = buffer.get_float()
		anim.tracks = {}

		return anim

	static func process_keys(buffer: ByteBuffer, node: BlitzNode):
		buffer = buffer.get_sub_buffer()

		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(node.name))

		var key_flags: int = buffer.get_int()
		var has_pos: bool = key_flags & 0b001
		var has_scl: bool = key_flags & 0b010
		var has_rot: bool = key_flags & 0b100

		var keys: Dictionary[int, Transform3D] = {}
		while !buffer.eof_reached():
			var frame := buffer.get_int()

			var tform := buffer.get_tform(
				has_pos, has_scl, has_rot
			)

			animation.track_insert_key(track, frame / anim.fps, tform)
			keys[frame] = tform
		BlitzAnim.anim.tracks[node] = keys
