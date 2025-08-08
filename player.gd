extends CharacterBody3D

@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.1
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@onready var camera_pivot: Camera3D = $Camera3D
var can_control: bool = true
var holded_item: SmithableItem = null
var smithing_item: SmithableItem = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if smithing_item:
			print("Smithing")
			pass

func _unhandled_input(event):
	if not can_control: return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion:
		# Rotate the camera pivot up/down
		camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		# Rotate the whole player left/right
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

func _physics_process(delta):
	if not can_control: return
	
	var input_dir = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x

	# Movement input
	if Input.is_action_pressed("forward"):
		input_dir += forward
	if Input.is_action_pressed("backward"):
		input_dir -= forward
	if Input.is_action_pressed("left"):
		input_dir -= right
	if Input.is_action_pressed("right"):
		input_dir += right

	input_dir = input_dir.normalized()

	# Apply horizontal movement
	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.z * move_speed

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		else:
			velocity.y = 0

	move_and_slide()
