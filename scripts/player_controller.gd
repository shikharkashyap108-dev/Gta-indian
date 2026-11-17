extends CharacterBody3D

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_LOOK_SENSITIVITY: float = 0.003
const MIN_LOOK_SENSITIVITY: float = 0.001
const MAX_LOOK_SENSITIVITY: float = 0.008
const WALK_SPEED: float = 4.5
const RUN_SPEED: float = 7.0
const JUMP_SPEED: float = 5.0
const GRAVITY: float = 9.8

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var desktop_hints: CanvasLayer = $DesktopHints
@onready var settings_readout: Label = $TouchControls/Overlay/SettingsReadout

var _settings: ConfigFile = ConfigFile.new()
var _look_sensitivity: float = DEFAULT_LOOK_SENSITIVITY
var _invert_vertical: bool = false
var _camera_yaw: float = 0.0
var _camera_pitch: float = deg_to_rad(-12.0)
var _touch_move_id: int = -1
var _touch_camera_id: int = -1
var _touch_sprint_id: int = -1
var _touch_move: Vector2 = Vector2.ZERO
var _touch_jump_requested: bool = false

func _ready() -> void:
	_configure_input_map()
	_load_settings()
	spring_arm.add_excluded_object(get_rid())
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

	var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("android")
	touch_controls.visible = is_mobile
	desktop_hints.visible = not is_mobile
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_settings_readout()

func _physics_process(delta: float) -> void:
	var keyboard_input: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)
	var movement_input: Vector2 = (keyboard_input + _touch_move).limit_length(1.0)
	var local_direction: Vector3 = Vector3(movement_input.x, 0.0, movement_input.y)
	var move_direction: Vector3 = camera_pivot.global_transform.basis * local_direction
	move_direction.y = 0.0
	if move_direction.length_squared() > 0.0:
		move_direction = move_direction.normalized()

	var movement_speed: float = WALK_SPEED
	if Input.is_action_pressed("sprint") or _touch_sprint_id != -1:
		movement_speed = RUN_SPEED
	velocity.x = move_direction.x * movement_speed
	velocity.z = move_direction.z * movement_speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") or _touch_jump_requested:
		velocity.y = JUMP_SPEED
	_touch_jump_requested = false
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_apply_look(mouse_motion.relative)
	elif event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		if screen_touch.pressed:
			_handle_touch_start(screen_touch.index, screen_touch.position)
		else:
			_handle_touch_end(screen_touch.index)
	elif event is InputEventScreenDrag:
		var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
		if screen_drag.index == _touch_camera_id:
			_apply_look(screen_drag.relative)
		elif screen_drag.index == _touch_move_id:
			_update_touch_move(screen_drag.position)
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_handle_desktop_key(key_event.keycode)

func _configure_input_map() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_UP)
	_bind_key("move_backward", KEY_S)
	_bind_key("move_backward", KEY_DOWN)
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("jump", KEY_SPACE)

func _bind_key(action_name: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey:
			var existing_key: InputEventKey = existing_event as InputEventKey
			if existing_key.physical_keycode == physical_keycode:
				return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)

func _apply_look(relative: Vector2) -> void:
	_camera_yaw -= relative.x * _look_sensitivity
	var vertical_direction: float = -1.0 if _invert_vertical else 1.0
	_camera_pitch -= relative.y * _look_sensitivity * vertical_direction
	_camera_pitch = clampf(_camera_pitch, deg_to_rad(-55.0), deg_to_rad(20.0))
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _handle_desktop_key(keycode: int) -> void:
	match keycode:
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_BRACKETLEFT, KEY_MINUS:
			_adjust_look_sensitivity(-0.0005)
		KEY_BRACKETRIGHT, KEY_EQUAL:
			_adjust_look_sensitivity(0.0005)
		KEY_I:
			_invert_vertical = not _invert_vertical
			_save_settings()
			_refresh_settings_readout()

func _handle_touch_start(index: int, position: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	if position.y >= screen_size.y * 0.055 and position.y < screen_size.y * 0.22:
		if position.x >= screen_size.x * 0.70 and position.x < screen_size.x * 0.81:
			_adjust_look_sensitivity(-0.0005)
		elif position.x >= screen_size.x * 0.82 and position.x < screen_size.x * 0.91:
			_adjust_look_sensitivity(0.0005)
		elif position.x >= screen_size.x * 0.92:
			_invert_vertical = not _invert_vertical
			_save_settings()
			_refresh_settings_readout()
		return

	if _is_jump_button(position, screen_size):
		_touch_jump_requested = true
	elif _is_sprint_button(position, screen_size):
		_touch_sprint_id = index
	elif _touch_move_id == -1 and _is_joystick_zone(position, screen_size):
		_touch_move_id = index
		_update_touch_move(position)
	elif _touch_camera_id == -1 and position.x >= screen_size.x * 0.40:
		_touch_camera_id = index

func _handle_touch_end(index: int) -> void:
	if index == _touch_move_id:
		_touch_move_id = -1
		_touch_move = Vector2.ZERO
	if index == _touch_camera_id:
		_touch_camera_id = -1
	if index == _touch_sprint_id:
		_touch_sprint_id = -1

func _update_touch_move(position: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(screen_size.x * 0.15, screen_size.y * 0.755)
	var radius: float = minf(screen_size.x, screen_size.y) * 0.15
	_touch_move = ((position - center) / radius).limit_length(1.0)

func _is_joystick_zone(position: Vector2, screen_size: Vector2) -> bool:
	return position.x < screen_size.x * 0.34 and position.y > screen_size.y * 0.45

func _is_sprint_button(position: Vector2, screen_size: Vector2) -> bool:
	return (
		position.x >= screen_size.x * 0.72
		and position.x < screen_size.x * 0.86
		and position.y >= screen_size.y * 0.70
	)

func _is_jump_button(position: Vector2, screen_size: Vector2) -> bool:
	return position.x >= screen_size.x * 0.87 and position.y >= screen_size.y * 0.70

func _adjust_look_sensitivity(amount: float) -> void:
	_look_sensitivity = clampf(
		_look_sensitivity + amount,
		MIN_LOOK_SENSITIVITY,
		MAX_LOOK_SENSITIVITY
	)
	_save_settings()
	_refresh_settings_readout()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var load_error: int = _settings.load(SETTINGS_PATH)
	if load_error != OK:
		push_error("Could not load player settings. Error code: %d" % load_error)
		return

	var sensitivity_value: Variant = _settings.get_value(
		"controls", "look_sensitivity", DEFAULT_LOOK_SENSITIVITY
	)
	if typeof(sensitivity_value) == TYPE_FLOAT or typeof(sensitivity_value) == TYPE_INT:
		_look_sensitivity = clampf(
			float(sensitivity_value), MIN_LOOK_SENSITIVITY, MAX_LOOK_SENSITIVITY
		)
	var invert_value: Variant = _settings.get_value("controls", "invert_vertical", false)
	if typeof(invert_value) == TYPE_BOOL:
		_invert_vertical = invert_value

func _save_settings() -> void:
	_settings.set_value("controls", "look_sensitivity", _look_sensitivity)
	_settings.set_value("controls", "invert_vertical", _invert_vertical)
	var save_error: int = _settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_error("Could not save player settings. Error code: %d" % save_error)

func _refresh_settings_readout() -> void:
	var sensitivity_scale: float = _look_sensitivity / DEFAULT_LOOK_SENSITIVITY
	var vertical_setting: String = "INVERTED" if _invert_vertical else "NORMAL"
	settings_readout.text = "LOOK %.1fx  |  Y: %s" % [sensitivity_scale, vertical_setting]

func _exit_tree() -> void:
	_save_settings()
