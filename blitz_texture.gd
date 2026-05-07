const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

enum BlendMode {
	NORMAL = 2
}

class BlitzTexture:
	var path: String
	var tform: Transform2D
	var flags: int
	var blend_mode: BlendMode = BlendMode.NORMAL

	func to_dict() -> Dictionary:
		return {
			"path": path,
			"tform": tform,
			"flags": flags,
			"blend_mode": blend_mode
		}

	static func process_texs(buffer: ByteBuffer) -> Array[BlitzTexture]:
		var texs: Array[BlitzTexture] = []
		buffer = buffer.get_sub_buffer()

		while !buffer.eof_reached():
			var tex: BlitzTexture = BlitzTexture.new()

			var texture_name: String = buffer.get_string()

			tex.flags = buffer.get_int()

			tex.blend_mode = buffer.get_int() as BlendMode

			var pos: Vector2 = buffer.get_vec2()
			var scl: Vector2 = buffer.get_vec2()
			var rot: float = buffer.get_float()

			tex.tform = Transform2D(rot, pos)
			tex.tform = tex.tform.scaled(scl)

			if tex.tform != Transform2D.IDENTITY:
				printerr("Mutated transform not supported: %s" % tex.tform)

			if tex.flags != 1 and tex.blend_mode != BlendMode.NORMAL:
				printerr("Used flags not supported")

			texs.append(tex)
		return texs
