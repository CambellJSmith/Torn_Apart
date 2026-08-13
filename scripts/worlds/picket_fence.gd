extends Node3D # Builds a reusable primitive white picket fence around exposed circular platform edges.
class_name TornPicketFence # Gives the fence component a strongly typed project-wide class name.

const FENCE_INSET: float = 0.28 # Pulls the fence slightly inward from each visible platform edge.
const VISUAL_SAMPLE_SPACING: float = 0.62 # Controls dense visual picket spacing around circular platforms.
const COLLISION_SAMPLE_SPACING: float = 1.9 # Uses much wider physics samples than the decorative fence geometry.
const OVERLAP_CLEARANCE: float = 0.32 # Opens fence gaps wherever another platform substantially overlaps the current perimeter.
const PICKET_WIDTH: float = 0.13 # Defines the horizontal thickness of each repeated primitive picket.
const PICKET_HEIGHT: float = 1.05 # Defines the visible height of each primitive picket above its platform surface.
const RAIL_THICKNESS: float = 0.11 # Defines the vertical thickness shared by the two horizontal fence rails.
const RAIL_DEPTH: float = 0.10 # Defines the depth of each horizontal fence rail.
const LOWER_RAIL_HEIGHT: float = 0.35 # Positions the lower horizontal rail above the platform surface.
const UPPER_RAIL_HEIGHT: float = 0.72 # Positions the upper horizontal rail above the platform surface.
const COLLISION_HEIGHT: float = 1.05 # Gives the simplified invisible perimeter enough height to stop player and enemy bodies.

@onready var _pickets: MultiMeshInstance3D = $pickets # Caches the GPU-instanced picket renderer.
@onready var _rails: MultiMeshInstance3D = $rails # Caches the GPU-instanced horizontal rail renderer.
@onready var _collision_shape: CollisionShape3D = $collision/shape # Caches the single static collision node used by the complete fence perimeter.

func build(platform_specs: Array[TornPlatformSpec]) -> void: # Rebuilds decorative fence instances and one simplified collision shape from typed platform definitions.
	var picket_transforms: Array[Transform3D] = [] # Collects every visible picket transform before allocating the shared MultiMesh buffer.
	var rail_transforms: Array[Transform3D] = [] # Collects both horizontal rails for every exposed visual perimeter segment.
	for platform_index: int in range(platform_specs.size()): # Visits every circular platform to collect its exposed decorative edge.
		_collect_visual_fence(platform_index, platform_specs, picket_transforms, rail_transforms) # Adds visual transforms while leaving overlaps open for traversal.
	var white_material: StandardMaterial3D = _create_white_material() # Creates one simple painted-white material shared by both repeated primitive meshes.
	_apply_multimesh(_pickets, _create_picket_mesh(white_material), picket_transforms) # Uploads all repeated pickets through one instanced renderer.
	_apply_multimesh(_rails, _create_rail_mesh(white_material), rail_transforms) # Uploads all repeated rails through one instanced renderer.
	_build_collision(platform_specs) # Builds one coarse static concave shape independently from the denser decorative samples.

func _collect_visual_fence(platform_index: int, platform_specs: Array[TornPlatformSpec], picket_transforms: Array[Transform3D], rail_transforms: Array[Transform3D]) -> void: # Samples one platform perimeter for visible pickets and rails.
	var platform_spec: TornPlatformSpec = platform_specs[platform_index] # Reads the typed platform definition for this visual perimeter.
	var fence_radius: float = maxf(platform_spec.radius - FENCE_INSET, 0.1) # Calculates the inward fence radius while preventing invalid tiny circles.
	var sample_count: int = maxi(16, int(ceil(TAU * fence_radius / VISUAL_SAMPLE_SPACING))) # Derives enough decorative samples for a readable circular fence.
	for sample_index: int in range(sample_count): # Walks each visual perimeter sample exactly once.
		var current_angle: float = TAU * float(sample_index) / float(sample_count) # Converts the current visual sample index into a circular angle.
		var next_angle: float = TAU * float((sample_index + 1) % sample_count) / float(sample_count) # Resolves the following sample with circular wraparound.
		var current_point: Vector3 = _get_perimeter_point(platform_spec, current_angle) # Calculates the current world-local fence point on the platform surface.
		var next_point: Vector3 = _get_perimeter_point(platform_spec, next_angle) # Calculates the neighboring world-local fence point.
		var current_exposed: bool = _is_point_exposed(current_point, platform_index, platform_specs) # Detects whether another platform covers the current perimeter section.
		var next_exposed: bool = _is_point_exposed(next_point, platform_index, platform_specs) # Detects whether the neighboring sample remains on the outside edge.
		if current_exposed: # Adds a visible picket only on the exposed outside perimeter.
			picket_transforms.append(Transform3D(Basis.IDENTITY, current_point + Vector3.UP * PICKET_HEIGHT * 0.5)) # Places one upright primitive picket with its base on the platform surface.
		if current_exposed and next_exposed: # Adds rails only between two exposed samples so platform overlaps remain open.
			_append_visual_rails(current_point, next_point, rail_transforms) # Adds the two painted-white rails for this decorative segment.

func _append_visual_rails(start_point: Vector3, end_point: Vector3, rail_transforms: Array[Transform3D]) -> void: # Adds two visible primitive rail instances between neighboring pickets.
	var segment_direction: Vector3 = end_point - start_point # Measures the tangent direction between neighboring circular samples.
	segment_direction.y = 0.0 # Keeps visual rails level across each platform perimeter.
	var segment_length: float = segment_direction.length() # Measures the exact local X scale needed by the shared rail primitive.
	if segment_length <= 0.001: # Rejects degenerate neighboring points before orientation work.
		return # Skips invalid zero-length visual geometry.
	var midpoint: Vector3 = (start_point + end_point) * 0.5 # Centers both rail instances between the neighboring pickets.
	var yaw: float = atan2(-segment_direction.z, segment_direction.x) # Rotates local X so the shared box follows the circular tangent.
	var rail_basis: Basis = Basis(Vector3.UP, yaw).scaled_local(Vector3(segment_length, 1.0, 1.0)) # Applies tangent orientation and exact segment length to the unit rail mesh.
	rail_transforms.append(Transform3D(rail_basis, midpoint + Vector3.UP * LOWER_RAIL_HEIGHT)) # Places the lower decorative rail.
	rail_transforms.append(Transform3D(rail_basis, midpoint + Vector3.UP * UPPER_RAIL_HEIGHT)) # Places the upper decorative rail.

func _build_collision(platform_specs: Array[TornPlatformSpec]) -> void: # Builds one coarse two-sided static trimesh for the complete exposed fence perimeter.
	var faces: PackedVector3Array = PackedVector3Array() # Collects triangle vertices for one ConcavePolygonShape3D instead of many child collision shapes.
	for platform_index: int in range(platform_specs.size()): # Visits every platform independently for simplified collision sampling.
		var platform_spec: TornPlatformSpec = platform_specs[platform_index] # Reads the typed platform definition used by this collision perimeter.
		var fence_radius: float = maxf(platform_spec.radius - FENCE_INSET, 0.1) # Uses the same inward edge as the decorative fence.
		var sample_count: int = maxi(10, int(ceil(TAU * fence_radius / COLLISION_SAMPLE_SPACING))) # Uses substantially fewer collision samples than visible pickets.
		for sample_index: int in range(sample_count): # Walks the coarse perimeter samples exactly once.
			var current_angle: float = TAU * float(sample_index) / float(sample_count) # Converts the current collision sample into a circular angle.
			var next_angle: float = TAU * float((sample_index + 1) % sample_count) / float(sample_count) # Resolves the next coarse sample with wraparound.
			var current_point: Vector3 = _get_perimeter_point(platform_spec, current_angle) # Calculates the current coarse collision point.
			var next_point: Vector3 = _get_perimeter_point(platform_spec, next_angle) # Calculates the neighboring coarse collision point.
			if not _is_point_exposed(current_point, platform_index, platform_specs): # Leaves collision open when another platform covers the current perimeter sample.
				continue # Skips this coarse segment start when it belongs to a traversal overlap.
			if not _is_point_exposed(next_point, platform_index, platform_specs): # Leaves collision open when the neighboring sample enters a traversal overlap.
				continue # Skips the complete segment so the overlap gap remains reliably passable.
			_append_collision_quad(current_point, next_point, faces) # Adds two triangles for one simplified vertical barrier panel.
	if faces.is_empty(): # Handles levels that intentionally have no exposed fence perimeter.
		_collision_shape.shape = null # Removes stale collision instead of keeping a previous build alive.
		return # Finishes collision rebuilding for the empty-perimeter case.
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new() # Creates one static trimesh collision resource for the complete fence.
	shape.backface_collision = true # Makes the thin barrier collide reliably from either side of its triangle faces.
	shape.set_faces(faces) # Uploads the simplified triangle list as one collision shape.
	_collision_shape.shape = shape # Applies the complete coarse fence collision to the single StaticBody child shape.

func _append_collision_quad(start_point: Vector3, end_point: Vector3, faces: PackedVector3Array) -> void: # Appends two triangles forming one vertical coarse fence barrier panel.
	var start_top: Vector3 = start_point + Vector3.UP * COLLISION_HEIGHT # Calculates the upper edge above the first coarse perimeter point.
	var end_top: Vector3 = end_point + Vector3.UP * COLLISION_HEIGHT # Calculates the upper edge above the neighboring coarse perimeter point.
	faces.append(start_point) # Adds the first lower vertex of the panel's first triangle.
	faces.append(end_point) # Adds the second lower vertex of the panel's first triangle.
	faces.append(end_top) # Adds the upper neighboring vertex completing the first triangle.
	faces.append(start_point) # Reuses the first lower vertex for the second triangle.
	faces.append(end_top) # Reuses the opposite upper vertex for the second triangle.
	faces.append(start_top) # Adds the final upper vertex completing the rectangular barrier panel.

func _get_perimeter_point(platform_spec: TornPlatformSpec, angle: float) -> Vector3: # Converts one typed platform definition and angle into a level-local fence position.
	var fence_radius: float = maxf(platform_spec.radius - FENCE_INSET, 0.1) # Reuses the inward radius shared by visual and collision sampling.
	return Vector3(platform_spec.center.x + cos(angle) * fence_radius, platform_spec.top_height, platform_spec.center.y + sin(angle) * fence_radius) # Places the sample around the platform center at its walkable height.

func _is_point_exposed(point: Vector3, platform_index: int, platform_specs: Array[TornPlatformSpec]) -> bool: # Reports whether a perimeter point lies outside every other platform footprint.
	for other_index: int in range(platform_specs.size()): # Checks this sample against every other cylinder participating in the level union.
		if other_index == platform_index: # Rejects the platform that owns the sampled perimeter.
			continue # Continues directly to the next possible overlapping platform.
		var other_spec: TornPlatformSpec = platform_specs[other_index] # Reads the comparison platform through named typed fields.
		var offset_x: float = point.x - other_spec.center.x # Measures horizontal distance from the sample to the comparison platform center.
		var offset_z: float = point.z - other_spec.center.y # Measures depth distance from the sample to the comparison platform center.
		var interior_radius: float = maxf(other_spec.radius - OVERLAP_CLEARANCE, 0.0) # Shrinks the comparison footprint so gaps appear only at meaningful overlaps.
		if offset_x * offset_x + offset_z * offset_z < interior_radius * interior_radius: # Detects a point safely inside another platform's playable footprint.
			return false # Removes fence visual and collision from the traversal overlap.
	return true # Keeps samples that form the exposed outside boundary of the combined platform layout.

func _create_picket_mesh(material: StandardMaterial3D) -> BoxMesh: # Creates the one primitive mesh shared by every vertical picket instance.
	var mesh: BoxMesh = BoxMesh.new() # Allocates a single box primitive for all repeated pickets.
	mesh.size = Vector3(PICKET_WIDTH, PICKET_HEIGHT, PICKET_WIDTH) # Gives the shared picket mesh its narrow upright profile.
	mesh.material = material # Reuses the one painted-white material created for this fence build.
	return mesh # Supplies the configured primitive to the MultiMesh renderer.

func _create_rail_mesh(material: StandardMaterial3D) -> BoxMesh: # Creates the unit-length primitive mesh shared by every horizontal rail instance.
	var mesh: BoxMesh = BoxMesh.new() # Allocates a single box primitive for all repeated rails.
	mesh.size = Vector3(1.0, RAIL_THICKNESS, RAIL_DEPTH) # Keeps local X at unit length so instance transforms provide exact segment length.
	mesh.material = material # Reuses the same painted-white material as the pickets.
	return mesh # Supplies the configured unit rail to the MultiMesh renderer.

func _create_white_material() -> StandardMaterial3D: # Creates the simple painted surface shared by all primitive fence visuals.
	var material: StandardMaterial3D = StandardMaterial3D.new() # Allocates one lightweight standard material for the complete fence build.
	material.albedo_color = Color(0.96, 0.96, 0.92, 1.0) # Gives the fence a slightly warm painted-white appearance.
	material.roughness = 0.88 # Keeps the primitive fence surfaces broadly matte under level lighting.
	return material # Supplies the shared material to both repeated mesh types.

func _apply_multimesh(instance: MultiMeshInstance3D, mesh: Mesh, transforms: Array[Transform3D]) -> void: # Uploads one repeated primitive and all transforms as a single instanced renderer.
	var multimesh: MultiMesh = MultiMesh.new() # Creates the low-overhead GPU instancing resource for this fence element type.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D # Configures storage for complete 3D transforms before allocating instances.
	multimesh.mesh = mesh # Assigns the one primitive mesh shared by every instance.
	multimesh.instance_count = transforms.size() # Allocates exactly the number of collected visual instances.
	for transform_index: int in range(transforms.size()): # Writes each precomputed visual transform into the shared instance buffer.
		multimesh.set_instance_transform(transform_index, transforms[transform_index]) # Stores one picket or rail without creating another MeshInstance3D node.
	instance.multimesh = multimesh # Applies the completed instanced resource to its renderer node.
