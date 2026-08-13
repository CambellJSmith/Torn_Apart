extends Node3D # Follows the player while keeping camera behaviour independent from player movement.
class_name TornCameraRig # Gives the camera rig a strongly typed project-wide class name.

const FOLLOW_SHARPNESS: float = 7.5 # Controls how quickly the rig catches the player position.
const LOOK_HEIGHT: float = 0.9 # Places the camera's focus near the visual center of the paper character.
@onready var _camera: Camera3D = $Camera3D # Caches the camera owned by this rig.
var _target: TornPlayerController = null # Stores the explicitly composed player target.
var _level: TornLevelContext = null # Stores the active level that owns camera composition bounds.

func _ready() -> void: # Prepares manual interpolation while waiting for main-scene composition.
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF) # Keeps interpolation manual for this rendered-frame camera rig.
	set_process(false) # Prevents camera updates before dependencies are valid.

func configure(target: TornPlayerController, level: TornLevelContext) -> void: # Supplies player and active level dependencies explicitly.
	_target = target # Stores the player without a global group lookup.
	_level = level # Stores the level used for camera bounds.
	var initial_position: Vector3 = _target.global_position # Reads the player's authored spawn.
	global_position = _get_target_rig_position(initial_position) # Starts at the clamped player anchor.
	_aim_camera(initial_position) # Aims before the first rendered update.
	set_process(true) # Enables smooth following after composition.

func _process(delta: float) -> void: # Smoothly follows the player's interpolated render position.
	var target_transform: Transform3D = _target.get_global_transform_interpolated() # Reads the render-interpolated player transform.
	var target_position: Vector3 = target_transform.origin # Extracts its smooth world position.
	var desired_position: Vector3 = _get_target_rig_position(target_position) # Calculates the level-clamped rig anchor.
	var blend_weight: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta) # Converts sharpness into stable frame-rate-independent smoothing.
	global_position = global_position.lerp(desired_position, blend_weight) # Smoothly catches the clamped anchor.
	_aim_camera(target_position) # Aims at the same interpolated player position.

func _get_target_rig_position(target_position: Vector3) -> Vector3: # Converts player position into a composition-safe ground-plane anchor.
	var desired_anchor: Vector3 = Vector3(target_position.x, 0.0, target_position.z) # Ignores jump and platform height for rig translation.
	if _level == null: # Keeps isolated camera tests usable without a level.
		return desired_anchor # Returns the normal unclamped anchor.
	return _level.clamp_camera_anchor(desired_anchor) # Applies the active level's editor-authored XZ bounds.

func _aim_camera(target_position: Vector3) -> void: # Points the camera toward the player's visual center.
	var look_target: Vector3 = target_position + Vector3.UP * LOOK_HEIGHT # Builds the world-space focus point.
	_camera.look_at(look_target, Vector3.UP) # Rotates toward the player with a stable up axis.
