extends Node # Stores player health independently from movement, visuals, and enemy logic.
class_name TornPlayerHealth # Gives the health component a strongly typed project-wide class name.

const MAX_HEALTH: int = 3 # Defines the player's full health pool.
const DAMAGE_INVULNERABILITY_MSEC: int = 750 # Defines the protected interval after accepted contact damage.

var _current_health: int = MAX_HEALTH # Stores the player's current health value.
var _invulnerable_until_msec: int = 0 # Stores the engine tick when contact damage may be accepted again.

func take_damage(amount: int) -> bool: # Attempts to remove health and reports whether the hit was accepted.
	if amount <= 0: # Rejects invalid damage requests before changing state.
		return false # Reports that no damage was applied.
	if _current_health <= 0: # Rejects damage while the component is already depleted.
		return false # Prevents repeated defeat processing before the controller restores health.
	var current_msec: int = Time.get_ticks_msec() # Reads the monotonic engine clock only when a damage request occurs.
	if current_msec < _invulnerable_until_msec: # Rejects contact damage during the post-hit protection interval.
		return false # Reports that the protected hit was ignored.
	_current_health = maxi(_current_health - amount, 0) # Removes health without allowing the stored value to become negative.
	_invulnerable_until_msec = current_msec + DAMAGE_INVULNERABILITY_MSEC # Starts the protection interval for subsequent contact checks.
	return true # Reports that the damage request changed player health.

func get_current_health() -> int: # Returns the current health value for future UI or combat systems.
	return _current_health # Exposes health read-only through an explicit method.

func is_depleted() -> bool: # Reports whether the player has no remaining health.
	return _current_health <= 0 # Converts the stored health value into a defeat condition.

func restore_full() -> void: # Restores the player after a defeat or future healing reset.
	_current_health = MAX_HEALTH # Restores the component to its full health pool.
