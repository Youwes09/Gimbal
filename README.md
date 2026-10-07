<h1 align="center">Gimbal</h1>

<p align="center">A summoned <a href="https://github.com/quickshell-mirror/quickshell">Quickshell</a> shell for wlroots Wayland. No bar — nothing is on screen until you call it.</p>

---

## What it is

Gimbal has no persistent chrome. You bind two keys:

- **the dashboard** — a game-bar style overlay around the search bar: now playing (art, seek, controls), volume / brightness sliders, screenshot / record / DND, live CPU / RAM / GPU, power (rest, suspend, reboot and shut down with a confirm click), and a wallpaper strip
- **the launcher** — the search bar on its own: a Spotlight-style bar: apps, files, clipboard history, a calculator, and run-a-command, all behind single-character prefixes, ranked by frecency, with an inspect card for previews

It also owns your wallpaper (static / GIF / video, cross-faded on switch), repaints itself from the wallpaper's colours, and quietly handles notifications, volume/brightness popups and screenshots.

## Features

**Launcher**
- `apps` (default) · `>` run a command · `=` calculator · `/` or `~` files & folders · `;` clipboard history
- Frecency ranking — what you actually reach for floats up
- Files: `enter` = smart open (project dir → editor, else file manager), `ctrl+enter` = editor, `alt+enter` = file manager, `shift+enter` = terminal there. It **learns** your pick per directory.
- Inspect card (`tab`) — text/image/video previews, colour swatches, binary metadata, app details; scrollable, mouse-locked
- Clipboard rows show image thumbnails
- Type `dnd` to toggle Do Not Disturb
- Glance line above the bar: time, date, battery, now playing — the bar you don't have
- Frosted backdrop: one blurred still of the screen per open, freed on close

**Rest screen**
- Big clock, date, battery (with time left / to full), now playing; no password, any key or click returns
- Comes up after `idleRest` seconds idle (default 300) or on `gimbal rest`; fades to true black after `idleDark` (default 600). Idle inhibitors (video, calls) hold it off
- Drifts a few pixels each minute so an OLED never holds the same image

**Wallpaper**
- Picked from the dashboard strip (`←`/`→` + `enter` while the search box is empty, or click); thumbnails cached under `~/.cache/gimbal/thumbs`
- Quickshell draws the wallpaper directly (kills `wbg` on start)
- `~/Pictures/Wallpapers` scanned on every dashboard open
- Video via QtMultimedia (ffmpeg backend); first-frame posters via ffmpeg
- `gimbal wallpaper next|prev|random|set <name>|list`

**Colours**
- Wallpaper → palette written to `~/.config/gimbal/colors.json`, live-reloaded by the theme
- Derived from an ImageMagick histogram of the current wallpaper: surfaces, accent, and contrast/secondary/tertiary/error state colours rotated around the accent

**Notifications**
- Own `org.freedesktop.Notifications` server (disable mako / dunst / swaync)
- Toasts drop from the top-centre as a shallow deck; hover pauses the timer, critical stays until dismissed

**Capture**
- Type `screenshot` (region / full) or `record` in the launcher — no prefix
- Region select freezes the screen first, then crops your drag from that still
- Screenshots land in `~/Pictures/Screenshots` and on the clipboard; `quiet` skips the file
- Recording via `wl-screenrec` (SIGINT to finalise), toggled from the same `record` entry, saved to `~/Videos/Recordings`
- `gimbal screenshot [region|full] [quiet]` · `gimbal record [full|region|toggle|stop]`

## Install

**Nix (any distro with the Nix package manager):**

```sh
nix shell github:Youwes09/Gimbal
gimbal start
```

Self-contained — pulls in Quickshell and every runtime dependency, no system packages touched. Add the flake as an input and put `gimbal.packages.${system}.default` in your `environment.systemPackages` / home-manager profile for a permanent install.

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
| | `imagemagick` | wallpaper colour palette, wallpaper still-cache |
| | `grim` | screenshots |
| | `brightnessctl` | screen brightness (used if no `oledctl` on `$PATH`) |
| | `libnotify` | screenshot toasts |
| | `xdg-utils` | fallback opener when no file manager is configured |
| **optional** | `qt6-multimedia` | video wallpapers |
| | `ffmpeg` | video wallpaper poster frames |
| | `wl-screenrec` | screen recording |
| | `upower` | low-battery warnings |
| | `file` | richer file-type detection in the inspect card |

Fonts (AdwaitaMono, Lucide) are bundled in `assets/fonts/`. The Nix flake pulls in every row above automatically.

## Usage

```
gimbal start            run the daemon (compositor autostart)
gimbal launch           the launcher
gimbal toggle           summon / dismiss the dashboard
gimbal rest             show the rest screen
gimbal wallpaper …      next | prev | random | rescan | list | <name>
gimbal screenshot …     region | full
gimbal record …         full | region | toggle | stop
```

**In the dashboard:** type to search (the cards step back) · with an empty search, `←`/`→` browse wallpapers · `enter` apply · `esc` close

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
  "idleRest": 300,
  "idleDark": 600,
  "fileRoots": ["~/Projects", "~/Documents", "~/Downloads"]
}
```

`dirOpen` — what plain `enter` does on a directory before it's learned a pick: `smart` | `editor` | `files` | `terminal`.

Env vars override the file: `GIMBAL_EDITOR`, `GIMBAL_FILE_MANAGER`, `GIMBAL_TERMINAL`, `GIMBAL_DIR_OPEN`, `GIMBAL_FILE_ROOTS` (`:`-separated), `GIMBAL_WALLPAPER_DIR`.

State (frecency, current wallpaper, video posters) lives under `~/.local/state/gimbal` and `~/.cache/gimbal`.

## Credits

Gimbal is a rebuild of ideas from **[pibble](https://github.com/kianblakley/pibble)** by [kian blakley](https://github.com/kianblakley) — the summoned-shell approach, the wallpaper carousel's spatial model (parallax windows, scale falloff, continuous rank), the clipboard inspect card, live-wallpaper handling, and wallpaper-derived theming all trace back to it. If you want the full-featured version with in-app settings, custom pages, and flyouts, use pibble.

Built with [Quickshell](https://github.com/quickshell-mirror/quickshell). Icons from [Lucide](https://lucide.dev).
