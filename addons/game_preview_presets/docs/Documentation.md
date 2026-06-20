# Godot Game Preview Preset

**Version:** 1.0.0  
**Author:** Rohan Sen  
**Godot version:** Godot 4.6+  
**Plugin folder:** `addons/game_preview_presets`

Godot Game Preview Preset adds a Unity-style Game View workflow to Godot by building on top of Godot's built-in embedded **Game** tab. It gives you fast aspect-ratio switching, resolution presets, custom viewport sizes, live responsive preview changes, screenshots, and game-viewport frame recording without replacing Godot's native play/embed system.

The plugin is designed for teams that need to test the same game across portrait phones, landscape phones, tablets, desktop windows, ultrawide screens, and custom device sizes directly inside the Godot editor.

---

## Features

- Unity-style Game View preset workflow inside Godot.
- Uses Godot's existing embedded **Game** tab instead of native OS window hacks.
- Movable and scrollable editor dock.
- Project-aware aspect presets based on your configured project viewport.
- Built-in presets for portrait, landscape, tablet, desktop, ultrawide, square, and common ratios.
- Custom width and height input.
- Custom ratio input such as `9:16`, `16:9`, `2360x1640`, `2560x1080`, or decimal ratios.
- Runtime live switching while the game is already playing.
- Keep Aspect / Fit workflow for Unity-style responsive testing.
- Fixed Size workflow for pixel-perfect checks.
- Screenshot capture from the game viewport only.
- Frame-sequence recording from the game viewport only.
- Captures saved inside the project at `res://Captures`.
- Non-destructive preview workflow: temporary testing changes are not written permanently unless you explicitly press **Apply Project**.
- Optional debug launch hooks such as FPS, collisions, navigation, and paths.

---

## Repository structure

```text
Godot Game Preview Preset/
├── addons/
│   └── game_preview_presets/
│       ├── plugin.cfg
│       ├── plugin.gd
│       ├── game_preview_presets_dock.tscn
│       ├── game_preview_presets_dock.gd
│       ├── preset_manager.gd
│       ├── preview_session.gd
│       └── game_preview_runtime_bridge.gd
└── README.md
```

---

## Installation

### Option 1: Install from this repository

1. Download or clone this repository.
2. Copy this folder into your Godot project:

   ```text
   addons/game_preview_presets
   ```

3. Your project should look like this:

   ```text
   YourGodotProject/
   ├── project.godot
   └── addons/
       └── game_preview_presets/
           ├── plugin.cfg
           ├── plugin.gd
           ├── game_preview_presets_dock.tscn
           ├── game_preview_presets_dock.gd
           ├── preset_manager.gd
           ├── preview_session.gd
           └── game_preview_runtime_bridge.gd
   ```

4. Open the project in Godot.
5. Go to **Project > Project Settings > Plugins**.
6. Enable **Godot Game Preview Preset**.
7. A dock named **Godot Game Preview Preset** / **Game Preview Presets** will appear in the editor.

### Option 2: Install from ZIP

1. Extract the ZIP file.
2. Copy only the `addons/game_preview_presets` folder into your Godot project.
3. Reload the project if Godot does not detect the plugin immediately.
4. Enable the plugin from **Project > Project Settings > Plugins**.

> Important: The `addons` folder must be directly beside `project.godot`. Do not place the addon inside an extra nested folder.

Correct:

```text
YourGodotProject/addons/game_preview_presets/plugin.cfg
```

Incorrect:

```text
YourGodotProject/Godot Game Preview Preset/addons/game_preview_presets/plugin.cfg
```

---

## Required Godot Game tab setup

This plugin controls the workflow around Godot's embedded Game tab, but Godot's own embedding must be enabled.

Before using the plugin, open Godot's native **Game** tab and set:

```text
Embed Game on Next Play: ON
Make Game Workspace Floating on Next Play: OFF
Sizing: Keep Aspect Ratio
```

Recommended default for Unity-style preview testing:

```text
Embed: ON
Floating: OFF
Sizing: Keep Aspect / Fit
Use Size: ON
Live: ON
Responsive: ON
```

If the game still opens in a separate window, check that **Make Game Workspace Floating on Next Play** is disabled.

---

## Quick start

1. Enable the plugin.
2. Open the **Godot Game Preview Preset** dock.
3. Drag the dock to the left or right side of the editor so it does not reduce the Game tab height.
4. In the native Godot **Game** tab, enable embedded play and disable floating play.
5. In the plugin, choose an aspect or preset.
6. Keep **Sizing** set to **Keep Aspect / Fit** for Unity-style responsive preview.
7. Keep **Use Size**, **Live**, and **Responsive** enabled.
8. Click **Play**.
9. While the game is running, change the width, height, aspect, or custom ratio and click **Apply Live**.

---

## Typical workflows

### Test a portrait mobile game

For a project with base viewport `1080 x 1920`:

1. Choose **Aspect: 9:16 Portrait** or **Project Current**.
2. Confirm the size is `1080 x 1920`.
3. Set **Sizing** to **Keep Aspect / Fit**.
4. Enable **Use Size**, **Live**, and **Responsive**.
5. Click **Play**.

### Test landscape and ultrawide devices

While the game is running:

1. Enter `2560x1080` in the custom field.
2. Click **Use**.
3. Click **Apply Live** if live update does not trigger automatically.

You can also enter:

```text
16:9
21:9
64:27
2360x1640
2560x1080
1920x1080
1080x1920
```

### Pixel-perfect fixed-size testing

Use this only when you want to inspect exact pixels/device resolution.

1. Set **Sizing** to **Fixed Size**.
2. Choose or type the target size.
3. Adjust **Scale**.
4. Use **Apply Live** while the game is running.

For normal responsive testing, prefer **Keep Aspect / Fit** instead of **Fixed Size**.

---

## Controls and button descriptions

### Top toolbar

| Control | Description |
|---|---|
| **Play** | Runs the main scene using the selected preview settings. Intended for embedded Game tab testing. |
| **Stop** | Stops the currently running game session. |
| **Apply Live** | Sends the currently selected size, aspect, scale, and preview options to the running game. Use this when changing device sizes while the game is already running. |
| **Screenshot** | Saves a PNG screenshot from the game viewport only. The editor UI is not included. |
| **Record** | Starts recording the game viewport as a PNG frame sequence. |
| **Pause** | Pauses or resumes frame recording. |
| **Stop Rec** | Stops frame recording and saves the completed sequence in the `Captures` folder. |

### Aspect and size controls

| Control | Description |
|---|---|
| **Aspect** | Quick aspect-ratio selector. Includes project current, free, portrait, landscape, tablet, ultrawide, and common ratios. |
| **Preset** | Selects a saved preset. Presets can be built-in or project-local custom presets. |
| **Size** | Width and height fields for exact viewport testing. Example: `1080 x 1920`, `2360 x 1640`, `2560 x 1080`. |
| **Swap** | Swaps width and height to quickly switch between portrait and landscape. |
| **Custom** | Accepts ratio or size input. Examples: `9:16`, `16:9`, `21:9`, `2360x1640`, `2560x1080`, `1.777`. |
| **Use** | Applies the value typed in the Custom field to the width and height controls. |
| **Sizing** | Selects the preview sizing workflow: Free, Fixed Size, Keep Aspect / Fit, or Stretch. |
| **Scale** | Used for Fixed Size / pixel-perfect testing. It scales the fixed preview size for inspection. It is not needed for normal Keep Aspect / Fit responsive testing. |

### Toggle controls

| Control | Description |
|---|---|
| **Embed** | Requests Godot's built-in embedded Game tab workflow on next play. |
| **Floating** | If enabled, Godot may run the embedded game in a floating window. Keep this off for a docked Unity-style workflow. |
| **Focus Play** | Focuses the game when play starts, where supported by the editor. |
| **Mute** | Runs the preview with muted/dummy audio where supported. Useful for repeated testing. |
| **Use Size** | Uses the selected logical preview size when playing and live-switching. |
| **Live** | Allows changing the preview size/aspect while the game is already running. |
| **Responsive** | Applies temporary responsive scaling support so aspect switches are visible even when the project is not already configured for responsive scaling. |

### Debug control

| Control | Description |
|---|---|
| **Overlay: Off** | No debug overlay or debug launch flag. |
| **Print FPS** | Enables FPS/debug output when launching the game. |
| **Collisions** | Launches with visible collision debugging where supported. |
| **Navigation** | Launches with navigation debugging where supported. |
| **Paths** | Launches with path/debug drawing where supported. |

### Utility buttons

| Control | Description |
|---|---|
| **Project Size** | Restores the width and height fields to the project's current base viewport size. |
| **Save Preset** | Saves the current width, height, ratio, and mode as a project-local preset. |
| **Remove** | Removes the selected custom preset. Built-in presets are not intended to be removed. |
| **Refresh** | Reloads the preset list and project viewport information. |
| **Fix Game Tab** | Attempts to set Godot's Game tab workflow to embedded, non-floating, keep-aspect behavior. Some editor internals are version-dependent. |
| **Apply Project** | Permanently writes the selected size to Godot Project Settings. Use only when you intentionally want to change the project viewport. |
| **Defaults** | Restores the plugin preview controls to recommended defaults. |

---

## Captures

The plugin creates this folder automatically:

```text
res://Captures
```

### Screenshots

Screenshots are saved as PNG files:

```text
res://Captures/screenshot_YYYYMMDD_HHMMSS.png
```

The screenshot captures the running game viewport only, not the Godot editor UI.

### Recording

Recording is saved as a PNG frame sequence:

```text
res://Captures/recording_YYYYMMDD_HHMMSS/
├── frame_000001.png
├── frame_000002.png
├── frame_000003.png
└── recording_info.txt
```

The recording uses the same viewport capture path as Screenshot, so it is designed to capture the actual game viewport area rather than the editor window.

### Why PNG sequence instead of MP4?

This plugin intentionally does not claim MP4 export in version 1.0.0. Real MP4/H.264 encoding is not practical as a pure GDScript editor plugin without native encoder support or an external conversion pipeline. PNG sequence recording is stable, portable, and keeps the plugin dependency-free.

A future version can add MP4 export through a native/GDExtension encoder or optional external conversion step.

---

## Custom presets

Custom presets are saved per project. This lets each project keep its own target devices and aspect ratios.

Example presets you may want to save:

```text
1080 x 1920  - Mobile portrait
1920 x 1080  - Mobile landscape / desktop 16:9
2360 x 1640  - Tablet landscape
1640 x 2360  - Tablet portrait
2560 x 1080  - Ultrawide
```

To create a preset:

1. Enter width and height, or type a custom ratio/size.
2. Choose the sizing mode.
3. Click **Save Preset**.
4. The preset becomes available in the **Preset** dropdown.

---

## Recommended settings by use case

| Use case | Recommended sizing | Use Size | Live | Responsive | Scale |
|---|---|---:|---:|---:|---|
| Unity-style responsive aspect testing | Keep Aspect / Fit | On | On | On | Not needed |
| Test many phones/tablets quickly | Keep Aspect / Fit | On | On | On | Not needed |
| Desktop/ultrawide layout testing | Keep Aspect / Fit | On | On | On | Not needed |
| Pixel-perfect fixed resolution inspection | Fixed Size | On | On | Optional | Use slider |
| Stretch behavior testing | Stretch | On | On | Optional | Not needed |

---

## Important limitations

- The plugin does not replace Godot's native Game embedding system.
- The plugin does not use OS-specific hacks to embed external windows.
- Godot does not expose a fully stable public API for injecting custom controls directly into the native Game toolbar. This plugin uses a movable editor dock instead.
- Some internal editor settings for Game tab embedding may vary between Godot versions. If automatic embedding setup does not work, manually enable **Embed Game on Next Play** and disable **Make Game Workspace Floating on Next Play** in the native Game tab.
- MP4 recording is not included in version 1.0.0. Recording is saved as PNG frame sequences.
- Fullscreen testing should use normal non-embedded play. Embedded preview is intended for editor-first layout testing.

---

## Troubleshooting

### The plugin does not appear in Project Settings

Check that the folder is installed here:

```text
YourGodotProject/addons/game_preview_presets/plugin.cfg
```

Then reload the project.

### The game still opens in a floating window

Open the native Godot **Game** tab and check:

```text
Embed Game on Next Play: ON
Make Game Workspace Floating on Next Play: OFF
```

You can also press **Fix Game Tab** in the plugin.

### The image is cropped

Use **Keep Aspect / Fit** instead of **Fixed Size** for responsive Unity-style testing.

Also check that your game UI supports responsive layout. The plugin can change the preview size, but your Control anchors, containers, stretch settings, camera logic, and safe-area logic still need to support multiple aspect ratios.

### Runtime size does not change while playing

Check these plugin toggles:

```text
Use Size: ON
Live: ON
Responsive: ON
```

Then change the size or custom ratio and press **Apply Live**.

### Screenshots work but recording looks wrong

Recording uses repeated viewport screenshots. Make sure the game is running before pressing **Record**. Then use **Stop Rec** to finalize the recording folder.

### I accidentally changed my project viewport

Most preview operations are temporary. However, **Apply Project** intentionally writes to Project Settings. If you used it by mistake, open Godot Project Settings and restore your original viewport width and height.

---

## Development notes

The plugin is organized into small editor-tool components:

| File | Purpose |
|---|---|
| `plugin.gd` | Main `EditorPlugin` entry point. Registers the dock and runtime bridge. |
| `game_preview_presets_dock.gd` | Builds and controls the editor UI. |
| `preset_manager.gd` | Handles built-in presets, project viewport size, custom presets, and preset persistence. |
| `preview_session.gd` | Applies play-session settings, launch arguments, temporary project/editor settings, and restoration. |
| `game_preview_runtime_bridge.gd` | Runtime autoload used for live preview switching, screenshots, and frame capture. |
| `game_preview_presets_dock.tscn` | Reusable dock scene. |
| `plugin.cfg` | Godot plugin metadata. |

---

## Version history

### 1.0.0

Initial stable release.

- Unity-style preview preset dock.
- Project-aware aspect and resolution presets.
- Custom size and custom ratio input.
- Live responsive preview switching.
- Screenshot capture.
- PNG frame-sequence recording.
- Captures saved to `res://Captures`.
- Non-destructive preview workflow.
- Godot 4.6+ support.

---

## License

Add your chosen license here before publishing the repository. Common options include MIT, Apache-2.0, or a proprietary/internal license.
