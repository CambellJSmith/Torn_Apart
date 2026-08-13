extends RefCounted # Stores one circular platform definition used by level-adjacent systems such as fence generation.
class_name TornPlatformSpec # Gives platform layout data a strongly typed project-wide class name.

var center: Vector2 # Stores the platform center on the world's XZ ground plane.
var radius: float # Stores the platform's horizontal radius for perimeter calculations.
var top_height: float # Stores the walkable surface height used by fence and traversal systems.

func _init(center_value: Vector2, radius_value: float, top_height_value: float) -> void: # Creates one named platform specification without relying on packed Vector4 field conventions.
	center = center_value # Stores the authored XZ center in an explicit named field.
	radius = radius_value # Stores the authored platform radius in an explicit named field.
	top_height = top_height_value # Stores the authored walkable height in an explicit named field.
