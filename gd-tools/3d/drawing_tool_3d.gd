@tool
extends Object
class_name DrawingTool3D

static var _surface_tool: SurfaceTool


static func _static_init() -> void:
	_surface_tool = SurfaceTool.new()


## Returns shader material with unshaded mode, disabled culling and 
## per-vertex colors support
static func get_default_shader_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, cull_disabled;
	
	void fragment() {
	    ALBEDO = COLOR.rgb;
	    ALPHA = COLOR.a;
	}
	"""
	material.shader = shader
	
	return material


## constructs mesh from given triangles points
static func from_triangles(triangles: PackedVector3Array, color: Color) -> ArrayMesh:
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_surface_tool.set_color(color)
	
	for v in triangles:
		_surface_tool.add_vertex(v)
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Constructs line mesh from given points and color.
## This method is only effective for static meshes.
static func get_static_flat_line(points: PackedVector3Array, color: Color) -> ArrayMesh:
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	_surface_tool.set_color(color)
	
	for i in range(points.size() - 1):
		_surface_tool.add_vertex(points[i])
		_surface_tool.add_vertex(points[i + 1])
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Constructs multicolored line mesh from given points and colors.
## This method is only effective for static meshes.
static func get_static_flat_multicolored_line(points: PackedVector3Array, 
											  colors: PackedColorArray) -> ArrayMesh:
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	for i in range(points.size() - 1):
		_surface_tool.set_color(colors[i])
		_surface_tool.add_vertex(points[i])
		_surface_tool.add_vertex(points[i + 1])
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Constructs thick line mesh (cylindrical) from given points and color.
## Each line segment is represented by cylinder with radius half of the line thickness
## and constructed from given number of segments. Closed means that bottom face of the first
## cilinder in line and top face of the last one will be constructed from circles,
## otherwise there will be no faces at all (line will look like the tunnel).
static func get_static_thick_line(points: PackedVector3Array, color: Color, thickness: float = 0.25,
								  segments: int = 8, closed: bool = false) -> ArrayMesh:
	var radius := thickness / 2.0
	
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_surface_tool.set_color(color)
	
	for i in range(points.size() - 1):
		var verts := _create_cylindrical_line_vertices(points[i], points[i + 1], radius, segments)
		
		for v in verts:
			_surface_tool.add_vertex(v)
	
	if closed and points.size() >= 2:
		for v in _create_circle_cap(points[0], points[1], radius, segments, false):
			_surface_tool.add_vertex(v)
		
		for v in _create_circle_cap(points[-1], points[-2], radius, segments, true):
			_surface_tool.add_vertex(v)
	
	var mesh := _surface_tool.commit()
	
	return mesh


static func _create_cylindrical_line_vertices(from: Vector3, to: Vector3, radius: float,
											  segments: int = 8) -> PackedVector3Array:
	var verts := PackedVector3Array()
	
	var direction := (to - from).normalized()
	var up := Vector3.UP
	# check direction collinear (parallel) with up
	if abs(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	
	# up, right and forward local coordinate system of the cylinder
	var right := direction.cross(up).normalized()
	var forward := right.cross(direction).normalized()
	
	for i in range(segments):
		# angles for each segment (rotation of the current segment)
		var angle1 := i * TAU / segments
		var angle2 := (i + 1) * TAU / segments
		
		# vectors from center to edges of the circle perpendicular to the direction
		var local_right1 := cos(angle1) * right + sin(angle1) * forward
		var local_right2 := cos(angle2) * right + sin(angle2) * forward
		
		#   to
		# C -- D
		# | \  |
		# |  \ |
		# B -- A
		#  from
		
		# ABC
		verts.push_back(from + local_right1 * radius) # from right
		verts.push_back(from + local_right2 * radius) # from left
		verts.push_back(to   + local_right1 * radius) # to left
		
		# CAD
		verts.push_back(to   + local_right1 * radius) # to left
		verts.push_back(from + local_right2 * radius) # from right
		verts.push_back(to   + local_right2 * radius) # to right
	
	return verts


static func _create_circle_cap(center: Vector3, direction_point: Vector3, radius: float, 
							   segments: int = 8, reverse_normal: bool = false) -> PackedVector3Array:
	var verts := PackedVector3Array()
	# this one is using the same technics as the _create_cylindrical_line_vertices() method
	
	# circle normal direction (perpendicular to the circle plane)
	var dir := (direction_point - center).normalized()
	if reverse_normal:
		dir *= -1
	
	var up := Vector3.UP
	if abs(dir.dot(up) > 0.99):
		up = Vector3.RIGHT
	
	var right := dir.cross(up).normalized()
	var forward := right.cross(dir).normalized()
	
	for i in range(segments):
		var angle1 := i * TAU / segments
		var angle2 := (i + 1) * TAU / segments
		
		# points on the circle
		var local_right1 := cos(angle1) * right + sin(angle1) * forward
		var local_right2 := cos(angle2) * right + sin(angle2) * forward
		
		var point1 := center + local_right1 * radius
		var point2 := center + local_right2 * radius
		
		# vertices order is important for proper faces culling
		if reverse_normal:
			verts.push_back(point1)
			verts.push_back(point2)
			verts.push_back(center)
		else:
			verts.push_back(center)
			verts.push_back(point1)
			verts.push_back(point2)
	
	return verts
