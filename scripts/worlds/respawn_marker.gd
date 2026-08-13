extends Marker3D # Provides an editor-visible recovery position without adding runtime rendering or physics geometry.
class_name TornRespawnMarker # Gives reusable recovery markers a strongly typed project-wide class name.

const ACTIVATION_RADIUS_SQUARED: float = 2.25 # Defines the ground-plane proximity required for the player to activate this recovery point.
const ACTIVATION_MAX_HEIGHT_DIFFERENCE: float = 0.45 # Prevents an overlapping lower island from activating a higher recovery point.

func is_reached(player_position: Vector3) -> bool: # Reports whether the player is close enough and on approximately the same platform height.
	var offset: Vector3 = player_position - global_position # Measures the world-space offset from the recovery marker to the player.
	if absf(offset.y) > ACTIVATION_MAX_HEIGHT_DIFFERENCE: # Rejects nearby XZ positions that belong to a different stepped level.
		return false # Keeps the marker inactive until the player actually reaches its surface.
	offset.y = 0.0 # Removes the accepted small height difference before ground-plane testing.
	return offset.length_squared() <= ACTIVATION_RADIUS_SQUARED # Uses squared distance to avoid an unnecessary square root every physics tick.
