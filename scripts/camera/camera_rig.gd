extends Node3D # Follows the player while keeping camera behaviour independent from player movement.
class_name TornCameraRig # Gives the camera rig a strongly typed project-wide class name.

const FOLLOW_SHARPNESS: float = 7.5 # Controls how quickly the rig catches the player position.
const LOOK_HEIGHT: float = 0.9 # Places the camera's focus near the visual center of the paper character.

@onready var _camera: Camera3D = $Camera3D # Caches the camera owned by this rig.

var _target: Node3D = null # Stores the player node followed by the camera rig.

func _ready() -> void: # Resolves the player target once the full main scene has entered the tree.
	_target = get_tree().get_first_node_in_group(&"player") as Node3D # Finds the composed player instance without coupling to a scene path.
	if _target == null: # Detects an invalid scene that has no player group member.
		push_error("camera_rig could not find a node in the player group") # Reports the scene composition problem to the debugger.
		set_process(false) # Stops follow processing because there is no valid target.
		return # Ends camera setup after the composition failure.
	global_position = _get_target_rig_position() # Starts the rig centered on the player to avoid an opening camera slide.
	_aim_camera() # Points the camera at the player's visual center before the first rendered frame.

func _process(delta: float) -> void: # Smoothly follows the player each rendered frame.
	var target_position: Vector3 = _get_target_rig_position() # Calculates the desired rig position from the player's current location.
	var blend_weight: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta) # Converts follow sharpness into stable frame-rate-independent smoothing.
	global_position = global_position.lerp(target_position, blend_weight) # Smoothly catches the player's horizontal position.
	_aim_camera() # Keeps the camera centered on the player while the rig is catching up.

func _get_target_rig_position() -> Vector3: # Converts the player position into a ground-plane rig anchor.
	return Vector3(_target.global_position.x, 0.0, _target.global_position.z) # Follows horizontal travel without inheriting jump height.

func _aim_camera() -> void: # Points the camera toward the player's upper body for consistent framing.
	var look_target: Vector3 = _target.global_position + Vector3.UP * LOOK_HEIGHT # Builds the world-space camera focus point.
	_camera.look_at(look_target, Vector3.UP) # Rotates the camera toward the focus point while keeping a stable vertical axis.
