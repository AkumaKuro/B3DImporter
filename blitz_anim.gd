const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

class BlitzAnim:
	static var anim: BlitzAnim

	var flags: int
	var frames: int
	var fps: float

	# Dict [frame: int, tform: Transform3D]
	var keys: Array[Dictionary]

	func to_dict() -> Dictionary:
		return {
			"flags": flags,
			"frames": frames,
			"fps": fps,
			"keys": keys
		}

	static func process_anim(buffer: ByteBuffer) -> BlitzAnim:
		buffer = buffer.get_sub_buffer()

		if anim != null: printerr("Only one anim supported")
		anim = BlitzAnim.new()
		anim.flags = buffer.get_int()
		anim.frames = buffer.get_int()
		anim.fps = buffer.get_float()
		anim.keys = []

		return anim

	static func process_keys(buffer: ByteBuffer):
		buffer = buffer.get_sub_buffer()

		var flags: int = buffer.get_int()
		var has_pos: bool = flags & 0b001
		var has_scl: bool = flags & 0b010
		var has_rot: bool = flags & 0b100

		var keys: Dictionary[int, Transform3D] = {}
		while !buffer.eof_reached():
			var frame := buffer.get_int()


			var tform := buffer.get_tform(
				has_pos, has_scl, has_rot
			)
			keys[frame] = tform
		BlitzAnim.anim.keys.append(keys)
