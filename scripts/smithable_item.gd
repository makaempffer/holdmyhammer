extends Node3D
class_name SmithableItem

# Signals - Camera
signal camera_locked
signal camera_returned

var crafted_item: CraftedItem = null
var spawned_decals = []
var started: bool = false
var completed: bool = false
const MARKER_SPAWN_DELAY = 3
var time_passed = 0

# Camera animation vars
var current_camera: Camera3D = null
var camera_original_transform: Transform3D
var camera_target_transform: Transform3D
var camera_anim_time: float = 0
var camera_anim_duration: float = 1.0
var animating_camera: bool = false
var returning_camera: bool = false
var hit_marker_texture = preload("res://assets/textures/hit_marker.png")

func set_crafted_item(item: CraftedItem) -> void:
	crafted_item = item
	_update_mesh()

func _update_mesh() -> void:
	if not crafted_item:
		return
	
	var mesh_resource: Mesh = null
	
	match crafted_item.name:
		"Iron Sword":
			mesh_resource = preload("res://assets/models/sword_base.obj")
		_:
			mesh_resource = preload("res://assets/models/sword_base.obj")
	
	$MeshInstance3D.mesh = mesh_resource

func _process(delta: float) -> void:
	for decal in spawned_decals:
		decal.scale -= Vector3.ONE * 0.5 * delta
		if decal.scale.x <= 0.1:
			decal.queue_free()
			spawned_decals.erase(decal)
	
	if completed: return
	
	# Spawn markers periodically
	time_passed += delta
	if time_passed >= MARKER_SPAWN_DELAY and started:
		var random_pos_x = randf_range(-0.5, 0.6)
		var random_pos_z = randf_range(-0.15, 0.15)
		_spawn_hit_marker(Vector3(random_pos_x, 0.2, random_pos_z))
		time_passed = 0

	# Animate camera if locking/unlocking
	if animating_camera:
		camera_anim_time += delta
		var t = clamp(camera_anim_time / camera_anim_duration, 0, 1)
		var smooth_t = t * t * (3 - 2 * t) # smoothstep
		current_camera.global_transform = camera_original_transform.interpolate_with(camera_target_transform, smooth_t)
		if t >= 1:
			animating_camera = false
			emit_signal("camera_locked")
	
	if returning_camera:
		camera_anim_time += delta
		var t = clamp(camera_anim_time / camera_anim_duration, 0, 1)
		var smooth_t = t * t * (3 - 2 * t) # smoothstep
		current_camera.global_transform = camera_target_transform.interpolate_with(camera_original_transform, smooth_t)
		if t >= 1:
			emit_signal("camera_returned")
			returning_camera = false

func _spawn_hit_marker(local_pos: Vector3, local_rotation: Vector3 = Vector3.ZERO) -> void:
	var marker = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(0.2, 0.2)  # Adjust size as needed
	marker.mesh = plane_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = hit_marker_texture
	mat.transparency = 3  # ALPHA_DISCARD
	mat.flags_unshaded = true
	mat.flags_transparent = true
	
	marker.material_override = mat
	
	marker.position = local_pos + Vector3(0, 0, 0.05)
	marker.rotation_degrees = local_rotation
	
	$MeshInstance3D.add_child(marker)
	spawned_decals.append(marker)



func lock_camera_top_view():
	current_camera = get_viewport().get_camera_3d()
	if current_camera == null:
		print("No active camera found!")
		return
	camera_original_transform = current_camera.global_transform
	
	var top_position = global_transform.origin + Vector3(0, 1, 0)
	var look_dir = Vector3.DOWN
	var up_dir = Vector3.DOWN
	var basis = Basis().looking_at(look_dir, up_dir)
	camera_target_transform = Transform3D(basis, top_position)
	
	camera_anim_time = 0
	animating_camera = true
	returning_camera = false


func return_camera_to_original():
	if current_camera == null:
		print("No camera to return to")
		return
	camera_anim_time = 0
	animating_camera = false
	returning_camera = true
