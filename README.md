# Godot Game Preview Preset v1.0.0

**Author:** Rohan Sen  
**Godot:** 4.6+

Godot Game Preview Preset adds a Unity-style Game View workflow on top of Godot's built-in embedded Game tab. It does not replace or hack native window embedding. Instead, it adds the missing editor UX layer for fast aspect-ratio testing, responsive preview switching, screenshots, and game-viewport capture.

## Main features

- Unity-style aspect and resolution presets.
- Project-aware portrait and landscape sizing.
- Custom width/height and custom ratio entry.
- Live preview switching while the game is running.
- Fixed Size, Keep Aspect / Fit, and Stretch-style workflow controls.
- Screenshot capture from the running game viewport only.
- Recording as a PNG frame sequence from the running game viewport only.
- Captures saved inside `res://Captures`.
- Movable, scrollable Godot dock UI.
- Non-destructive play overrides where possible.

## Capture behavior

Screenshots save PNG files to:

`res://Captures`

Recording saves a PNG frame sequence to:

`res://Captures/recording_YYYYMMDD_HHMMSS/frame_000001.png`

This version intentionally does not advertise MP4/MKV/AVI export. Pure GDScript cannot reliably encode a real MP4/H.264 file. A production MP4 recorder should be implemented later with a native/GDExtension encoder or an external post-process pipeline.

## Install

1. Copy `addons/game_preview_presets` into your Godot project.
2. Reload the project.
3. Open **Project > Project Settings > Plugins**.
4. Enable **Godot Game Preview Preset**.

## Recommended setup

In Godot's native **Game** tab:

- Enable **Embed Game on Next Play**.
- Disable **Make Game Workspace Floating on Next Play**.
- Use **Keep Aspect Ratio** for Unity-style responsive preview testing.

In the plugin dock:

- Choose a preset or enter a custom size.
- Enable live switching if you want to change sizes while the game is running.
- Use **Screenshot**, **Record**, **Pause**, and **Stop Rec** from the top toolbar.

## Notes

Godot does not expose a stable public API for injecting custom controls directly into the native Game toolbar. The plugin therefore uses a clean, movable, scrollable dock that can be placed beside the Game tab.
