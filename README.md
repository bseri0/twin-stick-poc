# Twin-stick touch controls (proof of concept)

A tiny Godot 4.7 project to try a two-thumb control scheme for a mobile game. Portrait 540 x 960, everything drawn in
code, no assets, no server.

**Play it in your browser (phone or desktop):** https://bseri0.github.io/twin-stick-poc/

## Controls

- **Left stick:** move. Drag to run, let go to stop. (Desktop: arrow keys also work.)
- **Right stick:** the action button, with a little aim.
  - **Tap** acts on the best target in range: nearest enemy for Attack and Defend, most-hurt of you or the ally for Heal.
  - **Hold** keeps acting (Attack fires every 0.35 s, Heal every 0.9 s, Defend holds the shield up).
  - **Hold + drag** points it. Aim assist pulls the aim 65% of the way onto any target inside a 30° cone around your
    drag; outside the cone you get your raw direction.
- **ATK / HEAL / DEF** above the right stick pick what it does. Cooldown shows as a sweep on the button.
  - Attack: shoots a bolt (20 damage; red dummies have 60 HP and respawn after 4 s).
  - Heal: +18 HP on you or the blue ally (drag toward the ally to pick them).
  - Defend: a 130° shield in the aim direction that blocks incoming shots; you move at half speed while it's up.

Each stick follows its own finger, so both thumbs work at once.

## Run it

- **Browser:** the link above. On a phone, add it to the home screen for full screen.
- **Windows:** double-click `play.bat` (needs Godot 4.7.2, standard build).
- **Editor:** open `project.godot` in Godot 4.7 and press F5. Debug > Deploy with Remote Debug runs it on a phone.
- Flags: `-- --demo` fakes both thumbs; `-- --shot=out.png` saves a screenshot after ~2 s and quits.

## Rebuild the web version

Install the Godot 4.7.2 export templates (Editor > Manage Export Templates), then Project > Export > Web > Export
Project, or from a terminal:

```sh
godot --headless --path . --export-release "Web" docs/index.html
```

The build uses the no-threads web template so it runs on GitHub Pages (which can't send the cross-origin isolation
headers threaded builds need). GitHub Pages serves the `docs/` folder.

## Tuning knobs (top of `main.gd`)

`ASSIST_CONE`, `ASSIST_PULL`, `RANGE`, `COOLDOWN`, `SHIELD_ARC`, `SPEED`. Stick sizes are `RADIUS` in
`move_stick.gd` / `action_stick.gd`.

## Files

- `main.gd`: the little world (player, ally, dummies, bolts), aim assist, drawing, HUD.
- `move_stick.gd`: left stick. `action_stick.gd`: right stick. `mode_buttons.gd`: the three selectors.

For a server-authoritative game, keep the sticks, selectors and aim assist on the client and have the right stick send
an intention (`attack`/`heal`/`defend` with a target or direction); the damage, healing and blocking here would move to
the server.
