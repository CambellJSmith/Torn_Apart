extends CharacterBody3D # Uses Godot's character body for controlled 3D movement and collision.
class_name TornPlayerController # Gives the player controller a strongly typed project-wide class name.

const MOVE_SPEED: float = 5.5 # Defines horizontal traversal speed.
const GROUND_ACCELERATION: float = 32.0 # Defines how quickly grounded movement reaches the requested speed.
const AIR_ACCELERATION: float = 10.0 # Defines how much directional control remains while airborne.
const JUMP_VELOCITY: float = 6.4 # Defines the upward launch speed for jumping.
const FALL_GRAVITY_MULTIPLIER: float = 1.35 # Makes the descending half of a jump feel more responsive.
const STOMP_NORMAL_DOT: float = 0.35 # Defines how upward-facing an enemy collision must be to count as a stomp.
const STOMP_BOUNCE_VELOCITY: float = 4.4 # Defines the rebound applied after a successful slime stomp.
const ENEMY_CONTACT_DAMAGE: int = 1 # Defines the health removed by an accepted enemy contact hit.
const DAMAGE_KNOCKBACK_SPEED: float = 5.0 # Defines horizontal separation applied after accepted enemy contact damage.
const DAMAGE_DIRECTION_EPSILON_SQUARED: float = 0.0001 # Filters negligible source offsets from knockback normalization.
const STICK_LEFT_NORTH: StringName = &"StickLeft_North" # References the north movement input action.
const STICK_LEFT_SOUTH: StringName = &"StickLeft_South" # References the south movement input action.
const STICK_LEFT_WEST: StringName = &"StickLeft_West" # References the west movement input action.
const STICK_LEFT_EAST: StringName = &"StickLeft_East" # References the east movement input action.
const BUTTON_A: StringName = &"Button_A" # References the jump input action.
const BUTTON_X: StringName = &"Button_X" # References the interaction-pose input action.

@onready var _paper_visual: TornPaperVisual = $paper_visual # Caches the composed paper visual controller.
@onready var _landing_probe: RayCast3D = $landing_probe # Caches the downward probe used only to time the pre-landing animation window.
@onready var _health: TornPlayerHealth = $health # Caches the composed health component used for enemy contact damage.

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) # Reads the project's configured 3D gravity once for physics calculations.
var _spawn_transform: Transform3D = Transform3D.IDENTITY # Stores the authored player spawn transform for defeat recovery.
var _respawned_this_frame: bool = false # Stores whether contact damage moved the player back to the spawn point during this physics frame.
var _stomp_bounce_active: bool = false # Preserves a stomp rebound across the stale floor state from the collision that produced it.

func _ready() -> void: # Captures runtime state that depends on the player's authored scene placement.
	_spawn_transform = global_transform # Remembers the initial world transform for lightweight prototype defeat recovery.

func _physics_process(delta: float) -> void: # Advances movement at the fixed physics cadence.
	_respawned_this_frame = false # Clears the one-frame respawn marker before processing new movement and collisions.
	var input_vector: Vector2 = Input.get_vector(STICK_LEFT_WEST, STICK_LEFT_EAST, STICK_LEFT_NORTH, STICK_LEFT_SOUTH) # Combines keyboard or gamepad movement into one normalized vector.
	var requested_velocity: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y) * MOVE_SPEED # Converts two-axis input into ground-plane velocity.
	var acceleration: float = GROUND_ACCELERATION # Starts with grounded acceleration for responsive movement.
	if not is_on_floor(): # Detects when the player is airborne.
		acceleration = AIR_ACCELERATION # Reduces steering authority while airborne.
	velocity.x = move_toward(velocity.x, requested_velocity.x, acceleration * delta) # Accelerates horizontal movement toward the requested X speed.
	velocity.z = move_toward(velocity.z, requested_velocity.z, acceleration * delta) # Accelerates depth movement toward the requested Z speed.
	_apply_vertical_movement(delta) # Applies gravity and jump behaviour independently from horizontal movement.
	var vertical_velocity_before_move: float = velocity.y # Preserves pre-collision descent information because move_and_slide may rewrite velocity.
	move_and_slide() # Moves through the 3D world using CharacterBody3D collision and floor handling.
	var stomped_enemy: bool = _handle_enemy_collisions(vertical_velocity_before_move) # Resolves stomp kills or ordinary damaging contact from this move.
	if _respawned_this_frame: # Detects defeat recovery performed while processing enemy contact.
		_paper_visual.set_motion_direction(Vector3.ZERO) # Resets locomotion presentation after the player teleports back to spawn.
		_paper_visual.set_jump_state(false, false) # Returns presentation to a grounded state after defeat recovery.
		_paper_visual.set_interacting(false) # Clears interaction presentation during the defeat recovery frame.
		return # Skips collision-derived presentation state from the player's pre-respawn position.
	var is_airborne: bool = stomped_enemy or not is_on_floor() # Treats a stomp rebound as airborne even if the collision was classified as a floor during move_and_slide.
	var landing_imminent: bool = false # Starts with landing presentation disabled for stomp rebounds and grounded movement.
	if not stomped_enemy: # Keeps the normal landing probe behaviour only when no enemy rebound occurred.
		landing_imminent = _is_landing_imminent(is_airborne) # Checks whether a descending airborne player is close enough to begin landing frames.
	_paper_visual.set_motion_direction(Vector3(velocity.x, 0.0, velocity.z)) # Passes current ground-plane motion to the visual component.
	_paper_visual.set_jump_state(is_airborne, landing_imminent) # Passes airtime and near-floor state so the jump sheet can split takeoff from landing.
	_paper_visual.set_interacting(Input.is_action_pressed(BUTTON_X)) # Lets the supplied interaction pose override grounded locomotion while the interaction button is held.

func _apply_vertical_movement(delta: float) -> void: # Keeps jump and gravity logic isolated from horizontal movement.
	if _stomp_bounce_active: # Overrides the stale floor state on the first movement frame after a successful stomp.
		_stomp_bounce_active = false # Releases the override because the next move will refresh CharacterBody3D floor state.
		velocity.y -= _gravity * delta # Applies normal gravity while preserving the upward stomp rebound for this movement frame.
		return # Prevents grounded handling from clearing the rebound before move_and_slide can use it.
	if is_on_floor(): # Checks whether the previous physics move established floor contact.
		if Input.is_action_just_pressed(BUTTON_A): # Detects a fresh jump press while grounded.
			velocity.y = JUMP_VELOCITY # Launches the player upward.
		else: # Handles grounded frames without a jump request.
			velocity.y = 0.0 # Prevents residual vertical velocity from accumulating on the floor.
		return # Finishes vertical processing for grounded movement.
	var gravity_multiplier: float = 1.0 # Starts airborne gravity at the normal project setting.
	if velocity.y < 0.0: # Detects the falling half of the jump arc.
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER # Increases falling gravity for a tighter landing feel.
	velocity.y -= _gravity * gravity_multiplier * delta # Applies frame-rate-independent gravity to vertical velocity.

func _handle_enemy_collisions(vertical_velocity_before_move: float) -> bool: # Resolves slime stomp kills before falling back to ordinary contact damage.
	var collision_index: int = 0 # Starts iteration at the first slide collision from the latest player move.
	while collision_index < get_slide_collision_count(): # Visits every collision generated by the latest CharacterBody3D move.
		var collision: KinematicCollision3D = get_slide_collision(collision_index) # Reads detailed collider and normal information for this slide interaction.
		var collider: Object = collision.get_collider() # Reads the object reached by the player during this physics frame.
		if collider is TornSlimeEnemy: # Filters world geometry and unrelated bodies from enemy combat handling.
			var slime: TornSlimeEnemy = collider as TornSlimeEnemy # Narrows the collider to the typed reusable slime enemy.
			if slime.is_dead(): # Ignores an enemy already disabled by another stomp collision in the same frame.
				collision_index += 1 # Advances past the defeated enemy without applying damage or another bounce.
				continue # Continues checking any remaining slide collisions from the player move.
			var upward_contact: float = Vector3.UP.dot(collision.get_normal()) # Measures whether the collision surface is sufficiently below the falling player.
			if vertical_velocity_before_move < 0.0 and upward_contact > STOMP_NORMAL_DOT: # Requires both descent and an upward-facing collision normal for a stomp.
				if slime.stomp(): # Attempts to kill the enemy exactly once before applying the rebound.
					velocity.y = STOMP_BOUNCE_VELOCITY # Rebounds the player upward after a successful squash.
					_stomp_bounce_active = true # Preserves the rebound through the next frame's stale CharacterBody3D floor state.
					return true # Reports the rebound so presentation does not treat the enemy surface as ordinary floor contact.
			take_enemy_contact_damage(slime.global_position) # Routes side or underside contact through the composed health component.
			return false # Stops after resolving the relevant live enemy collision for this frame.
		collision_index += 1 # Advances to the next slide collision when the current collider is not an enemy.
	return false # Reports that the player did not stomp an enemy during the latest move.

func take_enemy_contact_damage(source_position: Vector3) -> void: # Applies protected contact damage and horizontal separation from an enemy source.
	if not _health.take_damage(ENEMY_CONTACT_DAMAGE): # Rejects repeated contact while the health component is protecting the player.
		return # Avoids repeated knockback and defeat processing for ignored contact frames.
	if _health.is_depleted(): # Detects when the accepted contact removed the player's remaining health.
		_respawn_after_defeat() # Restores the lightweight prototype state at the authored player spawn point.
		return # Skips knockback because the player has already been repositioned by defeat recovery.
	var knockback_direction: Vector3 = global_position - source_position # Measures the ground-plane direction away from the damaging enemy.
	knockback_direction.y = 0.0 # Restricts contact separation to horizontal movement so grounded vertical state remains stable.
	if knockback_direction.length_squared() <= DAMAGE_DIRECTION_EPSILON_SQUARED: # Handles overlapping centers where a direction cannot be normalized safely.
		knockback_direction = Vector3.BACK # Supplies a stable fallback separation direction for exact overlaps.
	else: # Handles ordinary contact where the player and enemy centers are distinct.
		knockback_direction = knockback_direction.normalized() # Converts the source offset into a unit separation direction.
	velocity.x = knockback_direction.x * DAMAGE_KNOCKBACK_SPEED # Applies immediate horizontal separation along the X axis.
	velocity.z = knockback_direction.z * DAMAGE_KNOCKBACK_SPEED # Applies immediate horizontal separation along the Z axis.

func get_current_health() -> int: # Exposes player health for future UI without exposing mutable component state.
	return _health.get_current_health() # Forwards the read through the composed health component.

func _respawn_after_defeat() -> void: # Restores the prototype player state after health is depleted.
	global_transform = _spawn_transform # Moves the player back to the authored starting transform.
	velocity = Vector3.ZERO # Clears movement inherited from the collision that caused defeat.
	_stomp_bounce_active = false # Clears any pending rebound when defeat recovery takes ownership of movement state.
	_health.restore_full() # Restores health so the prototype can continue immediately after defeat.
	_respawned_this_frame = true # Prevents stale collision presentation from the pre-respawn location.

func _is_landing_imminent(is_airborne: bool) -> bool: # Resolves whether the descending player is within the short visual landing window.
	if not is_airborne: # Rejects grounded frames because actual contact is handled separately by the visual state machine.
		return false # Prevents the proximity probe from repeatedly restarting landing while standing on the floor.
	if velocity.y >= 0.0: # Rejects rising and apex-adjacent frames so takeoff always reaches and holds its fourth frame first.
		return false # Keeps the landing half completely out of the ascent portion of the jump.
	_landing_probe.force_raycast_update() # Refreshes the probe after this physics frame's movement so the result matches the player's latest position.
	return _landing_probe.is_colliding() # Starts the second half of the jump sheet only when floor geometry is close below the falling player.
