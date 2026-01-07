@tool
## A resource that provides calculations of orbital mechanics for 2d and 3d
##
## This class is used to easily create orbits based on parameters and predict body position
## in time, which avoids expensive Newton's equations.
extends Resource
class_name Orbit

## gravitational constant
const G: float = 1.0
## the direction of the X-axis. By default, it points on a periapsis in the plane of the orbit
const X_DIRECTION := Vector3(1,  0,  0)
## the direction of the Y-axis. By default, it is perpendicular to the plane of the orbit
const Y_DIRECTION := Vector3(0,  1,  0)
## the direction of the Z-axis. By default, it matches the movement direction on a periapsis 
## in the plane of the orbit
const Z_DIRECTION := Vector3(0,  0, -1)
## orbital axis compared to the Godot's
const AXIS := Vector3(X_DIRECTION.x, Y_DIRECTION.y, Z_DIRECTION.z)

#region GEOMETRY_PROPS
@export_group("Geometry")
var _F1: Vector3
## position of the center of mass
@export var major_focus: Vector3:
	set(val):
		if _F1 != val:
			_F1 = val
			emit_changed()
	get:
		return _F1

var _F2: Vector3:
	get:
		var f = Vector3(AXIS.x * -2 * _a * _e, 0, 0)
		f = f.rotated(Z_DIRECTION, _i)
		f = f.rotated(Y_DIRECTION, _W)
		f = f.rotated(X_DIRECTION, _w)
		f += _F1
		
		return f
## second orbital focus
var minor_focus: Vector3:
	get:
		return _F2

var _C: Vector3:
	get:
		var c = Vector3(AXIS.x * -_a * _e, 0, 0)
		c = c.rotated(Z_DIRECTION, _i)
		c = c.rotated(Y_DIRECTION, _W)
		c = c.rotated(X_DIRECTION, _w)
		c += _F1
		
		return c
## center of the orbit
var center: Vector3:
	get:
		return _C

var _init_pos: Vector3:
	get:
		return get_orbital_position3(_t0)
## get initial orbital position of the body
var initial_orbital_position: Vector3:
	get: return _init_pos
#endregion

#region SHAPE_PROPS
@export_group("Shape and size")
var _a: float
## the largest semi axis of the orbit
@export var semi_major_axis: float:
	set(val):
		if _a != val:
			_a = val
			emit_changed()
	get:
		return _a

var _b: float:
	get: return _a * sqrt(1 - _e*_e)
## the smallest semi axis of the orbit
var semi_minor_axis: float:
	get:
		return _b

var _e: float
## orbit eccintricity (0 is circle, 1 is parabola)
@export_range(0.0, 1.0, 0.01) var eccentricity: float:
	set(val):
		if _e != val:
			_e = val
			emit_changed()
	get:
		return _e

var _p: float:
	get: return _a * (1 - _e*_e)
## orbit width in the major focus
var semi_parameter: float:
	get:
		return _p

var _ra: float:
	get: return _p / (1 - _e)
## farest orbit point from the major focus
var apoapsis: float:
	get:
		return _ra

var _rp: float:
	get: return _p / (1 + _e)
## closest orbit point from the major focus
var periapsis: float:
	get:
		return _rp
#endregion

#region ROTATION_PROPS
@export_group("Rotation")
var _i: float     # in radians
var _i_deg: float # in degrees
## angle between ascending node and reference plane
@export_range(-180.0, 180.0, 0.1) var inclination_deg: float:
	set(val):
		if _i_deg != val:
			_i_deg = val
			_i = val * PI / 180
			emit_changed()
	get:
		return _i_deg

var _W: float     = 0  # in radians
var _W_deg: float = 90 # in degrees
## angle between ascending node and vernal equinox on reference plane
@export_range(-180.0, 180.0 , 0.1) var longitude_of_the_ascending_node_deg: float = 90:
	set(val):
		if _W_deg != val:
			_W_deg = val
			_W = (val - 90) * PI / 180
			emit_changed()
	get:
		return _W_deg

var _w: float     # in radians
var _w_deg: float # in degrees
## angle between ascending node and periapsis
@export_range(-180.0, 180.0, 0.1) var argument_of_periapsis_deg: float:
	set(val):
		if _w_deg != val:
			_w_deg = val
			_w = val * PI / 180
			emit_changed()
	get:
		return _w_deg
#endregion

#region MOVEMENT_PROPS
@export_group("Movement in time")
var _n_deg: float:
	get: return sqrt(_mu / _a**3) * 180 / PI
var _n: float:
	get: return sqrt(_mu / _a**3)
## mean angular speed (angle per time)
var mean_motion_deg: float:
	get:
		return _n_deg

var _P: float:
	get: return TAU / _n
## time it takes for a body to make one revolution around the center of mass
var orbital_period: float:
	get: return _P

var _mu: float:
	get: return _M * G
## central body mass multiplied by the gravitational constant
var standard_gravitational_parameter: float:
	get:
		return _mu

var _M: float
## mass of the most significant body in the system
@export var central_body_mass: float:
	set(val):
		if _M != val:
			_M = val
			emit_changed()
	get:
		return _M
#endregion

#region POSITION_PROPS
@export_group("Position in time")
var _t0: float
## simulation time
@export var epoch: float:
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
## time where the body is in the periapsis
var time_of_periapsis_passage:
	get: return _T0

var _L0: float     # in radians
var _L0_deg: float # in degrees
## angular displacement of the body, as if the orbit where circular, measured from the vernal equinox
@export_range(0.0, 360.0, 0.1) var mean_longitude_deg: float:
	set (val):
		if _L0_deg != val:
			_L0_deg = val
			_L0 = val * PI / 180
			emit_changed()
	get:
		return _L0_deg
#endregion


## 2d orbit, constructed from points
var points2: PackedVector2Array = []
## 3d orbit, constructed from points
var points3: PackedVector3Array = []


func _init() -> void:
	pass


## constructs orbit from given required params
static func from_params(F1: Vector3, a: float, e: float, i: float, W: float, w: float,
						M: float, t0: float, L0: float) -> Orbit:
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


static func default2d() -> Orbit:
	return Orbit.from_params(Vector3(450, 150, 0), 300, 0.75, 0, 25, 0, 10, 0, 0)


static func default3d() -> Orbit:
	return Orbit.from_params(Vector3(0, 0, 0), 12, 0.7, 0, 90, 0, 10, 95, 0)


func calculate_points2(samples: int) -> void:
	points2.clear()
	var step := 360.0 / samples
	
	for ix in range(samples):
		var theta := ix * step * PI / 180
		var p := Vector2(_a * cos(theta), _b * sin(theta))
		
		p = p.rotated(_W)
		p += Vector2(_C.x, _C.y)
		
		points2.append(p)
	
	points2.append(points2[0])


func calculate_points3(samples: int) -> void:
	points3.clear()
	var step := 360.0 / samples
	
	for ix in range(samples):
		var theta := ix * step * PI / 180
		var p := Vector3(AXIS.x * _a * cos(theta),
						 0,
						 AXIS.z * _b * sin(theta))
		
		p = p.rotated(Z_DIRECTION, _i)
		p = p.rotated(Y_DIRECTION, _W)
		p = p.rotated(X_DIRECTION, _w)
		p += _C
		
		points3.append(p)
	
	points3.append(points3[0])


func get_orbit_plane3_triangles(samples: int) -> PackedVector3Array:
	var verts := PackedVector3Array()
	
	calculate_points3(samples)
	for i in range(points3.size() - 1):
		verts.push_back(points3[i])
		verts.push_back(points3[i + 1])
		verts.push_back(_C)
	
	return verts


## get (L), angular displacement of the body, as if the orbit where circular, 
## measured from the vernal equinox
func get_mean_longitude(time: float) -> float:
	return _L0 + _n * (time - _t0)


## get (M), angular displacement of the body, as if the orbit where circular, 
## measured from the periapsis
func get_mean_anomaly(time: float) -> float:
	var L := get_mean_longitude(time)
	return fmod(L - _w - _W, TAU)


## get (E), angular displacement of the body around auxiliary circle (with radius a), 
## measured from the periapsis
func get_eccentric_anomaly(time: float) -> float:
	var M := get_mean_anomaly(time)
	var E := M
	
	for i in range(10):
		E = E + (M - E + _e * sin(E)) / (1.0 - _e * cos(E))
	
	return E


## get (v), actual angular displacement of the body, measured from the periapsis
func get_true_anomaly(time: float) -> float:
	var E := get_eccentric_anomaly(time)
	var sin_v := (sqrt(1.0 - _e*_e) * sin(E)) / (1.0 - _e * cos(E))
	var cos_v := (cos(E) - _e) / (1.0 - _e * cos(E))
	
	return atan2(sin_v, cos_v)


## get (l), actual angular displacement of the body, measured from the vernal equinox
func get_true_longitude(time: float) -> float:
	var v := get_true_anomaly(time)
	return v + _w + _W


## get (uM), angular displacement of the body, as if the orbit where circular, measured from the ascending node
func get_mean_argument_of_latitude(time: float) -> float:
	var M := get_mean_anomaly(time)
	return M + _W


## get (u), angular displacement of the body, measured from the ascending node
func get_argument_of_latitude(time: float) -> float:
	var v := get_true_anomaly(time)
	return v + _W


func get_orbital_position3(time: float) -> Vector3:
	var v := get_true_anomaly(time)
	var r := _p / (1 + _e * cos(v))
	var p := Vector3(AXIS.x * r * cos(v), 
					 0, 
					 AXIS.z * r * sin(v))
	
	p = p.rotated(Z_DIRECTION, _i)
	p = p.rotated(Y_DIRECTION, _W)
	p = p.rotated(X_DIRECTION, _w)
	p += _F1
	
	return p


func get_ascending_node() -> Vector3:
	var r = _p / (1 + _e * cos(PI / 2))
	var p = Vector3(AXIS.x * r * cos(PI / 2), 
					0, 
					AXIS.z * r * sin(PI / 2))
	
	p = p.rotated(Z_DIRECTION, _i)
	p = p.rotated(Y_DIRECTION, _W)
	p = p.rotated(X_DIRECTION, _w)
	p += _F1
	
	return p
