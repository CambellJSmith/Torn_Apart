# slime_enemy_sprites

Drop the final transparent slime PNGs into this folder using these exact names:

- `slime_green.png`
- `slime_yellow.png`
- `slime_red.png`

The enemy scene loads these resources at runtime so the gameplay code remains valid before the image files are added. Godot will create the corresponding import metadata when the files are first opened by the editor.
