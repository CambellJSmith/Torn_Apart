extends CharacterBody3D # Uses controlled 3D movement and collision for a grounded slime enemy.
class_name TornSlimeEnemy # Gives slime enemies a strongly typed project-wide class name.

const MOVE_SPEED: float = 1.8 # Controls the slime's horizontal chase speed.
const GROUND_ACCELERATION: float = 12.0 # Controls how quickly the slime reaches or leaves its requested speed.
const CHASE_DISTANCE_SQUARED: float = 36.0 # Limits active chasing without requiring a square root for distant targets.
const MOVEMENT_EPSILON_SQUARED: float = 0.0001 # Filters negligible target offsets from movement calculations.
const STOMP_PROTECTION_HEIGHT: float = 0.35 # Prevents enemy-side contact damage from beating a descending stomp check.
const SQUASH_DURATION: float = 0.18 # Controls how long the squash death presentation remains visible.
const SQUASH_HORIZONTAL_SCALE: float = 1.22 # Controls the sideways spread used by the squash presentation.
const SQUASH_VERTICAL_SCALE: float = 0.16 # Controls the vertical compression used by the squash presentation.
const SQUASH_DROP_DISTANCE: float = 0.32 # Keeps the compressed sprite visually anchored near the floor.

@onready var _sprite: Sprite3D = $sprite # Caches the billboard sprite used for the slime artwork and squash presentation.

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) # Reads the project gravity once for grounded enemy movement.
var _target: TornPlayerController = null # Stores the player instance chased and damaged by this slime.
var _texture_path: String = "" # Stores the configured sprite path without creating a hard scene dependency on an uncommitted image.
var _is_dead: bool = false # Stores whether stomp handling has disabled this enemy.
var _squash_elapsed: float = 0.0 # Tracks progress through the short squash death presentation.
var _initial_sprite_scale: Vector3 = Vector3.ONE # Stores the original sprite scale so squashing remains relative to scene setup.
var _initial_sprite_position: Vector3 = Vector3.ZERO # Stores the original sprite position so squashing stays floor-aligned.

func configure(texture_path: String) -> void: # Supplies the sprite path before or after the enemy enters the scene tree.
	_texture_path = texture_path # Stores the path for deferred resource loading after the PNG exists in the project.
	if is_node_ready(): # Detects runtime reconfiguration after the scene has already completed setup.
		_apply_configured_texture() # Refreshes the sprite immediately for late configuration.

func _ready() -> void: # Resolves composed runtime dependencies and applies the configured visual resource.
	_target = get_tree().get_first_node_in_group(&"player") as TornPlayerController # Finds the player without coupling the enemy to a scene path.
	_initial_sprite_scale = _sprite.scale # Captures the authored scale before any squash presentation changes it.
	_initial_sprite_position = _sprite.position # Captures the authored visual anchor before any squash presentation changes it.
	_apply_configured_texture() # Loads the optional enemy PNG only after the scene is ready.

func _physics_process(delta: float) -> void: # Advances enemy movement, gravity, contact handling, and squash death at physics cadence.
	if _is_dead: # Gives the squash death state complete priority over movement and contact logic.
		_update_squash(delta) # Advances the short visual compression before removing the enemy.
		return # Stops all live-enemy physics while the slime is being squashed.
	var requested_velocity: Vector3 = _get_requested_velocity() # Resolves horizontal chase movement from the cached player target.
	velocity.x = move_toward(velocity.x, requested_velocity.x, GROUND_ACCELERATION * delta) # Accelerates the slime toward the requested X movement.
	velocity.z = move_toward(velocity.z, requested_velocity.z, GROUND_ACCELERATION * delta) # Accelerates the slime toward the requested Z movement.
	_apply_vertical_movement(delta) # Applies gravity and floor stabilization independently from horizontal chasing.
	move_and_slide() # Moves through world and player collision using CharacterBody3D floor and wall handling.
	_handle_player_collisions() # Applies contact damage when the slime's own movement reaches the player.

func _get_requested_velocity() -> Vector3: # Builds a ground-plane chase velocity while the player is close enough to engage.
	if _target == null: # Rejects movement when the playable scene has no valid player target.
		return Vector3.ZERO # Keeps the enemy stationary until a target exists.
	var target_offset: Vector3 = _target.global_position - global_position # Measures the world-space direction from the slime to the player.
	target_offset.y = 0.0 # Restricts autonomous movement to the same ground plane used by player input.
	var target_distance_squared: float = target_offset.length_squared() # Measures chase distance without an unnecessary square root.
	if target_distance_squared > CHASE_DISTANCE_SQUARED: # Keeps distant slimes dormant until the player approaches their area.
		return Vector3.ZERO # Avoids movement work and cross-room convergence while outside engagement range.
	if target_distance_squared <= MOVEMENT_EPSILON_SQUARED: # Rejects normalization when the horizontal offset is effectively zero.
		return Vector3.ZERO # Prevents unstable direction values at negligible separation.
	return target_offset.normalized() * MOVE_SPEED # Produces the requested horizontal chase velocity toward the player.

func _apply_vertical_movement(delta: float) -> void: # Keeps enemy gravity separate from horizontal chase calculations.
	if is_on_floor(): # Checks whether the previous move established floor contact.
		velocity.y = 0.0 # Clears residual falling speed while the slime is grounded.
		return # Finishes vertical processing for grounded frames.
	velocity.y -= _gravity * delta # Applies frame-rate-independent project gravity while airborne.

func _handle_player_collisions() -> void: # Handles collisions created by the slime moving into the player.
	var collision_index: int = 0 # Starts iteration at the first slide collision from the latest move.
	while collision_index < get_slide_collision_count(): # Visits every collision generated by the latest CharacterBody3D move.
		var collision: KinematicCollision3D = get_slide_collision(collision_index) # Reads collision data for the current slide interaction.
		var collider: Object = collision.get_collider() # Reads the object reached by the slime during this physics frame.
		if collider is TornPlayerController: # Filters world geometry and other bodies from player-specific damage handling.
			var player: TornPlayerController = collider as TornPlayerController # Narrows the collider to the typed player controller.
			if not _player_is_descending_stomp(player): # Protects a valid top-down stomp from enemy-side damage ordering.
				player.take_enemy_contact_damage(global_position) # Requests contact damage through the player's composed health handling.
			return # Stops after the only relevant player collision for this frame.
		collision_index += 1 # Advances to the next slide collision when the current collider is not the player.

func _player_is_descending_stomp(player: TornPlayerController) -> bool: # Detects a likely stomp before the player's own collision pass resolves it.
	if player.velocity.y >= 0.0: # Rejects grounded and rising contacts from stomp protection.
		return false # Allows ordinary contact damage for non-descending player movement.
	return player.global_position.y > global_position.y + STOMP_PROTECTION_HEIGHT # Protects descending contacts where the player is clearly above the slime.

func stomp() -> bool: # Squashes the slime once and reports whether the stomp was accepted.
	if _is_dead: # Rejects repeated stomp calls after another collision has already killed the slime.
		return false # Prevents duplicate bounce or death processing for the same enemy.
	_is_dead = true # Marks the enemy dead before any later physics callback can deal contact damage.
	velocity = Vector3.ZERO # Stops all movement immediately when the stomp succeeds.
	collision_layer = 0 # Removes the dead slime from other bodies' collision queries during the squash presentation.
	collision_mask = 0 # Stops the dead slime from querying world or player collision during the squash presentation.
	return true # Reports that the player should receive the successful stomp response.

func is_dead() -> bool: # Reports whether the slime has already entered its squash death state.
	return _is_dead # Exposes death state read-only for player collision filtering.

func _update_squash(delta: float) -> void: # Compresses the billboard briefly before removing the defeated enemy instance.
	_squash_elapsed += delta # Advances the non-looping squash timer using physics time.
	var squash_ratio: float = minf(_squash_elapsed / SQUASH_DURATION, 1.0) # Converts elapsed time into a clamped presentation ratio.
	var target_scale: Vector3 = Vector3(_initial_sprite_scale.x * SQUASH_HORIZONTAL_SCALE, _initial_sprite_scale.y * SQUASH_VERTICAL_SCALE, _initial_sprite_scale.z) # Builds the final flattened sprite scale from authored scene values.
	var target_position: Vector3 = _initial_sprite_position + Vector3.DOWN * SQUASH_DROP_DISTANCE # Builds the lowered visual anchor used to keep the flattened slime near the ground.
	_sprite.scale = _initial_sprite_scale.lerp(target_scale, squash_ratio) # Blends the sprite from normal proportions into the flattened squash pose.
	_sprite.position = _initial_sprite_position.lerp(target_position, squash_ratio) # Lowers the visual while its height collapses so the bottom remains visually stable.
	if squash_ratio >= 1.0: # Detects completion of the squash presentation.
		queue_free() # Removes the defeated enemy after its visual death response has finished.

func _apply_configured_texture() -> void: # Loads the configured texture only when the user has dropped the expected asset into the project.
	if _texture_path.is_empty(): # Rejects unconfigured instances without invoking the resource loader.
		push_warning("slime_enemy has no configured texture path") # Reports scene setup errors without crashing the playable prototype.
		return # Leaves the billboard empty until a valid path is provided.
	if not ResourceLoader.exists(_texture_path, "Texture2D"): # Checks for an imported texture before attempting a load that would emit an engine error.
		push_warning("missing slime sprite: %s" % _texture_path) # Reports the exact asset path that should be supplied by the project.
		return # Keeps gameplay logic active while the intentionally uncommitted sprite is absent.
	var loaded_resource: Resource = ResourceLoader.load(_texture_path, "Texture2D") # Loads the imported texture through Godot's cached resource system.
	var texture: Texture2D = loaded_resource as Texture2D # Narrows the loaded resource to the sprite texture type expected by Sprite3D.
	if texture == null: # Rejects an unexpected resource type without assigning an invalid visual.
		push_warning("slime sprite is not a Texture2D: %s" % _texture_path) # Reports incompatible asset setup clearly in the debugger.
		return # Leaves the existing sprite unchanged when the loaded resource is invalid.
	_sprite.texture = texture # Applies the supplied slime artwork to the billboard sprite.
