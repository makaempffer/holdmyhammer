extends Area3D

var player_in_range = false
var player_ref = null
var current_item = null
var interacting: bool = false

var SmithableItemScene = preload("res://scenes/smithable_item.tscn")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	current_item = SmithableItemScene.instantiate()
	add_child(current_item)
	var item = CraftedItem.new("Iron Sword", "Sword", 1, 1, 1)
	current_item.set_crafted_item(item)
	current_item.global_transform.origin = global_transform.origin + Vector3(0.8, 0, 0)
	current_item.rotation_degrees = Vector3(0, -90, 0)
	if current_item:
		current_item.connect("camera_locked", Callable(self, "_on_camera_locked"))
		current_item.connect("camera_returned", Callable(self, "_on_camera_returned"))

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		player_ref.smithing_item = current_item
		print(current_item.crafted_item.name)

func _on_body_exited(body):
	if body.is_in_group("player"):
		# Safeguard
		player_in_range = false
		player_ref.can_control = true
		player_ref.smithing_item = null
		player_ref = null

func _process(delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		interact()

func interact():
	print("Interacted with:", name)
	interacting = not interacting
	if interacting:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if current_item:
			current_item.lock_camera_top_view()
		if player_ref:
			player_ref.can_control = false
				
	else:
		if current_item:
			current_item.return_camera_to_original()
		player_ref.smithing_item = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_camera_locked():
	# Called when camera finished moving to top view
	if player_ref:
		player_ref.can_control = false
		current_item.started = true

func _on_camera_returned():
	# Called when camera finished moving back
	if player_ref:
		player_ref.can_control = true
		player_ref.smithing_item = null
		current_item.started = false
	
func _input(event):
	if player_in_range and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_ref and player_ref.smithing_item:
			var click_info = get_marker_clicked(player_ref.smithing_item.spawned_decals)
			if click_info.has("marker"):
				print("Clicked marker:", click_info.marker)
				print("Distance from center:", click_info.distance)
				# Handle hit logic here
				
func get_marker_clicked(markers: Array) -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return {}
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	
	var result = space_state.intersect_ray(query)
	if not result:
		return {}
	
	var hit_pos = result.position
	
	var closest_marker = null
	var closest_dist = 50.0 # big initial value (in screen pixels)
	
	for marker in markers:
		# Project 3D positions to 2D screen coordinates
		var marker_screen_pos = camera.unproject_position(marker.global_transform.origin)
		var hit_screen_pos = camera.unproject_position(hit_pos)
		
		# Calculate 2D distance in pixels
		var dist_2d = marker_screen_pos.distance_to(hit_screen_pos)
		
		if dist_2d < closest_dist:
			closest_dist = dist_2d
			closest_marker = marker
	
	if closest_marker:
		return {
			"marker": closest_marker,
			"distance": closest_dist
		}
	return {}
