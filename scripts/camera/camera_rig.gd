extends Node3D # Follows the player while keeping camera behaviour independent from player movement.
class_name TornCameraRig # Gives the camera rig a strongly typed project-wide class name.

const FOLLOW_SHARPNESS: float = 7.5 # Controls how quickly the rig catches the player position.
const LOOK_HEIGHT: float = 0.9 # Places the camera's focus near the visual center of the paper character.

@onready var _camera: Camera3D = $Camera3D # Caches the camera owned by this rig.

var _target: Node3D = null # Stores the player node followed by the camera rig.

func _ready() -> void: # Resolves the player target and configures manual interpolation before rendered-frame camera updates begin.
	_target = get_tree().get_first_node_in_group(&"player") as Node3D # Finds the composed player instance without coupling to a scene path.
	if _target == null: # Detects an invalid scene that has no player group member.
		push_error("camera_rig could not find a node in the player group") # Reports the scene composition problem to the debugger.
		set_process(false) # Stops follow processing because there is no valid target.
		return # Ends camera setup after the composition failure.
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF) # Disables automatic interpolation because this rig performs camera interpolation manually each rendered frame.
	var initial_target_position: Vector3 = _target.global_position # Reads the authored target position before rendered-frame interpolation is needed.
	global_position = _get_target_rig_position(initial_target_position) # Starts the rig centered on the player to avoid an opening camera slide.
	_aim_camera(initial_target_position) # Points the camera at the player's visual center before the first rendered frame.

func _process(delta: float) -> void: # Smoothly follows the player's interpolated render position each rendered frame.
	var interpolated_target_transform: Transform3D = _target.get_global_transform_interpolated() # Reads the same interpolated player transform used for rendering between fixed physics ticks.
	var interpolated_target_position: Vector3 = interpolated_target_transform.origin # Extracts the smooth world-space player position once for both camera translation and aiming.
	var target_position: Vector3 = _get_target_rig_position(interpolated_target_position) # Calculates the desired rig position from the interpolated player location.
	var blend_weight: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta) # Converts follow sharpness into stable frame-rate-independent smoothing.
	global_position = global_position.lerp(target_position, blend_weight) # Smoothly catches the player's horizontal render position without stepping at physics frequency.
	_aim_camera(interpolated_target_position) # Keeps camera orientation synchronized with the same interpolated position used for follow movement.

func _get_target_rig_position(target_position: Vector3) -> Vector3: # Converts one interpolated player position into the camera rig's ground-plane anchor.
	return Vector3(target_position.x, 0.0, target_position.z) # Follows horizontal travel without inheriting jump height.

func _aim_camera(target_position: Vector3) -> void: # Points the camera toward the interpolated player's upper body for consistent smooth framing.
	var look_target: Vector3 = target_position + Vector3.UP * LOOK_HEIGHT # Builds the world-space camera focus point from the same smooth target position used by the rig.
	_camera.look_at(look_target, Vector3.UP) # Rotates the camera toward the focus point while keeping a stable vertical axis.
