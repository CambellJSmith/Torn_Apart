extends Node3D # Owns level-specific slime placement without coupling enemy spawning to the main scene bootstrap script.

const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn") # Loads the reusable slime gameplay scene once for all level variants.
const GREEN_TEXTURE_PATH: String = "res://assets/enemies/slime_green.png" # Defines where the green slime artwork should be dropped into the project.
const YELLOW_TEXTURE_PATH: String = "res://assets/enemies/slime_yellow.png" # Defines where the yellow slime artwork should be dropped into the project.
const RED_TEXTURE_PATH: String = "res://assets/enemies/slime_red.png" # Defines where the red slime artwork should be dropped into the project.
const GREEN_SPAWN_POSITION: Vector3 = Vector3(1.6, 0.80, 0.3) # Places the green enemy on the raised central cylinder.
const YELLOW_SPAWN_POSITION: Vector3 = Vector3(-1.0, 1.55, -5.0) # Places the yellow enemy on the highest rear cylinder.
const RED_SPAWN_POSITION: Vector3 = Vector3(6.3, 0.80, -4.0) # Places the red enemy on the raised side cylinder.

func _ready() -> void: # Creates the three configured slime variants when their owning level becomes ready.
	_spawn_slime(&"green_slime", GREEN_TEXTURE_PATH, GREEN_SPAWN_POSITION) # Creates the green slime instance with its expected artwork path.
	_spawn_slime(&"yellow_slime", YELLOW_TEXTURE_PATH, YELLOW_SPAWN_POSITION) # Creates the yellow slime instance with its expected artwork path.
	_spawn_slime(&"red_slime", RED_TEXTURE_PATH, RED_SPAWN_POSITION) # Creates the red slime instance with its expected artwork path.

func _spawn_slime(slime_name: StringName, texture_path: String, spawn_position: Vector3) -> void: # Instantiates and configures one reusable slime enemy for the current level.
	var slime: TornSlimeEnemy = SLIME_SCENE.instantiate() as TornSlimeEnemy # Creates the typed enemy instance from the shared scene resource.
	if slime == null: # Detects an invalid scene root before attempting configuration.
		push_error("slime_enemy.tscn must instantiate TornSlimeEnemy") # Reports a broken enemy scene composition immediately.
		return # Prevents null access when the enemy scene no longer matches its expected type.
	slime.name = slime_name # Gives each level enemy a stable descriptive scene-tree name.
	slime.position = spawn_position # Places the slime at its authored location on the current world's cylinder layout.
	slime.configure(texture_path) # Supplies the intentionally externalized sprite path before the enemy enters the tree.
	add_child(slime) # Adds the fully configured enemy to the owning isolated level.
