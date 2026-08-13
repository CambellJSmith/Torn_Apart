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
const BUTTON_X: StringName = &"Button_X" # References the interaction input action.

@onready var _paper_visual: TornPaperVisual = $paper_visual # Caches the composed paper visual controller.
@onready var _landing_probe: RayCast3D = $landing_probe # Caches the downward probe used to time pre-landing animation.
@onready var _health: TornPlayerHealth = $health # Caches the composed health component.
@onready var _interaction: TornNearbyInteraction = $interaction # Caches the composed nearby interaction component.

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity")) # Reads project gravity once.
var _level: TornLevelContext = null # Stores the active isolated level that owns recovery rules.
var _respawned_this_frame: bool = false # Stores whether recovery moved the player this physics frame.
var _stomp_bounce_active: bool = false # Preserves a stomp rebound across stale floor state.

func configure_level(level: TornLevelContext) -> void: # Supplies the active level and places the player at its authored spawn.
	_level = level # Stores the level contract.
	global_transform = _level.get_respawn_transform() # Places the player at the level-owned spawn.
	velocity = Vector3.ZERO # Clears movement before play begins.
	reset_physics_interpolation() # Prevents interpolation from blending from the temporary scene origin.

func configure_interaction_ui(prompt_ui: TornInteractionPrompt) -> void: # Supplies persistent prompt UI to the composed interaction component.
	_interaction.configure_prompt_ui(prompt_ui) # Keeps interaction UI ownership outside movement logic.

func _physics_process(delta: float) -> void: # Advances movement, recovery, combat contact, and interactions at physics cadence.
	_respawned_this_frame = false # Clears the one-frame recovery marker.
	if _recover_from_void_if_needed(): # Handles a fall already below the level threshold.
		_reset_presentation_after_recovery() # Returns visuals to a stable grounded state.
		return # Skips stale gameplay processing after teleporting.
	var input_vector: Vector2 = Input.get_vector(STICK_LEFT_WEST, STICK_LEFT_EAST, STICK_LEFT_NORTH, STICK_LEFT_SOUTH) # Combines movement input.
	var requested_velocity: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y) * MOVE_SPEED # Converts input into ground-plane velocity.
	var acceleration: float = GROUND_ACCELERATION # Starts with responsive grounded acceleration.
	if not is_on_floor(): # Detects airborne movement.
		acceleration = AIR_ACCELERATION # Reduces steering authority while airborne.
	velocity.x = move_toward(velocity.x, requested_velocity.x, acceleration * delta) # Accelerates toward requested X speed.
	velocity.z = move_toward(velocity.z, requested_velocity.z, acceleration * delta) # Accelerates toward requested Z speed.
	_apply_vertical_movement(delta) # Applies jump and gravity independently.
	var vertical_velocity_before_move: float = velocity.y # Preserves descent state before collision resolution.
	move_and_slide() # Moves through the 3D world with CharacterBody3D collision.
	if _recover_from_void_if_needed(): # Catches a threshold crossing produced by this move.
		_reset_presentation_after_recovery() # Resets visuals after the level-owned teleport.
		return # Prevents stale slide collisions from affecting gameplay.
	var stomped_enemy: bool = _handle_enemy_collisions(vertical_velocity_before_move) # Resolves stomp or contact damage.
	if _respawned_this_frame: # Detects defeat recovery during enemy collision processing.
		_reset_presentation_after_recovery() # Resets visuals at the recovery point.
		return # Skips stale pre-recovery state.
	if _level != null: # Updates recovery markers only when a level is configured.
		_level.update_recovery_point(global_position) # Activates nearby editor-authored recovery points.
	_interaction.update_target(self) # Refreshes the nearest interactable from the physics overlap list.
	if Input.is_action_just_pressed(BUTTON_X): # Detects a fresh interaction action press.
		_interaction.use_target(self) # Directly invokes the selected interactable.
	var is_airborne: bool = stomped_enemy or not is_on_floor() # Treats stomp rebounds as airborne.
	var landing_imminent: bool = false # Starts with landing presentation disabled.
	if not stomped_enemy: # Keeps normal landing-probe behaviour outside stomp rebounds.
		landing_imminent = _is_landing_imminent(is_airborne) # Checks whether a descending player is close to floor geometry.
	_paper_visual.set_motion_direction(Vector3(velocity.x, 0.0, velocity.z)) # Passes ground-plane movement to visuals.
	_paper_visual.set_jump_state(is_airborne, landing_imminent) # Passes jump and landing state to visuals.
	_paper_visual.set_interacting(Input.is_action_pressed(BUTTON_X)) # Shows the interaction pose while the action is held.

func _apply_vertical_movement(delta: float) -> void: # Keeps jump and gravity logic isolated from horizontal movement.
	if _stomp_bounce_active: # Overrides stale floor state after a stomp.
		_stomp_bounce_active = false # Releases the override for the next refreshed move.
		velocity.y -= _gravity * delta # Applies gravity while preserving the rebound.
		return # Prevents grounded handling from clearing the rebound.
	if is_on_floor(): # Checks whether the previous move established floor contact.
		if Input.is_action_just_pressed(BUTTON_A): # Detects a fresh grounded jump press.
			velocity.y = JUMP_VELOCITY # Launches the player upward.
		else: # Handles grounded frames without jumping.
			velocity.y = 0.0 # Clears residual vertical movement.
		return # Finishes grounded vertical processing.
	var gravity_multiplier: float = 1.0 # Starts airborne gravity at the normal project setting.
	if velocity.y < 0.0: # Detects the falling half of the jump.
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER # Tightens the descending arc.
	velocity.y -= _gravity * gravity_multiplier * delta # Applies frame-rate-independent gravity.

func _handle_enemy_collisions(vertical_velocity_before_move: float) -> bool: # Resolves slime stomps before ordinary contact damage.
	for collision_index: int in range(get_slide_collision_count()): # Visits every collision from the latest move.
		var collision: KinematicCollision3D = get_slide_collision(collision_index) # Reads detailed collision information.
		var collider: Object = collision.get_collider() # Reads the contacted object.
		if collider is not TornSlimeEnemy: # Filters unrelated collision bodies.
			continue # Checks the next collision.
		var slime: TornSlimeEnemy = collider as TornSlimeEnemy # Narrows the collider to a slime.
		if slime.is_dead(): # Ignores already defeated enemies.
			continue # Checks remaining collisions.
		var upward_contact: float = Vector3.UP.dot(collision.get_normal()) # Measures whether contact is beneath the player.
		if vertical_velocity_before_move < 0.0 and upward_contact > STOMP_NORMAL_DOT: # Requires descent and an upward-facing normal.
			if slime.stomp(): # Attempts to defeat the slime once.
				velocity.y = STOMP_BOUNCE_VELOCITY # Applies the successful stomp rebound.
				_stomp_bounce_active = true # Preserves the rebound through stale floor state.
				return true # Reports the stomp to presentation logic.
		take_enemy_contact_damage(slime.global_position) # Applies ordinary damaging contact.
		return false # Stops after resolving the live enemy collision.
	return false # Reports that no stomp occurred.

func take_enemy_contact_damage(source_position: Vector3) -> void: # Applies protected contact damage and horizontal separation.
	if not _health.take_damage(ENEMY_CONTACT_DAMAGE): # Rejects damage during the protection interval.
		return # Avoids repeated knockback and defeat work.
	if _health.is_depleted(): # Detects removal of the player's final health point.
		_respawn_after_defeat() # Restores the player at the active recovery point.
		return # Skips knockback after recovery.
	var knockback_direction: Vector3 = global_position - source_position # Measures the direction away from the enemy.
	knockback_direction.y = 0.0 # Restricts separation to the ground plane.
	if knockback_direction.length_squared() <= DAMAGE_DIRECTION_EPSILON_SQUARED: # Handles exact overlaps safely.
		knockback_direction = Vector3.BACK # Supplies a stable fallback direction.
	else: # Handles ordinary distinct positions.
		knockback_direction = knockback_direction.normalized() # Converts the offset into a unit direction.
	velocity.x = knockback_direction.x * DAMAGE_KNOCKBACK_SPEED # Applies X separation.
	velocity.z = knockback_direction.z * DAMAGE_KNOCKBACK_SPEED # Applies Z separation.

func get_current_health() -> int: # Exposes health read-only for future UI.
	return _health.get_current_health() # Forwards the read through the health component.

func _recover_from_void_if_needed() -> bool: # Restores the player after falling beneath the active level.
	if _level == null: # Rejects recovery checks without a composed level.
		return false # Reports that no recovery occurred.
	if global_position.y >= _level.get_fall_threshold_y(): # Keeps normal play above the void threshold.
		return false # Reports that recovery is unnecessary.
	_respawn_to_level(false) # Returns to the active recovery point without healing.
	return true # Reports that a recovery teleport occurred.

func _respawn_after_defeat() -> void: # Restores player state after health depletion.
	_respawn_to_level(true) # Returns to the active recovery point and restores health.

func _respawn_to_level(restore_health: bool) -> void: # Performs one level-owned recovery teleport.
	if _level == null: # Detects invalid composition.
		push_error("player_controller requires a TornLevelContext for recovery") # Reports the missing dependency.
		return # Avoids teleporting to an invalid transform.
	global_transform = _level.get_respawn_transform() # Moves to the current spawn or recovery marker.
	reset_physics_interpolation() # Prevents teleport interpolation across the level.
	velocity = Vector3.ZERO # Clears inherited movement.
	_stomp_bounce_active = false # Clears pending stomp rebound state.
	if restore_health: # Restores health only for defeat recovery.
		_health.restore_full() # Refills the health component.
	_respawned_this_frame = true # Marks discontinuous movement for this physics frame.
	_interaction.clear_target() # Clears stale spatial interaction targeting.

func _reset_presentation_after_recovery() -> void: # Returns composed visuals to a stable grounded state after teleports.
	_paper_visual.set_motion_direction(Vector3.ZERO) # Resets locomotion presentation.
	_paper_visual.set_jump_state(false, false) # Resets jump presentation.
	_paper_visual.set_interacting(false) # Clears interaction presentation.

func _is_landing_imminent(is_airborne: bool) -> bool: # Resolves whether the descending player is close to floor geometry.
	if not is_airborne: # Rejects grounded frames.
		return false # Prevents repeated landing animation restarts.
	if velocity.y >= 0.0: # Rejects rising frames.
		return false # Keeps landing frames out of ascent.
	_landing_probe.force_raycast_update() # Refreshes the probe after current movement.
	return _landing_probe.is_colliding() # Reports whether floor geometry is close below.
