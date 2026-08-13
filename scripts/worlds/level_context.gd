extends Node3D # Owns reusable isolated-level state while leaving geometry and content in each level scene.
class_name TornLevelContext # Gives active level scenes a strongly typed project-wide base class.

@onready var _spawn_point: Marker3D = $spawn_point # Caches the editor-authored initial player spawn marker.
@onready var _recovery_points: Node3D = $recovery_points # Caches the container holding optional reusable recovery markers.
@onready var _camera_bounds_min: Marker3D = $camera_bounds_min # Caches the editor-authored minimum camera anchor bounds.
@onready var _camera_bounds_max: Marker3D = $camera_bounds_max # Caches the editor-authored maximum camera anchor bounds.

var _active_recovery_point: TornRespawnMarker = null # Stores the most recently reached recovery marker when the level contains one.
var _active_respawn_transform: Transform3D = Transform3D.IDENTITY # Stores the transform used for fall recovery and defeat recovery.

func _ready() -> void: # Initializes reusable level state from editor-authored marker nodes.
	_active_respawn_transform = _spawn_point.global_transform # Starts the level using its explicit spawn marker as the active recovery point.

func update_recovery_point(player_position: Vector3) -> void: # Checks nearby authored recovery markers without using gameplay signals.
	for child: Node in _recovery_points.get_children(): # Visits only the small set of recovery points owned by the current isolated level.
		if child is not TornRespawnMarker: # Ignores unrelated helper nodes if the recovery container gains other children later.
			continue # Skips directly to the next child when the node is not a reusable recovery marker.
		var recovery_point: TornRespawnMarker = child as TornRespawnMarker # Narrows the child to the reusable marker type for strongly typed access.
		if recovery_point == _active_recovery_point: # Avoids repeating work for the recovery point that is already active.
			continue # Keeps scanning in case another nearby recovery point has just been reached.
		if not recovery_point.is_reached(player_position): # Rejects recovery points outside their small activation radius.
			continue # Continues scanning the remaining authored markers.
		_active_recovery_point = recovery_point # Stores the newly reached marker as the active level recovery point.
		_active_respawn_transform = recovery_point.global_transform # Captures its current world transform for future fall or defeat recovery.
		return # Stops after activating the first nearby marker because isolated level recovery points should not overlap.

func get_respawn_transform() -> Transform3D: # Returns the currently active recovery transform for the composed player controller.
	return _active_respawn_transform # Exposes level-owned spawn state without allowing the player to mutate it directly.

func get_fall_threshold_y() -> float: # Provides a conservative default void threshold that individual levels can override.
	return -10.0 # Keeps generic levels safe until they define a tighter threshold below their authored geometry.

func clamp_camera_anchor(anchor: Vector3) -> Vector3: # Constrains the camera rig anchor to the level's editor-authored XZ composition bounds.
	var minimum_position: Vector3 = _camera_bounds_min.global_position # Reads the world-space minimum marker once for this clamp operation.
	var maximum_position: Vector3 = _camera_bounds_max.global_position # Reads the world-space maximum marker once for this clamp operation.
	anchor.x = clampf(anchor.x, minf(minimum_position.x, maximum_position.x), maxf(minimum_position.x, maximum_position.x)) # Keeps horizontal camera travel inside the authored X range.
	anchor.z = clampf(anchor.z, minf(minimum_position.z, maximum_position.z), maxf(minimum_position.z, maximum_position.z)) # Keeps depth camera travel inside the authored Z range.
	anchor.y = 0.0 # Keeps the existing ground-plane camera rig behaviour independent from jump and platform height.
	return anchor # Supplies the composition-safe anchor back to the camera rig.
