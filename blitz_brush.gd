const ByteBuffer := preload("res://byte_buffer.gd").ByteBuffer

class BlitzBrush:
	var name: String
	var color: Color
	var shininess: float
	var blend: int
	var fx: int
	var texture_id: int

	func to_dict() -> Dictionary:
		return {
			"name": name,
			"color": color,
			"shininess": shininess,
			"blend": blend,
			"fx": fx,
			"texture_id": texture_id
		}

	func _to_string() -> String:
		return str(to_dict())

	static func process_brush(buffer: ByteBuffer) -> Array[BlitzBrush]:
		buffer = buffer.get_sub_buffer()

		var count: int = buffer.get_int()
		var brushes: Array[BlitzBrush] = []

		for i: int in count:
			var brush: BlitzBrush = BlitzBrush.new()
			brush.name = buffer.get_string()
			brush.color = buffer.get_color()
			brush.shininess = buffer.get_float()
			brush.blend = buffer.get_int()
			brush.fx = buffer.get_int()
			brush.texture_id = buffer.get_int()
			brushes.append(brush)
		return brushes
