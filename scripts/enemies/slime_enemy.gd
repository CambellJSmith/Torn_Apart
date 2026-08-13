extends CharacterBody3D # Uses controlled 3D movement and collision for a grounded slime enemy.
class_name TornSlimeEnemy # Gives slime enemies a strongly typed project-wide class name.

const MOVE_SPEED: float = 1.8 # Controls the slime's horizontal chase speed.
const GROUND_ACCELERATION: float = 12.0 # Controls how quickly the slime reaches or leaves its requested speed.
const CHASE_DISTANCE_SQUARED: float = 36.0 # Limits active chasing without requiring a square root for distant targets.
const MOVEMENT_EPSILON_SQUARED: float = 0.0001 # Filters negligible target offsets from movement calculations.
const STOMP_PROTECTION_HEIGHT: float = 0.35 # Prevents enemy-side contact damage from beating a descending stomp check.
const LEDGE_PROBE_FORWARD: float = 0.7 # Places the floor probe ahead of the slime in its requested movement direction.
const LEDGE_PROBE_HEIGHT: float = 0.4 # Starts the vertical floor probe above the slime's ground contact point.
const LEDGE_PROBE_DEPTH: float = 1.25 # Looks far enough down to allow small platform drops while rejecting empty void.
const SQUASH_DURATION: float = 0.18 # Controls how long the squash death presentation remains visible.
const SQUASH_HORIZONTAL_SCALE: float = 1.22 # Controls the sideways spread used by the squash presentation.
const SQUASH_VERTICAL_SCALE: float = 0.16 # Controls the vertical compression used by the squash presentation.
const SQUASH_DROP_DISTANCE: float = 0.32 # Keeps the compressed sprite visually anchored near the floor.

@onready var _sprite: Sprite3D = $sprite # Caches the billboard sprite used for the slime artwork and squash presentation.
@onready var _ledge_probe: RayCast3D = $ledge_probe # Caches the world-only floor probe used to keep autonomous movement on level geometry.

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) # Reads the project gravity once for grounded enemy movement.
var _target: TornPlayerController = null # Stores the player instance chased and damaged by this slime.
var _is_dead: bool = false # Stores whether stomp handling has disabled this enemy.
var _squash_elapsed: float = 0.0 # Tracks progress through the short squash death presentation.
var _initial_sprite_scale: Vector3 = Vector3.ONE # Stores the original sprite scale so squashing remains relative to scene setup.
var _initial_sprite_position: Vector3 = Vector3.ZERO # Stores the original sprite position so squashing stays floor-aligned.

func _ready() -> void: # Resolves runtime dependencies and captures authored visual state.
	_target = get_tree().get_first_node_in_group(&"player") as TornPlayerController # Finds the composed player instance without coupling the enemy to a scene path.
	_initial_sprite_scale = _sprite.scale # Captures the authored scale before squash presentation changes it.
	_initial_sprite_position = _sprite.position # Captures the authored visual anchor before squash presentation changes it.

func _physics_process(delta: float) -> void: # Advances enemy movement, gravity, contact handling, and squash death at physics cadence.
	if _is_dead: # Gives the squash death state complete priority over movement and contact logic.
		_update_squash(delta) # Advances the short visual compression before removing the enemy.
		return # Stops all live-enemy physics while the slime is being squashed.
	var requested_velocity: Vector3 = _get_requested_velocity() # Resolves safe ground-plane chase movement from the cached player target.
	velocity.x = move_toward(velocity.x, requested_velocity.x, GROUND_ACCELERATION * delta) # Accelerates the slime toward the requested X movement.
	velocity.z = move_toward(velocity.z, requested_velocity.z, GROUND_ACCELERATION * delta) # Accelerates the slime toward the requested Z movement.
	_apply_vertical_movement(delta) # Applies gravity and floor stabilization independently from horizontal chasing.
	move_and_slide() # Moves through world and player collision using CharacterBody3D floor and wall handling.
	_handle_player_collisions() # Applies contact damage when the slime's own movement reaches the player.

func _get_requested_velocity() -> Vector3: # Builds a chase velocity only when the target is close and world floor exists ahead.
	if _target == null: # Rejects movement when the playable scene has no valid player target.
		return Vector3.ZERO # Keeps the enemy stationary until a target exists.
	var target_offset: Vector3 = _target.global_position - global_position # Measures the world-space direction from the slime to the player.
	target_offset.y = 0.0 # Restricts autonomous movement to the ground plane.
	var target_distance_squared: float = target_offset.length_squared() # Measures chase distance without an unnecessary square root.
	if target_distance_squared > CHASE_DISTANCE_SQUARED: # Keeps distant slimes dormant until the player approaches their area.
		return Vector3.ZERO # Avoids cross-level convergence while outside engagement range.
	if target_distance_squared <= MOVEMENT_EPSILON_SQUARED: # Rejects normalization when the horizontal offset is effectively zero.
		return Vector3.ZERO # Prevents unstable direction values at negligible separation.
	var direction: Vector3 = target_offset.normalized() # Converts the target offset into a safe ground-plane movement direction.
	if not _has_floor_ahead(direction): # Checks world geometry before committing to autonomous movement toward an island edge.
		return Vector3.ZERO # Stops the slime at the ledge instead of allowing it to walk into the void.
	return direction * MOVE_SPEED # Produces the safe requested horizontal chase velocity.

func _has_floor_ahead(direction: Vector3) -> bool: # Tests one vertical world-only ray at a point ahead of the slime.
	_ledge_probe.position = Vector3(direction.x * LEDGE_PROBE_FORWARD, LEDGE_PROBE_HEIGHT, direction.z * LEDGE_PROBE_FORWARD) # Moves the probe origin ahead without rotating the CharacterBody.
	_ledge_probe.target_position = Vector3(0.0, -LEDGE_PROBE_DEPTH, 0.0) # Casts straight downward so current floor cannot create a false positive before the ledge.
	_ledge_probe.force_raycast_update() # Refreshes the probe immediately for the current requested movement direction.
	return _ledge_probe.is_colliding() # Allows movement only when world collision exists beneath the ahead point.

func _apply_vertical_movement(delta: float) -> void: # Keeps enemy gravity separate from horizontal chase calculations.
	if is_on_floor(): # Checks whether the previous move established floor contact.
		velocity.y = 0.0 # Clears residual falling speed while the slime is grounded.
		return # Finishes vertical processing for grounded frames.
	velocity.y -= _gravity * delta # Applies frame-rate-independent project gravity while airborne.

func _handle_player_collisions() -> void: # Handles collisions created by the slime moving into the player.
	for collision_index: int in range(get_slide_collision_count()): # Visits every collision generated by the latest CharacterBody3D move.
		var collision: KinematicCollision3D = get_slide_collision(collision_index) # Reads collision data for the current slide interaction.
		var collider: Object = collision.get_collider() # Reads the object reached by the slime during this physics frame.
		if collider is not TornPlayerController: # Filters world geometry and other bodies from player-specific damage handling.
			continue # Continues directly to the next slide collision.
		var player: TornPlayerController = collider as TornPlayerController # Narrows the collider to the typed player controller.
		if not _player_is_descending_stomp(player): # Protects a valid top-down stomp from enemy-side damage ordering.
			player.take_enemy_contact_damage(global_position) # Requests contact damage through the player's composed health handling.
		return # Stops after the only relevant player collision for this frame.

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
	var target_scale: Vector3 = Vector3(_initial_sprite_scale.x * SQUASH_HORIZONTAL_SCALE, _initial_sprite_scale.y * SQUASH_VERTICAL_SCALE, _initial_sprite_scale.z) # Builds the final flattened sprite scale.
	var target_position: Vector3 = _initial_sprite_position + Vector3.DOWN * SQUASH_DROP_DISTANCE # Builds the lowered anchor that keeps the flattened slime near the floor.
	_sprite.scale = _initial_sprite_scale.lerp(target_scale, squash_ratio) # Blends the sprite from normal proportions into the flattened squash pose.
	_sprite.position = _initial_sprite_position.lerp(target_position, squash_ratio) # Lowers the visual while its height collapses.
	if squash_ratio >= 1.0: # Detects completion of the squash presentation.
		queue_free() # Removes the defeated enemy after its visual response has finished.
