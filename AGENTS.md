# GetTheMechOuttaDodge

A first-person mech extraction shooter built with the **Godot 4.7** engine. Pure GDScript
(no C#/Mono, no external package manager). Source lives in `scripts/`, `scenes/`, `actors/`,
`world/`, `ui/`, `autoload/`, and `data/`. The main scene is `scenes/title.tscn`.

## Cursor Cloud specific instructions

The environment startup/update script installs the Godot 4.7 editor binary and symlinks it as
`godot` (on `PATH`). There are no other dependencies to install.

### Rendering: no GPU — you MUST use the OpenGL compatibility renderer

The project defaults to **Forward Plus (Vulkan)**, but the cloud VM has **no Vulkan ICD / no GPU**.
Launching with the default renderer will fail. Always run the game with software OpenGL
(Mesa `llvmpipe`) instead:

```bash
godot --rendering-driver opengl3 --rendering-method gl_compatibility
```

- A desktop X server is available on `DISPLAY=:1` (via Xvfb) for GUI runs; prefix commands with
  `DISPLAY=:1` when launching the windowed game.
- Audio has no sound card and falls back to Godot's "dummy" audio driver. The
  `ALSA ... cannot find card '0'` warnings are expected and harmless.

### Importing assets

Godot auto-imports on first run. To pre-generate the (gitignored) `.godot/` import cache
explicitly and surface any GDScript parse errors, run:

```bash
godot --headless --import
```

### Lint / parse check

There is no separate GDScript linter or automated test suite in this repo. Loading the project
compiles every script, so `godot --headless --import` (or a short `godot --headless` run) is the
way to catch parse/compile errors — a clean run means all scripts parsed.

### Running / testing the game

- Headless smoke test (no window, catches script errors):
  `godot --headless`
- Windowed run (for screenshots / manual play), software renderer:
  `DISPLAY=:1 godot --rendering-driver opengl3 --rendering-method gl_compatibility`
- From the title menu, **QUICK DEPLOY** drops you into a first-person raid map and
  **ENTER HANGAR** opens the customization/hangar scene — both exercise the core loop.
- In-game controls: `WASD` move, mouse look, `E` interact, `F` board, `G` hold hotwire, `LMB` fire.

### Exporting a build

The `export_presets.cfg` targets Windows Desktop and needs export templates that are not
installed here; a headless `--rendering-driver opengl3` run is the primary way to validate
changes in this environment.
