## Free Camera 3D allows you to easily control camera in 3D space.[br]
## HOLD RMB - look around[br]
## W/S, A/D, SPACE/CTRL - move around[br]
## SHIFT/ALT - change movement speed
class_name FreeCam
extends Camera3D

@export_range(10, 5.0, 0.1)   var shift_multiplier:  float = 2.5
@export_range(0.1, 1.0, 0.01) var alt_multiplier:    float = 0.4
@export_range(0.1, 1.0, 0.01) var mouse_sensetivity: float = 0.25

const ACCELERATION: float =  30.0
const DECELERATION: float = -10.0
const SPEED:        float =  4.0

var _velocity  := Vector3.ZERO
var _direction := Vector3.FORWARD
var _mouse_pos := Vector2.ZERO
var _total_pitch: float = 0.0

var _inp_right    := false
var _inp_left     := false
var _inp_forward  := false
var _inp_backward := false
var _inp_up       := false
var _inp_down     := false
var _inp_sprint   := false
var _inp_creep    := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.relative
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed \
							   else Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventKey:
		match event.keycode:
			KEY_A:     _inp_left     = event.pressed
			KEY_D:     _inp_right    = event.pressed
			
			KEY_W:     _inp_forward  = event.pressed
			KEY_S:     _inp_backward = event.pressed
			
			KEY_SPACE: _inp_up       = event.pressed
			KEY_CTRL:  _inp_down     = event.pressed
			
			KEY_SHIFT: _inp_sprint   = event.pressed
			KEY_ALT:   _inp_creep    = event.pressed


func _process(delta: float) -> void:
	_update_mouselook()
	_update_movement(delta)


func _update_movement(delta: float) -> void:
	_direction = Vector3(
		(_inp_right as float)    - (_inp_left as float),
		(_inp_up as float)       - (_inp_down as float),
		(_inp_backward as float) - (_inp_forward as float)
	)
	
	var offset := _direction.normalized() * ACCELERATION * SPEED * delta \
				+ _velocity.normalized()  * DECELERATION * SPEED * delta
	
	var speed_multiplier := 1.0
	if _inp_sprint: speed_multiplier *= shift_multiplier
	if _inp_creep:  speed_multiplier *= alt_multiplier
	
	if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
		_velocity = Vector3.ZERO
	else:
		_velocity = (_velocity + offset).clamp(Vector3(-SPEED, -SPEED, -SPEED), Vector3(SPEED, SPEED, SPEED))
	
	translate(_velocity * delta * speed_multiplier)


func _update_mouselook() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var yaw   := _mouse_pos.x * mouse_sensetivity
		var pitch := _mouse_pos.y * mouse_sensetivity
		_mouse_pos = Vector2.ZERO
		
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch
		
		rotate_y(deg_to_rad(-yaw))
		rotate_object_local(Vector3.RIGHT, deg_to_rad(-pitch))
