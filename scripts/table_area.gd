# forge_station.gd
extends Area3D

const ComboHud := preload("res://scenes/UI/combo_hud.tscn")
var SmithableItemScene := preload("res://scenes/smithable_item.tscn")
const SparksEffectScene := preload("res://effects/hit_sparks.tscn")

var player_in_range := false
var player_ref = null
var current_item = null
var interacting := false

# keep a private reference (no groups)
var _combo_hud: CanvasLayer = null

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
		current_item.connect("smithing_completed", Callable(self, "_on_smithing_completed"))

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		player_ref.smithing_item = current_item

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if player_ref:
			player_ref.can_control = true
			player_ref.smithing_item = null
		player_ref = null

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		interact()
	if interacting:
		var hud := _ensure_hud()
		hud.set_progress(current_item.progress)

func interact():
	if current_item.animating_camera or current_item.returning_camera:
		return

	interacting = !interacting
	if interacting:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if current_item: 
			current_item.lock_camera_top_view()
			var hud := _ensure_hud()
			hud.init_progress_bar(current_item.MAX_PROGRESS)
		if player_ref: player_ref.can_control = false
	else:
		if current_item: current_item.return_camera_to_original()
		if player_ref: player_ref.smithing_item = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_camera_locked():
	var hud := _ensure_hud()
	hud.show_hud()
	hud.reset_combo()

	if player_ref:
		player_ref.can_control = false
		current_item.started = true

func _on_camera_returned():
	if _combo_hud and is_instance_valid(_combo_hud):
		_combo_hud.hide_hud()

	if player_ref:
		player_ref.can_control = true
		player_ref.smithing_item = null
		current_item.started = false

func _input(event):
	if player_in_range and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_ref and player_ref.smithing_item and interacting:
			var click_info = get_marker_clicked(player_ref.smithing_item.spawned_decals)
			if click_info.has("marker"):
				spawn_hit_effect(click_info.marker.global_transform.origin)
				# Feed a judgment to HUD (optional)

				var dist: float = float(click_info.distance)
				current_item.progress += _judge_distance(dist)

func _judge_distance(d: float) -> float:
	if d < 8.0: return 5
	if d < 18.0: return 3
	if d < 28.0: return 1
	return 1

func get_marker_clicked(markers: Array) -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera: return {}
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to

	var result = space_state.intersect_ray(query)
	if not result: return {}

	var hit_pos: Vector3 = result.position
	var closest_marker = null
	var closest_dist := 50.0

	for marker in markers:
		var marker_screen_pos = camera.unproject_position(marker.global_transform.origin)
		var hit_screen_pos = camera.unproject_position(hit_pos)
		var dist_2d = marker_screen_pos.distance_to(hit_screen_pos)
		if dist_2d < closest_dist:
			closest_dist = dist_2d
			closest_marker = marker

	if closest_marker:
		return {"marker": closest_marker, "distance": closest_dist}
	return {}

func spawn_hit_effect(hit_position: Vector3):
	var spark_instance = SparksEffectScene.instantiate()
	get_tree().current_scene.add_child(spark_instance)
	spark_instance.global_position = hit_position
	spark_instance.hit()

# ---------- lazy HUD helpers (no groups) ----------
func _ensure_hud() -> CanvasLayer:
	# Reuse existing if valid and still in tree
	if _combo_hud and is_instance_valid(_combo_hud) and _combo_hud.get_tree():
		return _combo_hud

	# Instance fresh
	_combo_hud = ComboHud.instantiate()
	# Add to scene root so CanvasLayer actually overlays
	get_tree().current_scene.add_child(_combo_hud)
	_combo_hud.visible = false
	return _combo_hud
	
func _on_smithing_completed():
	# optional: reward, SFX, etc.
	# auto-exit interaction
	if interacting:
		interacting = false
		if current_item: current_item.return_camera_to_original()
		var hud := _ensure_hud()
		hud.hide_hud()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
