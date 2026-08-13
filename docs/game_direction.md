# Torn Apart — game direction

## Core presentation

Torn Apart should feel like a physical storybook or tabletop diorama. Characters are visually flat paper pieces, while the spaces they occupy are real 3D environments with depth, collision, height, ramps, platforms, props, and camera composition.

The project should take inspiration from the broad design language of paper-themed RPGs without copying protected characters, art, names, story material, music, or level layouts.

## Gameplay pillars

1. **Exploration** — compact 3D areas with readable paths, secrets, jumps, environmental interactions, and strong visual composition.
2. **Character interaction** — dialogue-heavy encounters, NPC reactions, party banter, and environmental storytelling.
3. **Timing-based battles** — turn-based decisions strengthened by player timing for attacks, guards, dodges, or special moves.
4. **Paper-world mechanics** — gameplay that makes the flat-character/3D-world contrast mechanically relevant rather than purely cosmetic.

## Architecture rules

- Keep movement, visuals, camera, combat, dialogue, interaction, inventory, and save data in separate systems.
- Prefer scene composition over large inheritance trees.
- Keep gameplay state out of visual-only nodes.
- Avoid signals for project gameplay flow; use direct composition and explicit method calls.
- Use strongly typed GDScript wherever Godot's type system allows it.
- Keep input behind named actions such as `StickLeft_North` and `Button_A` rather than hardcoding device input inside gameplay code.
- Build UI with Godot Control nodes in scenes rather than drawing interface elements manually in gameplay scripts.

## Milestones

### Milestone 1 — overworld foundation

Implemented in the initial project bootstrap:

- player movement and collision
- jump and gravity
- flat paper visual component
- orthographic follow camera
- prototype 3D room
- keyboard and controller input fallbacks

### Milestone 2 — interaction and dialogue

- reusable interactable component
- interaction targeting and prompts
- dialogue data model
- dialogue UI
- NPC facing and simple state control

### Milestone 3 — battle vertical slice

- transition from overworld encounter into battle scene
- player and enemy combatants
- turn order
- basic attack
- timed input window
- damage and health
- return to overworld with encounter state preserved

### Milestone 4 — paper mechanics

Choose mechanics that are original to Torn Apart. Possible directions include folding through gaps, rotating into a thin edge to pass obstacles, tearing/rejoining paths, layering paper planes, or changing which depth layer a character occupies.
