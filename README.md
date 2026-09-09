<h1 align="center">Gimbal</h1>

<p align="center">A summoned-overlay <a href="https://github.com/quickshell-mirror/quickshell">Quickshell</a> shell for wlroots Wayland. No bar — nothing is on screen until you call it.</p>

---

## What it is

Gimbal has no persistent chrome. You bind two keys:

- **the overlay** — a circular reveal onto a clock page, a wallpaper picker, and notification history, with a hold-to-confirm power/suspend arm
- **the launcher** — a Spotlight-style bar: apps, files, clipboard history, a calculator, and run-a-command, all behind single-character prefixes, ranked by frecency, with an inspect card for previews

It also owns your wallpaper (static / GIF / video, cross-faded on switch) and repaints itself from the wallpaper's colours.

## Features

**Overlay**
- Circular reveal in/out from a configurable origin
- Clock page — time, date, weather, battery
- Wallpaper picker — infinite parallax carousel, live video previews, cross-fade apply
- Power arm — `↑`/`↓` arms shutdown / suspend, `enter` confirms; entering the wallpaper picker cancels it

**Launcher**
- `apps` (default) · `>` run a command · `=` calculator · `/` or `~` files & folders · `;` clipboard history
- Frecency ranking — what you actually reach for floats up
- Files: `enter` = smart open (project dir → editor, else file manager), `ctrl+enter` = editor, `alt+enter` = file manager, `shift+enter` = terminal there. It **learns** your pick per directory.
- Inspect card (`tab`) — text/image/video previews, colour swatches, binary metadata, app details; scrollable, mouse-locked
- Clipboard rows show image thumbnails

**Notifications**
- Own `org.freedesktop.Notifications` server (disable mako / dunst / swaync)
- Toasts drop from the top-centre as a shallow deck; hover pauses the timer, critical stays until dismissed
- History page (`n` in the overlay) — grouped by app, per-item + clear-all, DND toggle, action buttons on still-live notifications

**Wallpaper**
- Quickshell draws it directly (kills `wbg` on start)
- `~/Pictures/Wallpapers` scanned on every picker open
- Video via QtMultimedia (ffmpeg backend); first-frame posters via ffmpeg
- Cross-fade transition on both the desktop and the overlay's frosted backdrop
- `gimbal wallpaper next|prev|random|set <name>|list`

**Colours**
- Wallpaper → palette written to `~/.config/gimbal/colors.json`, live-reloaded by the theme
- [matugen](https://github.com/InioX/matugen) when present (proper Material You); ImageMagick histogram derivation otherwise

## Install

**Arch:**

```sh
git clone <this-repo> ~/.local/share/gimbal
~/.local/share/gimbal/install.sh
```

The script checks dependencies, installs the missing ones (`pacman` + `paru`/`yay` for AUR), links `gimbal` into `~/.local/bin`, and seeds `~/.config/gimbal/config.json`.

**Anything else:** run it from a checkout — `path/to/gimbal start` — after installing the dependencies below. `gimbal` figures out its own location.

### Dependencies

| | package | enables |
|---|---|---|
| **required** | `quickshell` (AUR) | the runtime — needs Wayland + the UPower service |
| | `wl-clipboard`, `cliphist` | clipboard history (`wl-paste --watch cliphist store` must run) |
| | `imagemagick` | wallpaper colour palette |
| **optional** | `qt6-multimedia` | video wallpapers |
| | `ffmpeg` | video wallpaper poster frames |
| | `upower` | battery on the clock page |
| | `curl` | weather on the clock page |
| | `file` | richer file-type detection in the inspect card |
| | `matugen` | Material You palette instead of the ImageMagick fallback |

> matugen `4.0.0` currently fails colour extraction outside a TTY — until that's fixed, pin `3.x` or just rely on the ImageMagick fallback.

Fonts (AdwaitaMono, Lucide) are bundled in `assets/fonts/`.

## Usage

```
gimbal start            run the daemon (compositor autostart)
gimbal launch           the launcher
gimbal toggle [page]    summon / dismiss the overlay  (page: clock | wallpaper | notifications)
gimbal wallpaper …      next | prev | random | rescan | list | <name>
```

**In the overlay:** `w` → wallpaper picker · `n` → notifications · `←`/`→` cycle · `enter` apply · `↑`/`↓` arm power · `esc` close

**In the launcher:** type a prefix, `↑`/`↓` to move, `tab` to inspect, `enter` to run.

### Compositor integration

<details><summary>mango</summary>

```
exec-once=gimbal start
bind=SUPER+SHIFT,a,spawn_shell,gimbal launch
bind=SUPER,Tab,spawn_shell,gimbal toggle
```
</details>

<details><summary>Hyprland</summary>

```
exec-once = gimbal start
bind = SUPER SHIFT, A, exec, gimbal launch
bind = SUPER, Tab, exec, gimbal toggle
```
</details>

<details><summary>niri</summary>

```
spawn-at-startup "gimbal" "start"
binds {
    "Mod+Shift+A" { spawn "gimbal" "launch"; }
    "Mod+Tab"     { spawn "gimbal" "toggle"; }
}
```
</details>

<details><summary>sway / river</summary>

```
exec gimbal start
bindsym $mod+Shift+a exec gimbal launch
bindsym $mod+Tab exec gimbal toggle
```
</details>

## Config

`~/.config/gimbal/config.json` (live-reloaded):

```json
{
  "editor": "code",
  "fileManager": "nautilus",
  "terminal": "foot",
  "dirOpen": "smart",
  "fileRoots": ["~/Projects", "~/Documents", "~/Downloads"]
}
```

`dirOpen` — what plain `enter` does on a directory before it's learned a pick: `smart` | `editor` | `files` | `terminal`.

Env vars override the file: `GIMBAL_EDITOR`, `GIMBAL_FILE_MANAGER`, `GIMBAL_TERMINAL`, `GIMBAL_DIR_OPEN`, `GIMBAL_FILE_ROOTS` (`:`-separated), `GIMBAL_WALLPAPER_DIR`.

State (frecency, current wallpaper, video posters) lives under `~/.local/state/gimbal` and `~/.cache/gimbal`.

## Credits

Gimbal is a rebuild of ideas from **[pibble](https://github.com/kianblakley/pibble)** by [kian blakley](https://github.com/kianblakley) — the summoned-shell approach, the wallpaper carousel's spatial model (parallax windows, scale falloff, continuous rank), the clipboard inspect card, live-wallpaper handling, and matugen-driven theming all trace back to it. If you want the full-featured version with in-app settings, custom pages, and flyouts, use pibble.

Built with [Quickshell](https://github.com/quickshell-mirror/quickshell). Palette by [matugen](https://github.com/InioX/matugen). Icons from [Lucide](https://lucide.dev).
