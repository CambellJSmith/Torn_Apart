extends TornLevelContext # Uses the reusable isolated-level state component.
class_name TornWorld01 # Gives the first level a strongly typed class name.

const FALL_THRESHOLD_Y: float = -3.5 # Defines the first world's void recovery height.
@onready var _picket_fence: TornPicketFence = $picket_fence # Caches the reusable fence component.

func _ready() -> void: # Initializes level state and repeated fence presentation.
	super._ready() # Captures the authored spawn marker in the base component.
	_picket_fence.build(_create_platform_specs()) # Builds fence presentation from typed platform metadata.

func get_fall_threshold_y() -> float: # Supplies the level-specific fall threshold.
	return FALL_THRESHOLD_Y # Returns the authored recovery height.

func _create_platform_specs() -> Array[TornPlatformSpec]: # Creates typed perimeter data matching the static scene cylinders.
	var specs: Array[TornPlatformSpec] = [] # Allocates the small level perimeter list.
	specs.append(TornPlatformSpec.new(Vector2(-3.5, 3.5), 5.6, 0.0)) # Describes the starting cylinder.
	specs.append(TornPlatformSpec.new(Vector2(2.0, 0.5), 5.2, 0.75)) # Describes the central cylinder.
	specs.append(TornPlatformSpec.new(Vector2(-1.0, -5.0), 4.5, 1.5)) # Describes the rear cylinder.
	specs.append(TornPlatformSpec.new(Vector2(6.3, -4.0), 3.8, 0.75)) # Describes the side cylinder.
	return specs # Supplies metadata without generating platform geometry at runtime.
