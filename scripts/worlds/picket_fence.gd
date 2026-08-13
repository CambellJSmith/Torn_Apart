extends Node3D # Builds a reusable primitive white picket fence around exposed circular platform edges.
class_name TornPicketFence # Gives the fence component a strongly typed project-wide class name.

const FENCE_INSET: float = 0.28 # Pulls the fence slightly inward from each visible platform edge.
const FENCE_SAMPLE_SPACING: float = 0.62 # Controls the approximate spacing between neighboring pickets around a circular platform.
const OVERLAP_CLEARANCE: float = 0.32 # Opens fence gaps wherever another platform substantially overlaps the current perimeter.
const PICKET_WIDTH: float = 0.13 # Defines the horizontal thickness of each repeated primitive picket.
const PICKET_HEIGHT: float = 1.05 # Defines the visible height of each primitive picket above its platform surface.
const RAIL_THICKNESS: float = 0.11 # Defines the vertical thickness shared by the two horizontal fence rails.
const RAIL_DEPTH: float = 0.10 # Defines the depth of each horizontal fence rail.
const LOWER_RAIL_HEIGHT: float = 0.35 # Positions the lower horizontal rail above the platform surface.
const UPPER_RAIL_HEIGHT: float = 0.72 # Positions the upper horizontal rail above the platform surface.
const COLLISION_HEIGHT: float = 1.05 # Gives each fence segment continuous collision across the complete visible fence height.
const COLLISION_DEPTH: float = 0.16 # Keeps fence collision narrow while reliably stopping the player and enemies.

@onready var _pickets: MultiMeshInstance3D = $pickets # Caches the GPU-instanced picket renderer.
@onready var _rails: MultiMeshInstance3D = $rails # Caches the GPU-instanced horizontal rail renderer.
@onready var _collision: StaticBody3D = $collision # Caches the static body that owns continuous fence-segment collision.

func build(platform_specs: Array[Vector4]) -> void: # Rebuilds fence visuals and collision from the owning level's circular platform definitions.
	var picket_transforms: Array[Transform3D] = [] # Collects every visible picket transform before allocating the shared MultiMesh buffer.
	var rail_transforms: Array[Transform3D] = [] # Collects both horizontal rails for every exposed perimeter segment.
	_clear_collision() # Removes any previously generated collision when the component is deliberately rebuilt.
	for platform_index in range(platform_specs.size()): # Visits every circular platform so exposed edges can be fenced independently.
		_collect_platform_fence(platform_index, platform_specs, picket_transforms, rail_transforms) # Appends visible fence transforms and matching segment collision for this platform.
	_apply_multimesh(_pickets, _create_picket_mesh(), picket_transforms) # Draws every repeated picket through one GPU-instanced primitive mesh.
	_apply_multimesh(_rails, _create_rail_mesh(), rail_transforms) # Draws every repeated horizontal rail through one GPU-instanced primitive mesh.

func _collect_platform_fence(platform_index: int, platform_specs: Array[Vector4], picket_transforms: Array[Transform3D], rail_transforms: Array[Transform3D]) -> void: # Samples one circular perimeter while skipping openings created by overlapping platforms.
	var platform_spec: Vector4 = platform_specs[platform_index] # Reads the center, radius, and top height packed into the level's typed platform definition.
	var fence_radius: float = maxf(platform_spec.z - FENCE_INSET, 0.1) # Calculates the inward fence radius while preventing invalid tiny circles.
	var sample_count: int = maxi(16, int(ceil(TAU * fence_radius / FENCE_SAMPLE_SPACING))) # Derives enough evenly spaced samples to keep the circular fence readable.
	for sample_index in range(sample_count): # Walks each perimeter sample exactly once around the complete circle.
		var current_angle: float = TAU * float(sample_index) / float(sample_count) # Converts the current sample index into a circular angle.
		var next_angle: float = TAU * float((sample_index + 1) % sample_count) / float(sample_count) # Resolves the following sample while wrapping cleanly to the start of the circle.
		var current_point: Vector3 = _get_perimeter_point(platform_spec, current_angle) # Calculates the current fence point on the authored platform surface.
		var next_point: Vector3 = _get_perimeter_point(platform_spec, next_angle) # Calculates the next neighboring fence point on the same circular surface.
		var current_exposed: bool = _is_point_exposed(current_point, platform_index, platform_specs) # Detects whether another platform covers this section and should create a traversal opening.
		var next_exposed: bool = _is_point_exposed(next_point, platform_index, platform_specs) # Detects whether the following sample remains on an exposed outer edge.
		if current_exposed: # Adds a visible picket only when this perimeter sample belongs to the outside of the combined level shape.
			picket_transforms.append(Transform3D(Basis.IDENTITY, current_point + Vector3.UP * PICKET_HEIGHT * 0.5)) # Places one upright primitive picket with its base resting on the platform surface.
		if current_exposed and next_exposed: # Builds rails and collision only between two neighboring exposed samples so platform overlaps remain open.
			_append_fence_segment(current_point, next_point, rail_transforms) # Adds both visible rails and one continuous blocking collision segment between these samples.

func _get_perimeter_point(platform_spec: Vector4, angle: float) -> Vector3: # Converts one packed platform definition and angle into a world-space fence position.
	var fence_radius: float = maxf(platform_spec.z - FENCE_INSET, 0.1) # Reuses the inward radius used by the circular fence sampling logic.
	return Vector3(platform_spec.x + cos(angle) * fence_radius, platform_spec.w, platform_spec.y + sin(angle) * fence_radius) # Places the sample around the platform center at the platform's walkable top height.

func _is_point_exposed(point: Vector3, platform_index: int, platform_specs: Array[Vector4]) -> bool: # Reports whether a perimeter point lies outside every other overlapping platform footprint.
	for other_index in range(platform_specs.size()): # Checks the sample against every other cylinder participating in the level union.
		if other_index == platform_index: # Rejects the platform that owns the sampled perimeter point.
			continue # Continues directly to the next possible overlapping platform.
		var other_spec: Vector4 = platform_specs[other_index] # Reads the comparison platform center and radius.
		var offset_x: float = point.x - other_spec.x # Measures horizontal distance from the sampled point to the comparison platform center.
		var offset_z: float = point.z - other_spec.y # Measures depth distance from the sampled point to the comparison platform center.
		var interior_radius: float = maxf(other_spec.z - OVERLAP_CLEARANCE, 0.0) # Shrinks the comparison footprint slightly so fence openings appear only at meaningful overlaps.
		if offset_x * offset_x + offset_z * offset_z < interior_radius * interior_radius: # Detects a sample that sits safely inside another platform's playable footprint.
			return false # Removes fence from this overlap so the player can travel between the two cylinders.
	return true # Keeps fence on samples that form the exposed outer boundary of the combined level.

func _append_fence_segment(start_point: Vector3, end_point: Vector3, rail_transforms: Array[Transform3D]) -> void: # Adds two visible rails and one full-height collision box between neighboring perimeter points.
	var segment_direction: Vector3 = end_point - start_point # Measures the tangent direction and length between neighboring circular samples.
	segment_direction.y = 0.0 # Keeps fence segments level even when their owning platform height differs from neighboring cylinders.
	var segment_length: float = segment_direction.length() # Measures the exact rail and collision length required for this sampled arc segment.
	if segment_length <= 0.001: # Rejects degenerate neighboring points before normalizing orientation or creating collision.
		return # Skips invalid geometry without adding zero-sized physics shapes.
	var midpoint: Vector3 = (start_point + end_point) * 0.5 # Centers visuals and collision between the neighboring pickets.
	var yaw: float = atan2(-segment_direction.z, segment_direction.x) # Rotates each local X-aligned box so it follows the circular tangent in the XZ plane.
	var rail_basis: Basis = Basis(Vector3.UP, yaw).scaled_local(Vector3(segment_length, 1.0, 1.0)) # Applies segment length as local X scale after orienting the shared rail primitive.
	rail_transforms.append(Transform3D(rail_basis, midpoint + Vector3.UP * LOWER_RAIL_HEIGHT)) # Places the lower white rail between the neighboring pickets.
	rail_transforms.append(Transform3D(rail_basis, midpoint + Vector3.UP * UPPER_RAIL_HEIGHT)) # Places the upper white rail between the neighboring pickets.
	var box_shape: BoxShape3D = BoxShape3D.new() # Creates one inexpensive primitive collision box for this fence segment.
	box_shape.size = Vector3(segment_length, COLLISION_HEIGHT, COLLISION_DEPTH) # Matches collision length to the segment while blocking across the complete fence height.
	var collision_shape: CollisionShape3D = CollisionShape3D.new() # Creates the scene node that places this primitive shape on the shared static body.
	collision_shape.shape = box_shape # Assigns the configured primitive box to the fence collision node.
	collision_shape.position = midpoint + Vector3.UP * COLLISION_HEIGHT * 0.5 # Places collision from the platform surface to the top of the pickets.
	collision_shape.rotation = Vector3(0.0, yaw, 0.0) # Aligns the collision box with the same circular tangent as the visible rails.
	_collision.add_child(collision_shape) # Adds the completed blocking segment to the reusable static fence body.

func _create_picket_mesh() -> BoxMesh: # Creates the single primitive box mesh instanced for every vertical picket.
	var mesh: BoxMesh = BoxMesh.new() # Allocates one shared box primitive for all repeated fence posts.
	mesh.size = Vector3(PICKET_WIDTH, PICKET_HEIGHT, PICKET_WIDTH) # Gives each picket a narrow upright rectangular profile.
	mesh.material = _create_white_material() # Applies the simple white fence surface to the shared picket primitive.
	return mesh # Supplies the configured primitive to the MultiMesh renderer.

func _create_rail_mesh() -> BoxMesh: # Creates the single unit-length primitive box mesh instanced and scaled for every fence rail segment.
	var mesh: BoxMesh = BoxMesh.new() # Allocates one shared box primitive for all repeated horizontal rails.
	mesh.size = Vector3(1.0, RAIL_THICKNESS, RAIL_DEPTH) # Keeps local X at unit length so each instance transform can scale it to its sampled segment length.
	mesh.material = _create_white_material() # Applies the same simple white fence surface used by the pickets.
	return mesh # Supplies the configured primitive to the MultiMesh renderer.

func _create_white_material() -> StandardMaterial3D: # Creates the simple shared-looking surface used by primitive fence geometry.
	var material: StandardMaterial3D = StandardMaterial3D.new() # Allocates a lightweight standard material without external texture dependencies.
	material.albedo_color = Color(0.96, 0.96, 0.92, 1.0) # Gives the fence a slightly warm painted-white appearance.
	material.roughness = 0.88 # Keeps the painted primitive surfaces matte under the level lighting.
	return material # Supplies the configured material to the generated picket or rail primitive.

func _apply_multimesh(instance: MultiMeshInstance3D, mesh: Mesh, transforms: Array[Transform3D]) -> void: # Uploads one repeated primitive and all of its authored transforms as a single instanced renderer.
	var multimesh: MultiMesh = MultiMesh.new() # Creates the low-overhead GPU instancing resource for this fence element type.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D # Configures the buffer for complete 3D transforms before allocating instance storage.
	multimesh.mesh = mesh # Assigns the single primitive mesh shared by every fence instance in this renderer.
	multimesh.instance_count = transforms.size() # Allocates exactly the number of instances collected from exposed platform edges.
	for transform_index in range(transforms.size()): # Writes each precomputed world-space fence transform into the shared instance buffer.
		multimesh.set_instance_transform(transform_index, transforms[transform_index]) # Stores one picket or rail transform without creating another MeshInstance3D node.
	instance.multimesh = multimesh # Applies the completed GPU-instanced fence resource to its renderer node.

func _clear_collision() -> void: # Removes collision generated by an earlier deliberate rebuild of the same fence component.
	for child in _collision.get_children(): # Visits every generated collision segment currently owned by the static fence body.
		child.queue_free() # Schedules the old segment for removal before replacement geometry is used in later physics frames.
