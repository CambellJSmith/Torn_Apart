# Torn Apart

Torn Apart is a Godot 4.6 project exploring a paper-cutout RPG presentation: flat characters moving through a fully 3D diorama world.

## Current playable foundation

- 3D overworld built from `StaticBody3D` collision and simple prototype geometry.
- Flat paper-character presentation composed separately from the gameplay body.
- `CharacterBody3D` movement, acceleration, jumping, gravity, slopes/floor handling, and collision.
- Orthographic follow camera for a storybook/diorama presentation.
- Keyboard and gamepad fallback mappings using the project's preferred action names.
- Systems are split by responsibility so combat, dialogue, party members, interaction, and animation can grow independently.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| `StickLeft_North` | W | Left stick up |
| `StickLeft_South` | S | Left stick down |
| `StickLeft_West` | A | Left stick left |
| `StickLeft_East` | D | Left stick right |
| `Button_A` | Space | A / Cross |
| `Button_Start` | Escape | Start / Options |

The fallback bindings are only created if an action does not already exist, so future project or player-defined mappings are preserved.

## Run

Open `project.godot` in Godot 4.6.x and run the project. The current target version is Godot 4.6.3 stable.

## Direction

The prototype deliberately uses original placeholder geometry rather than copying Nintendo assets. The design target is the broad genre language: readable paper characters, diorama-like 3D spaces, exploration, character-driven dialogue, and eventually timing-focused turn-based combat.

See `docs/game_direction.md` for the initial system roadmap.
