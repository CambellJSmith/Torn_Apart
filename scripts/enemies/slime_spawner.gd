extends Node3D # Owns prototype slime placement without coupling enemy spawning to the main scene bootstrap script.

const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn") # Loads the reusable slime gameplay scene once for all prototype variants.
const GREEN_TEXTURE_PATH: String = "res://assets/enemies/slime_green.png" # Defines where the green slime artwork should be dropped into the project.
const YELLOW_TEXTURE_PATH: String = "res://assets/enemies/slime_yellow.png" # Defines where the yellow slime artwork should be dropped into the project.
const RED_TEXTURE_PATH: String = "res://assets/enemies/slime_red.png" # Defines where the red slime artwork should be dropped into the project.
const GREEN_SPAWN_POSITION: Vector3 = Vector3(-5.0, 0.05, 1.0) # Places the green prototype enemy in the playable room.
const YELLOW_SPAWN_POSITION: Vector3 = Vector3(4.5, 0.05, 1.5) # Places the yellow prototype enemy in the playable room.
const RED_SPAWN_POSITION: Vector3 = Vector3(0.0, 0.05, -4.5) # Places the red prototype enemy deeper into the playable room.

func _ready() -> void: # Creates the three configured slime variants when the prototype room becomes ready.
	_spawn_slime(&"green_slime", GREEN_TEXTURE_PATH, GREEN_SPAWN_POSITION) # Creates the green slime instance with its expected artwork path.
	_spawn_slime(&"yellow_slime", YELLOW_TEXTURE_PATH, YELLOW_SPAWN_POSITION) # Creates the yellow slime instance with its expected artwork path.
	_spawn_slime(&"red_slime", RED_TEXTURE_PATH, RED_SPAWN_POSITION) # Creates the red slime instance with its expected artwork path.

func _spawn_slime(slime_name: StringName, texture_path: String, spawn_position: Vector3) -> void: # Instantiates and configures one reusable slime enemy.
	var slime: TornSlimeEnemy = SLIME_SCENE.instantiate() as TornSlimeEnemy # Creates the typed enemy instance from the shared scene resource.
	if slime == null: # Detects an invalid scene root before attempting configuration.
		push_error("slime_enemy.tscn must instantiate TornSlimeEnemy") # Reports a broken enemy scene composition immediately.
		return # Prevents null access when the enemy scene no longer matches its expected type.
	slime.name = slime_name # Gives each prototype enemy a stable descriptive scene-tree name.
	slime.position = spawn_position # Places the slime at its authored prototype-room location.
	slime.configure(texture_path) # Supplies the intentionally externalized sprite path before the enemy enters the tree.
	add_child(slime) # Adds the fully configured enemy to the live prototype room.
