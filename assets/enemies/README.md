# slime_enemy_sprites

The three slime sprites are imported directly by their reusable variant scenes:

- `slime_green.png` → `scenes/enemies/slime_green.tscn`
- `slime_yellow.png` → `scenes/enemies/slime_yellow.tscn`
- `slime_red.png` → `scenes/enemies/slime_red.tscn`

Enemy placement belongs to each level scene. Shared movement, ledge detection, stomp, and contact-damage behaviour remains in `scripts/enemies/slime_enemy.gd`.
