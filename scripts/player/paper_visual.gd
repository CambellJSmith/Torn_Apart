extends Node3D # Controls only the presentation of the flat paper character.
class_name TornPaperVisual # Gives the visual component a strongly typed project-wide class name.

const LEAN_LIMIT: float = 0.08 # Limits how far the paper artwork leans during lateral movement.
const LEAN_SHARPNESS: float = 12.0 # Controls how quickly the visual settles toward its target lean.
const MOTION_EPSILON: float = 0.01 # Filters tiny movement values from visual animation decisions.

@onready var _art_root: Node3D = $art_root # Caches the child that contains all placeholder paper artwork.

var _motion_direction: Vector3 = Vector3.ZERO # Stores player movement used to animate the paper presentation.

func _process(delta: float) -> void: # Updates camera-facing presentation independently from gameplay physics.
	_face_active_camera() # Keeps the flat character readable from the current gameplay camera.
	_apply_motion_lean(delta) # Adds a small movement lean without affecting collision or gameplay state.

func set_motion_direction(direction: Vector3) -> void: # Accepts movement information from the composed player controller.
	_motion_direction = direction # Stores the latest ground-plane movement for visual animation.

func _face_active_camera() -> void: # Rotates the flat character around the vertical axis toward the active camera.
	var camera: Camera3D = get_viewport().get_camera_3d() # Retrieves the camera currently rendering this viewport.
	if camera == null: # Handles frames where no gameplay camera is active yet.
		return # Avoids attempting a look-at operation without a camera target.
	var camera_target: Vector3 = camera.global_position # Starts with the camera's world position as the facing target.
	camera_target.y = global_position.y # Removes vertical tilt so the paper character stays upright on the ground.
	if global_position.distance_squared_to(camera_target) <= MOTION_EPSILON: # Guards against an invalid look-at direction when positions coincide.
		return # Skips rotation when there is no meaningful horizontal direction to the camera.
	look_at(camera_target, Vector3.UP, true) # Points the artwork's front face toward the camera while preserving vertical orientation.

func _apply_motion_lean(delta: float) -> void: # Smoothly leans the artwork to reinforce lateral movement.
	var target_lean: float = 0.0 # Starts from a neutral upright presentation.
	if absf(_motion_direction.x) > MOTION_EPSILON: # Checks whether lateral movement is large enough to animate.
		target_lean = -signf(_motion_direction.x) * LEAN_LIMIT # Chooses a small lean opposite the lateral travel direction.
	var blend_weight: float = 1.0 - exp(-LEAN_SHARPNESS * delta) # Converts sharpness into stable frame-rate-independent smoothing.
	_art_root.rotation.z = lerp_angle(_art_root.rotation.z, target_lean, blend_weight) # Smoothly rotates only the artwork while leaving the gameplay body untouched.
