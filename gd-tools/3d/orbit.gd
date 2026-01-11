@tool
extends Resource
class_name Orbit
## A resource for orbital mechanics calculations in 2D and 3D.
##
## This class implements Keplerian orbit calculations using the standard
## [url=https://en.wikipedia.org/wiki/Orbital_elements]eight orbital parameters[/url] 
## plus system origin (major focus) three coordinates.
## It provides fast position prediction without solving Newton's equations numerically.
## [br][br]
## [b]Coordinate System:[/b][br]
## This class uses a modified coordinate system optimized for Godot Engine:
## [codeblock lang=text]
## |                                                  | Godot          | Standard astronomical |
## |                                                  | implementation | system                |
## ---------------------------------------------------------------------------------------------
## | • Points toward the periapsis                    |       +X       |           +X          |
## | • Points in the direction of motion at periapsis |       -Z       |           +Y          |
## | • Perpendicular to the reference plane           |       +Y       |           +Z          |
## [/codeblock]
## [br]
## [b]Rotation order:[/b][br]
## The implemented coordinate system has the following rotation order:
## [codeblock lang=text]
## 1. Longitude of the ascending node around +Y
## 2. Inclination around +X
## 3. Argument of periapsis around +Y
## [/codeblock]

## Gravitational constant [i](scaled to unit system)[/i].
## Default value assumes distance and time units are appropriately scaled.
const G: float = 1.0

## X-axis direction in the orbital plane [i](points toward periapsis)[/i].
const X_DIRECTION := Vector3(1,  0,  0)

## Y-axis direction [i](perpendicular to orbital plane, points upward)[/i].
const Y_DIRECTION := Vector3(0,  1,  0)

## Z-axis direction [i](in-plane, motion direction at periapsis)[/i].
const Z_DIRECTION := Vector3(0,  0, -1)

## Composite axis vector for coordinate transformations.
## This vector maps standard orbital plane coordinates to Godot's coordinate system.
const AXIS := Vector3(X_DIRECTION.x, Y_DIRECTION.y, Z_DIRECTION.z)

#region GEOMETRY_PROPS
@export_group("Geometry")
var _F1: Vector3 = Vector3.ZERO
## Position of the primary [i](central)[/i] focus, where the central body is located.
## This is typically the more massive body in a two-body system.
@export var major_focus: Vector3 = Vector3.ZERO:
	set(val):
		if _F1 != val:
			_F1 = val
			emit_changed()
	get:
		return _F1

var _F2: Vector3:
	get:
		var f = Vector3(AXIS.x * -2 * _a * _e, 0, 0)
		f = _rotate_point(f)
		f += _F1
		return f
## Position of the secondary [i](empty)[/i] focus of the elliptical orbit.
## For circular orbits ([code]eccentricity = 0[/code]), this coincides with the major focus.
var minor_focus: Vector3:
	get: return _F2

var _C: Vector3:
	get:
		var c = Vector3(AXIS.x * -_a * _e, 0, 0)
		c = _rotate_point(c)
		c += _F1
		return c
## Geometric center of the elliptical orbit.
var center: Vector3:
	get: return _C

var _periapsis_pos: Vector3:
	get:
		var p := Vector3(periapsis, 0, 0)
		p = _rotate_point(p)
		p += _F1
		return p
## Position of the periapsis [i](closest point to the central body)[/i].
var periapsis_position: Vector3:
	get: return _periapsis_pos

var _proj_periapsis_pos: Vector3:
	get:
		var v := _periapsis_pos
		var n := Y_DIRECTION
		var p := v - n * v.dot(n)
		p.y += _F1.y
		return p
## Periapsis position projected onto the reference plane ([code]Y = major_focus.y[/code]).
var projected_periapsis_position: Vector3:
	get: return _proj_periapsis_pos

var _apoapsis_pos: Vector3:
	get:
		var p := Vector3(apoapsis, 0, 0)
		p = _rotate_point(p)
		p = _F1 - p
		return p
## Position of the apoapsis [i](farthest point from the central body)[/i].
var apoapsis_position: Vector3:
	get: return _apoapsis_pos

var _proj_apoapsis_pos: Vector3:
	get:
		var v := _apoapsis_pos
		var n := Y_DIRECTION
		var p := v - n * v.dot(n)
		p.y += _F1.y
		return p
## Apoapsis position projected onto the reference plane ([code]Y = major_focus.y[/code]).
var projected_apoapsis_position: Vector3:
	get: return _proj_apoapsis_pos

var _asc_node_pos: Vector3:
	get:
		# Switch ascending and descending nodes for negative inclination
		var v := -_w if _i > 0 else PI - _w
		var r := _p / (1 + _e * cos(v))
		var p := Vector3(AXIS.x * r * cos(v), 0, AXIS.z * r * sin(v))
		p = _rotate_point(p)
		p += _F1
		return p
## Position of the ascending node [i](where orbit crosses reference plane upward)[/i].
var ascending_node_position: Vector3:
	get: return _asc_node_pos

var _desc_node_pos: Vector3:
	get:
		# Switch ascending and descending nodes for negative inclination
		var v := PI - _w if _i > 0 else -_w
		var r := _p / (1 + _e * cos(v))
		var p := Vector3(AXIS.x * r * cos(v), 0, AXIS.z * r * sin(v))
		p = _rotate_point(p)
		p += _F1
		return p
## Position of the descending node [i](where orbit crosses reference plane downward)[/i].
var descending_node_position: Vector3:
	get: return _desc_node_pos

var _init_pos: Vector3:
	get:
		return get_orbital_position_3d(_t0)
## Body position at the epoch time ([code]t = epoch[/code]).
## For valid orbits, this should match the mean longitude specification.
var initial_orbital_position: Vector3:
	get: return _init_pos
#endregion

#region SHAPE_PROPS
@export_group("Shape and Size")
var _a: float = 1.0
## Semi-major axis - the largest radius of the elliptical orbit.
## Must be positive. Defines the orbit's size.
@export var semi_major_axis: float = 1.0:
	set(val):
		if val <= 0:
			push_error("Semi-major axis must be positive")
			return
		if _a != val:
			_a = val
			emit_changed()
	get:
		return _a

var _b: float:
	get: 
		return _a * sqrt(1 - _e * _e)
## Semi-minor axis - the smallest radius of the elliptical orbit.
var semi_minor_axis: float:
	get: return _b

var _e: float = 0.5
## Orbital eccentricity, defining the shape of the ellipse.
## Range: [code]0.0[/code] [i](circle)[/i] to [code]1.0[/code] [i](parabola, not supported)[/i].
@export_range(0.0, 0.99, 0.01) var eccentricity: float = 0.5:
	set(val):
		if val < 0 or val >= 1.0:
			push_error("Eccentricity must be in range [0, 1)")
			return
		if _e != val:
			_e = val
			emit_changed()
	get:
		return _e

var _p: float:
	get: 
		return _a * (1 - _e * _e)
## Semi-parameter - the orbital parameter perpendicular to the semi-major axis.
## Also known as the semi-latus rectum.
var semi_parameter: float:
	get: return _p

var _ra: float:
	get: 
		return _p / (1 - _e)
## Apoapsis distance - farthest distance from the central body [i](scalar)[/i].
var apoapsis: float:
	get: return _ra

var _rp: float:
	get: 
		return _p / (1 + _e)
## Periapsis distance - closest distance to the central body [i](scalar)[/i].
var periapsis: float:
	get: return _rp
#endregion

#region ROTATION_PROPS
@export_group("Orientation")
var _i: float     = 0 # In radians
var _i_deg: float = 0 # In degrees
## Orbital inclination - tilt of the orbital plane relative to the reference plane.
## Negative values invert ascending/descending nodes.
@export_range(-180.0, 180.0, 0.1) var inclination_deg: float = 0.0:
	set(val):
		if _i_deg != val:
			_i_deg = val
			_i = deg_to_rad(val)
			emit_changed()
	get:
		return _i_deg

var _W: float     = 0 # In radians
var _W_deg: float = 0 # In degrees
## Longitude of the ascending node [i](Ω)[/i] - rotation around the reference plane normal.
## Defines where the orbit crosses the reference plane moving upward.
@export_range(-180.0, 180.0, 0.1) var longitude_of_the_ascending_node_deg: float = 0.0:
	set(val):
		if _W_deg != val:
			_W_deg = val
			_W = deg_to_rad(val)
			emit_changed()
	get:
		return _W_deg

var _w: float     = 0 # In radians
var _w_deg: float = 0 # In degrees
## Argument of periapsis [i](ω)[/i] - angle from ascending node to periapsis.
## Defines the orientation of the ellipse within the orbital plane.
@export_range(-180.0, 180.0, 0.1) var argument_of_periapsis_deg: float = 0.0:
	set(val):
		if _w_deg != val:
			_w_deg = val
			_w = deg_to_rad(val)
			emit_changed()
	get:
		return _w_deg
#endregion

#region MOVEMENT_PROPS
@export_group("Motion")
var _n_deg: float:
	get: 
		return rad_to_deg(_n)
var _n: float:
	get: 
		return sqrt(_mu / _a**3)
## Mean motion - average angular speed in degrees per time unit.
var mean_motion_deg: float:
	get: return _n_deg

var _P: float:
	get: 
		return TAU / _n
## Orbital period - time for one complete revolution.
var orbital_period: float:
	get: return _P

var _mu: float:
	get: 
		return _M * G
## Standard gravitational parameter ([code]μ = G × M[/code]).
## Product of gravitational constant and central body mass.
var standard_gravitational_parameter: float:
	get: return _mu

var _M: float = 1.0
## Mass of the central [i](dominant)[/i] body in the system.
## Must be positive. Affects orbital period via Kepler's third law.
@export var central_body_mass: float = 1.0:
	set(val):
		if val <= 0:
			push_error("Central body mass must be positive")
			return
		if _M != val:
			_M = val
			emit_changed()
	get:
		return _M
#endregion

#region POSITION_PROPS
@export_group("Position in time")
var _t0: float = 0
## Epoch time - reference time for mean longitude and initial position.
## Typically set to 0 for simulation start time.
@export var epoch: float = 0.0:
	set(val):
		if _t0 != val:
			_t0 = val
			emit_changed()
	get:
		return _t0

var _T0: float:
	get:
		var M0 := get_mean_anomaly(_t0)
		return _t0 - M0 / _n
## Time of periapsis passage - when the body last passed through periapsis.
var time_of_periapsis_passage:
	get: return _T0

var _L0: float     = 0 # In radians
var _L0_deg: float = 0 # In degrees
## Mean longitude at epoch [i](L₀)[/i] - angular position assuming circular orbit.
## Measured from the reference direction ([code]+X[/code]) at time [code]epoch[/code].
@export_range(0.0, 360.0, 0.1) var mean_longitude_deg: float = 0.0:
	set(val):
		if _L0_deg != val:
			_L0_deg = val
			_L0 = deg_to_rad(val)
			emit_changed()
	get:
		return _L0_deg
#endregion

#region DRAWING_PROPS
var _points2: PackedVector2Array = []
## Precomputed 2D orbit points for visualization.
## Call [method calculate_points_2d] to populate this array.
var points_2d: PackedVector2Array:
	get: return _points2

var _points3: PackedVector3Array = []
## Precomputed 3D orbit points for visualization.
## Call [method calculate_points_3d] to populate this array.
var points_3d: PackedVector3Array:
	get: return _points3
#endregion


#region CONSTRUCTORS
func _init() -> void:
	pass


## Creates a new Orbit instance with specified parameters.
## [br][br]
## [param F1]: Position of the central body [i](major focus)[/i][br]
## [param a]: Semi-major axis [i](must be > 0)[/i][br]
## [param e]: Eccentricity [i](0 ≤ e < 1)[/i][br]
## [param i]: Inclination in degrees[br]
## [param W]: Longitude of ascending node in degrees[br]
## [param w]: Argument of periapsis in degrees[br]
## [param M]: Central body mass [i](must be > 0)[/i][br]
## [param t0]: Epoch time[br]
## [param L0]: Mean longitude at epoch in degrees[br]
## [b]returns[/b]: A new Orbit instance, or [code]null[/code] if parameters are invalid
static func from_params(F1: Vector3, a: float, e: float, i: float, W: float, w: float,
						M: float, t0: float, L0: float) -> Orbit:
	if a <= 0:
		push_error("Semi-major axis must be positive")
		return null
	if e < 0 or e >= 1.0:
		push_error("Eccentricity must be in range [0, 1)")
		return null
	if M <= 0:
		push_error("Central body mass must be positive")
		return null
	
	var orbit := Orbit.new()
	orbit.major_focus = F1
	orbit.semi_major_axis = a
	orbit.eccentricity = e
	orbit.inclination_deg = i
	orbit.longitude_of_the_ascending_node_deg = W
	orbit.argument_of_periapsis_deg = w
	orbit.central_body_mass = M
	orbit.epoch = t0
	orbit.mean_longitude_deg = L0
	
	return orbit


## Creates a default 2D orbit for testing and demonstration.
## Returns an elliptical orbit with visible eccentricity.
static func default2d() -> Orbit:
	return Orbit.from_params(
		Vector3(450, 150, 0),  # Focus position
		300,                   # Semi-major axis
		0.75,                  # Eccentricity
		0,                     # Inclination
		25,                    # Longitude of ascending node
		0,                     # Argument of periapsis
		10,                    # Central body mass
		0,                     # Epoch
		0                      # Mean longitude
	)


## Creates a default 3D orbit for testing and demonstration.
## Returns a moderately inclined elliptical orbit.
static func default3d() -> Orbit:
	return Orbit.from_params(
		Vector3(0, 0, 0),      # Focus at origin
		12,                    # Semi-major axis
		0.7,                   # Eccentricity
		45,                    # Inclination
		90,                    # Longitude of ascending node
		30,                    # Argument of periapsis
		10,                    # Central body mass
		95,                    # Epoch
		0                      # Mean longitude
	)
#endregion


## Calculates 2D orbit points for visualization.[br][br]
## Generates [param samples] [i](minimum 3)[/i] equally spaced points around the orbit.
## Results are stored in [member points_2d].
func calculate_points_2d(samples: int) -> void:
	if samples < 3:
		push_error("Sample count must be at least 3")
		return
	
	_points2.clear()
	var step := TAU / samples
	
	for ix in range(samples):
		var theta := ix * step
		var p := Vector3(AXIS.x * _a * cos(theta), 0, AXIS.z * _b * sin(theta))
		p = _rotate_point(p)
		#p = p.rotated(Y_DIRECTION, _W)
		p += _C
		_points2.append(Vector2(p.x, p.z))
	
	# Close the loop
	_points2.append(_points2[0])


## Calculates 3D orbit points for visualization.[br][br]
## Generates [param samples] [i](minimum 3)[/i] equally spaced points around the orbit.
## Results are stored in [member points_3d].
func calculate_points_3d(samples: int) -> void:
	if samples < 3:
		push_error("Sample count must be at least 3")
		return
	
	_points3.clear()
	var step := TAU / samples
	
	for ix in range(samples):
		var theta := ix * step
		var p := Vector3(AXIS.x * _a * cos(theta), 0, AXIS.z * _b * sin(theta))
		p = _rotate_point(p)
		p += _C
		_points3.append(p)
	
	# Close the loop
	_points3.append(_points3[0])


## Generates triangle vertices for rendering the orbital plane.[br][br]
## Creates triangles connecting the orbit center to each edge segment.
## Useful for rendering a filled orbital plane.[br]
## [param samples]: Number of orbit segments [i](minimum 3)[/i][br]
## [b]returns[/b]: Array of vertices for triangle rendering
func get_orbit_plane_triangles(samples: int) -> PackedVector3Array:
	calculate_points_3d(samples)
	var verts := PackedVector3Array()
	
	for i in range(_points3.size() - 1):
		verts.push_back(_points3[i])
		verts.push_back(_points3[i + 1])
		verts.push_back(_C)
	
	return verts


## Calculates mean longitude [i](L)[/i] at specified time.[br][br]
## Mean longitude represents the angular position assuming a circular orbit
## with the same period, measured from the reference direction ([code]+X[/code]).
func get_mean_longitude(time: float) -> float:
	return _L0 + _n * (time - _t0)


## Calculates mean anomaly [i](M)[/i] at specified time.[br][br]
## Mean anomaly is the angular position relative to periapsis,
## assuming constant angular speed.
func get_mean_anomaly(time: float) -> float:
	var L := get_mean_longitude(time)
	return fmod(L - _w - _W, TAU)


## Calculates eccentric anomaly [i](E)[/i] using Newton's method.[br][br]
## Solves Kepler's equation: [code]M = E - e × sin(E)[/code]. 
## Iterates [b]10[/b] times for convergence [i](sufficient for most applications)[/i].
func get_eccentric_anomaly(time: float) -> float:
	var M := get_mean_anomaly(time)
	var E := M
	
	# Newton-Raphson iteration for Kepler's equation
	for i in range(10):
		var delta := (M - E + _e * sin(E)) / (1.0 - _e * cos(E))
		E += delta
		if abs(delta) < 1e-10:  # Convergence check
			break
	
	return E


## Calculates true anomaly [i](ν)[/i] at specified time.[br][br]
## True anomaly is the actual angular position relative to periapsis.
func get_true_anomaly(time: float) -> float:
	var E := get_eccentric_anomaly(time)
	var sin_v := (sqrt(1.0 - _e * _e) * sin(E)) / (1.0 - _e * cos(E))
	var cos_v := (cos(E) - _e) / (1.0 - _e * cos(E))
	return atan2(sin_v, cos_v)


## Calculates true longitude [i](l)[/i] at specified time.[br][br]
## True longitude is the actual angular position measured from the
## reference direction ([code]+X[/code]).
func get_true_longitude(time: float) -> float:
	var v := get_true_anomaly(time)
	return v + _w + _W


## Calculates mean argument of latitude [i](uₘ)[/i] at specified time.[br][br]
## Mean argument of latitude is the angular position relative to
## the ascending node, assuming circular motion.
func get_mean_argument_of_latitude(time: float) -> float:
	var M := get_mean_anomaly(time)
	return fmod(M + _W, TAU)


## Calculates argument of latitude [i](u)[/i] at specified time.[br][br]
## Argument of latitude is the actual angular position relative to
## the ascending node.
func get_argument_of_latitude(time: float) -> float:
	var v := get_true_anomaly(time)
	return fmod(v + _W, TAU)


## Calculates the 3D position of the orbiting body at specified time.[br][br]
## This is the main method for orbit propagation. It combines all
## orbital elements to compute the body's position in world space.
func get_orbital_position_3d(time: float) -> Vector3:
	var v := get_true_anomaly(time)
	var r := _p / (1 + _e * cos(v))
	var p := Vector3(AXIS.x * r * cos(v), 0, AXIS.z * r * sin(v))
	p = _rotate_point(p)
	p += _F1
	return p


func _rotate_point(p: Vector3) -> Vector3:
	p = p.rotated(Y_DIRECTION, _w)
	p = p.rotated(X_DIRECTION, _i)
	p = p.rotated(Y_DIRECTION, _W)
	return p
