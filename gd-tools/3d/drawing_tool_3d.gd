@tool
extends Object
class_name DrawingTool3D
## A utility class for creating 3D meshes programmatically.
##
## This class provides methods to generate various types of 3D geometry including:[br]
## - Single- and multi-colored lines[br]
## - Meshes for static [i](rare redraws)[/i] ang dynamic [i](frequent redraws)[/i] usage[br]
## - Flat and thick cylindrical lines with optional end caps[br]
## - Triangle meshes[br]
## - Custom materials for rendering[br]
##[br][br]
## [b]Usage Example:[/b]
## [codeblock]
## # Create a simple line mesh
## var points := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 5, 0)])
## var line_mesh = DrawingTool3D.get_static_flat_line(points, Color.RED)
##
## $MeshInstance3D.material_override = DrawingTool3D.get_default_shader_material()
## $MeshInstance3D.mesh = line_mesh
## [/codeblock]
##[br]
## [b]Note:[/b] This class is a singleton-like utility. All methods are static.

static var _surface_tool: SurfaceTool


static func _static_init() -> void:
	_surface_tool = SurfaceTool.new()


## Returns shader material with [code]unshaded mode[/code], [code]disabled culling[/code] and 
## [code]per-vertex colors[/code] support
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


## Creates a triangle mesh from a flat array of vertex positions.[br][br]
## This method takes a [PackedVector3Array] where each three consecutive vertices
## form one triangle. All triangles will have the same color.
static func from_triangles(triangles: PackedVector3Array, color: Color) -> ArrayMesh:
	if triangles.size() % 3 != 0:
		push_error("Triangle array size must be multiple of 3")
		return null
	
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_surface_tool.set_color(color)
	
	for v in triangles:
		_surface_tool.add_vertex(v)
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Creates a simple line mesh connecting consecutive points.[br][br]
## Generates a line strip where each line segment connects point [code]i[/code] to point [code]i+1[/code].
## All segments share the same color. The mesh uses [code]PRIMITIVE_LINES[/code], so each segment
## is independent [i](no continuity between segments)[/i].
##[br][br]
## [b]Note:[/b] For performance reasons, this method is best suited for static geometry.
## For frequently updating lines, consider alternative approaches.
static func get_static_flat_line(points: PackedVector3Array, color: Color) -> ArrayMesh:
	if points.size() < 2:
		push_error("At least 2 points required for line generation")
		return ArrayMesh.new()
	
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	_surface_tool.set_color(color)
	
	for i in range(points.size() - 1):
		_surface_tool.add_vertex(points[i])
		_surface_tool.add_vertex(points[i + 1])
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Creates a multicolored line mesh with per-segment colors.[br][br]
## Similar to [method get_static_flat_line], but allows each line segment to have
## a different color. The color at index [code]i[/code] is applied to the segment
## connecting points [code]i[/code] and [code]i+1[/code].
##[br][br]
## [b]Note:[/b] For performance reasons, this method is best suited for static geometry.
## For frequently updating lines, consider alternative approaches.
static func get_static_flat_multicolored_line(points: PackedVector3Array, 
											  colors: PackedColorArray) -> ArrayMesh:
	if points.size() < 2:
		push_error("At least 2 points required for line generation")
		return ArrayMesh.new()
	
	if colors.size() != points.size() - 1:
		push_error("Colors array must have exactly (points.size() - 1) elements")
		return ArrayMesh.new()
	
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_LINES)
	
	for i in range(points.size() - 1):
		_surface_tool.set_color(colors[i])
		_surface_tool.add_vertex(points[i])
		_surface_tool.add_vertex(points[i + 1])
	
	var mesh := _surface_tool.commit()
	
	return mesh


## Creates a thick cylindrical line mesh from a series of points.[br][br]
## Generates a 3D cylindrical tube along the specified path. Each segment between
## consecutive points becomes a cylinder with the specified thickness.
## [br][br]
## [b]Parameters:[/b][br]
## - [param points]: Array of points defining the path. Must contain at least 2 points.[br]
## - [param color]: Color for the entire cylindrical line.[br]
## - [param thickness]: Diameter of the cylindrical tube [i](default: 0.25)[/i].[br]
## - [param segments]: Number of sides for each cylinder [i](default: 6)[/i]. Higher values
##   produce smoother cylinders but increase vertex count.[br]
## - [param closed]: If [code]true[/code], adds circular caps to the ends of the line.
##   When [code]false[/code], the tube remains open at both ends.
## [br][br]
## [b]Performance:[/b] Vertex count scales with [code]points.size() * segments * 2[/code].[br]
## Use higher segment counts judiciously for complex paths.[br]
## [b]Note:[/b] For performance reasons, this method is best suited for static geometry.
## For frequently updating lines, consider alternative approaches.
static func get_static_thick_line(points: PackedVector3Array, color: Color, thickness: float = 0.25,
								  segments: int = 6, closed: bool = false) -> ArrayMesh:
	if points.size() < 2:
		push_error("At least 2 points required for thick line generation")
		return ArrayMesh.new()
	
	if thickness <= 0:
		push_error("Thickness must be greater than 0")
		return ArrayMesh.new()
	
	if segments < 3:
		push_error("Segments must be at least 3")
		return ArrayMesh.new()
	
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


## Creates a thick cylindrical line mesh with per-segment colors.[br][br]
## Similar to [method get_static_thick_line], but allows each cylindrical segment
## to have a different color. The color at index [code]i[/code] is applied to the
## cylinder connecting points [code]i[/code] and [code]i+1[/code].
## [br][br]
## [b]Performance:[/b] Vertex count scales with [code]points.size() * segments * 2[/code].
## Use higher segment counts judiciously for complex paths.[br]
## [b]Note:[/b] For performance reasons, this method is best suited for static geometry.
## For frequently updating lines, consider alternative approaches.
static func get_static_thick_multicolored_line(points: PackedVector3Array, colors: PackedColorArray, 
											   thickness: float = 0.25, segments: int = 6, 
											   closed: bool = false) -> ArrayMesh:
	if points.size() < 2:
		push_error("At least 2 points required for thick line generation")
		return ArrayMesh.new()
	
	if colors.size() != points.size() - 1:
		push_error("Colors array must have exactly (points.size() - 1) elements")
		return ArrayMesh.new()
	
	if thickness <= 0:
		push_error("Thickness must be greater than 0")
		return ArrayMesh.new()
	
	if segments < 3:
		push_error("Segments must be at least 3")
		return ArrayMesh.new()
	
	var radius := thickness / 2.0
	
	_surface_tool.clear()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(points.size() - 1):
		_surface_tool.set_color(colors[i])
		var verts := _create_cylindrical_line_vertices(points[i], points[i + 1], radius, segments)
		
		for v in verts:
			_surface_tool.add_vertex(v)
	
	if closed and points.size() >= 2:
		_surface_tool.set_color(colors[0])
		for v in _create_circle_cap(points[0], points[1], radius, segments, false):
			_surface_tool.add_vertex(v)
		
		_surface_tool.set_color(colors[-1])
		for v in _create_circle_cap(points[-1], points[-2], radius, segments, true):
			_surface_tool.add_vertex(v)
	
	var mesh := _surface_tool.commit()
	
	return mesh


# Generates vertices for a cylindrical segment between two points.
#
# This internal method creates the triangle vertices for a single cylindrical
# segment (a tube section). The cylinder is oriented along the direction from
# [param from] to [param to].
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


# Generates vertices for a circular cap at the end of a cylindrical line.
#
# This internal method creates a circular face perpendicular to the line direction.
# Used to create closed ends for cylindrical lines when [param closed] is true.
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
