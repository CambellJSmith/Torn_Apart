extends Marker3D # Provides an editor-visible recovery position without adding runtime rendering or physics geometry.
class_name TornRespawnMarker # Gives reusable recovery markers a strongly typed project-wide class name.

const ACTIVATION_RADIUS_SQUARED: float = 2.25 # Defines the ground-plane proximity required for the player to activate this recovery point.

func is_reached(player_position: Vector3) -> bool: # Reports whether the player is close enough on the ground plane to make this recovery marker active.
	var offset: Vector3 = player_position - global_position # Measures the world-space offset from the recovery marker to the player.
	offset.y = 0.0 # Ignores vertical separation so small jumps do not prevent recovery-point activation.
	return offset.length_squared() <= ACTIVATION_RADIUS_SQUARED # Uses squared distance to avoid an unnecessary square root every physics tick.
