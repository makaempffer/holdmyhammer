extends Area3D

const ComboHud := preload("res://scenes/UI/combo_hud.tscn")
var SmithableItemScene := preload("res://scenes/smithable_item.tscn")
const SparksEffectScene := preload("res://effects/hit_sparks.tscn")

@onready var rest_socket: Node3D = $RestSocket

var player_in_range := false
var player_ref: Node = null
var current_item: Node3D = null
var interacting := false

# keep a private reference (no groups)
var _combo_hud: CanvasLayer = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	current_item = SmithableItemScene.instantiate()
	_place_item_on_table(current_item)

	# Example data for the item
	if "set_crafted_item" in current_item:
		var item = CraftedItem.new("Iron Sword", "Sword", 1, 1, 1)
		current_item.set_crafted_item(item)

	# Signals from the smithable item (guard if method/signal exists)
	if current_item:
		if current_item.has_signal("camera_locked"):
			current_item.connect("camera_locked", Callable(self, "_on_camera_locked"))
		if current_item.has_signal("camera_returned"):
			current_item.connect("camera_returned", Callable(self, "_on_camera_returned"))
		if current_item.has_signal("smithing_completed"):
			current_item.connect("smithing_completed", Callable(self, "_on_smithing_completed"))

func _place_item_on_table(item: Node3D):
	# Parent to forge and snap to the rest socket
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	item.global_transform = rest_socket.global_transform
	# Keep your visual orientation (adjust if your mesh needs it)
	item.rotation_degrees = Vector3(0, -90, 0)
	# Optional: re-enable physics/collision when on table (if your item implements it)
	if "set_held" in item:
		item.set_held(false)
	current_item = item

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
	if player_in_range and Input.is_action_just_pressed("grab"):
		grab()

	if interacting and current_item and "progress" in current_item:
		var hud := _ensure_hud()
		hud.set_progress(current_item.progress)

func interact():
	# Don’t allow interaction if the table has no item (it’s in the player’s hands)
	if current_item == null:
		return

	if ("animating_camera" in current_item and current_item.animating_camera) \
		or ("returning_camera" in current_item and current_item.returning_camera):
		return

	interacting = !interacting
	if interacting:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if current_item:
			if "lock_camera_top_view" in current_item:
				current_item.lock_camera_top_view()
			var hud := _ensure_hud()
			if "MAX_PROGRESS" in current_item:
				hud.init_progress_bar(current_item.MAX_PROGRESS)
		if player_ref:
			player_ref.can_control = false
	else:
		if current_item and "return_camera_to_original" in current_item:
			current_item.return_camera_to_original()
		if player_ref:
			player_ref.smithing_item = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func grab():
	if not player_in_range or not player_ref:
		return

	# Block grabbing while the table item is animating its camera
	if current_item and (
		("animating_camera" in current_item and current_item.animating_camera) or
		("returning_camera" in current_item and current_item.returning_camera)
	):
		return

	# A) Table has an item and player has free hands -> pick it up
	if current_item and player_ref.holded_item == null:
		if "grab_smithing_item" in player_ref:
			player_ref.grab_smithing_item(current_item)
			# Optional: mark held on the item
			if "set_held" in current_item:
				current_item.set_held(true)
		player_ref.smithing_item = player_ref.holded_item
		current_item = null
		return

	# B) Player is holding something and table is empty -> put it back
	if player_ref.holded_item and current_item == null:
		var item = null
		if "release_smithing_item" in player_ref:
			item = player_ref.release_smithing_item()
		else:
			# Fallback if release method missing
			item = player_ref.holded_item
			player_ref.holded_item = null
		if item:
			_place_item_on_table(item)
			player_ref.smithing_item = current_item
		return

func _on_camera_locked():
	var hud := _ensure_hud()
	hud.show_hud()
	hud.reset_combo()

	if player_ref:
		player_ref.can_control = false
	if current_item and "started" in current_item:
		current_item.started = true

func _on_camera_returned():
	if _combo_hud and is_instance_valid(_combo_hud):
		_combo_hud.hide_hud()

	if player_ref:
		player_ref.can_control = true
		player_ref.smithing_item = null
	if current_item and "started" in current_item:
		current_item.started = false

func _input(event):
	if player_in_range and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if player_ref and player_ref.smithing_item and interacting:
			# Use the table item (not the held one) while interacting
			var target_item = player_ref.smithing_item
			if not target_item:
				return
			if "spawned_decals" not in target_item:
				return
			var markers = target_item.spawned_decals
			for i in range(markers.size() - 1, -1, -1):
				var click_info = get_marker_clicked([markers[i]])
				if click_info.has("marker"):
					spawn_hit_effect(markers[i].global_transform.origin)
					if current_item and "progress" in current_item:
						current_item.progress += _judge_distance(float(click_info.distance))
					markers[i].queue_free()
					markers.remove_at(i)
					break

func _judge_distance(d: float) -> float:
	if d < 8.0: return 10
	if d < 18.0: return 9
	if d < 28.0: return 7
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
	if "hit" in spark_instance:
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
		if current_item and "return_camera_to_original" in current_item:
			current_item.return_camera_to_original()
		var hud := _ensure_hud()
		hud.hide_hud()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree():
	# Safety: clear player binding if forge is removed
	if player_ref and is_instance_valid(player_ref):
		player_ref.smithing_item = null
