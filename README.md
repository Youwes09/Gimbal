<h1 align="center">Gimbal</h1>

<p align="center">A summoned <a href="https://github.com/quickshell-mirror/quickshell">Quickshell</a> shell for wlroots Wayland. No bar by default — nothing is on screen until you call it.</p>

---

## What it is

Gimbal has no persistent chrome unless you turn on the bar. You bind three keys:

- **the deck** — a three-column overview: at a glance on the left, a main panel in the middle, controls on the right
- **the launcher** — a Spotlight-style bar: apps, files, clipboard history, a calculator, and run-a-command, all behind single-character prefixes, ranked by frecency, with an inspect card for previews
- **the wallpaper carousel** — a circular reveal onto an infinite parallax carousel of your wallpapers

It also owns your wallpaper (static / GIF / video, cross-faded on switch), repaints itself from the wallpaper's colours, and quietly handles notifications, volume/brightness popups, idle and screenshots.

## Features

**Deck**
- Left: clock and battery (Enter or click it for a calendar with day, month and year progress; ←→ change month), now playing (art, seek, controls), CPU / RAM / GPU / temperature as matching ring tiles
- Centre, with a section rail:
  - **Home** — your most-used apps, the folders you open most from the launcher with their git branch and uncommitted changes, the latest notifications
  - **Spaces** — every workspace with the apps open on it and a preview of its layout; the last session and saved setups as strips you can restore. Restoring moves open windows back onto their workspaces and relaunches the rest (terminals in their old directory). The layout is saved as it changes, through `mmsg` (mango)
  - **Network** — the link you're on (signal, band, channel and rate, address, gateway, internet, Tailscale), live throughput with average and peak, data used per day and per network (counted in the background, kept across reboots), Wi-Fi networks (passwords asked inline) and Bluetooth devices with battery and how long they've been connected
  - **Notifications** — full history; open, dismiss, clear, Focus (Do Not Disturb)
  - **Captures** — newest screenshots and recordings; open, copy, trash; take new ones
  - **Session** — your machine at a glance (host, OS, kernel, uptime, NixOS generation and when it was built), then rest, suspend, log out, reboot, shut down (the last three ask twice)
- Right: quick toggles (Focus, keyboard backlight, power profile via `asusctl`, warm light via WayOLED's `oledctl`; each shows "Unavailable" without its tool) above Sound (output, microphone, a slider per app playing, with its icon) and Display (brightness)
- Fully keyboard driven with arrows and `enter`: arrows move spatially across the whole deck and hand off between panels at the edges; in the mixer `←`/`→` set the level. `tab` / `1`–`6` switch pages, `space` play/pause, `esc` close. Key chips under the deck show what works where you are
- Frosted backdrop from one blurred still of the screen; everything is built on open and torn down on close. Stats and git state are only sampled while it is open

**Launcher**
- `apps` (default) · `>` run a command · `=` calculator · `/` or `~` files & folders · `;` clipboard history · `:` emoji & symbols (enter types it where you were; see `emojiAction`)
- Frecency ranking — what you actually reach for floats up
- Files: `enter` = smart open (project dir → editor, else file manager), `ctrl+enter` = editor, `alt+enter` = file manager, `shift+enter` = terminal there. It **learns** your pick per directory.
- Inspect card (`tab`) — text/image/video previews, colour swatches, binary metadata, app details; scrollable, mouse-locked
- Clipboard rows show image thumbnails
- Type `dnd` to toggle Do Not Disturb

**Rest screen**
- Big clock, date, battery (with time left / to full), now playing; no password, any key or click returns
- Comes up after `idleRest` seconds idle (default 300) or on `gimbal rest`; fades to true black after `idleDark` (default 600). Idle inhibitors (video, calls) hold it off
- Drifts a few pixels each minute so an OLED never holds the same image

**Wallpaper**
- Carousel — circular reveal, infinite parallax, live video previews, cross-fade apply; `w` in the deck or `gimbal walls`
- Quickshell draws the wallpaper directly (kills `wbg` on start)
- `~/Pictures/Wallpapers` scanned on every carousel open
- Video via QtMultimedia (ffmpeg backend); first-frame posters via ffmpeg
- `gimbal wallpaper next|prev|random|set <name>|list`

**Colours**
- Wallpaper → palette written to `~/.config/gimbal/colors.json`, live-reloaded by the theme
- Derived from an ImageMagick histogram of the current wallpaper: surfaces, accent, and contrast/secondary/tertiary/error state colours rotated around the accent

**Polkit**
- Gimbal is the polkit agent: when an app asks for admin rights, a card asks for your password (stop any other agent)

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
| | `imagemagick` | wallpaper colour palette, wallpaper still-cache, app icon normalisation |
| | `grim` | screenshots |
| | `brightnessctl` | screen brightness (used if no `oledctl` on `$PATH`), keyboard backlight fallback |
| | `libnotify` | screenshot toasts |
| | `xdg-utils` | fallback opener when no file manager is configured |
| **optional** | `qt6-multimedia` | video wallpapers |
| | `ffmpeg` | video wallpaper poster frames |
| | `wl-screenrec` | screen recording |
| | `glib` (`gdbus`) | keyboard backlight through UPower, kept in step with the Fn keys |
| | `upower` | low-battery warnings |
| | `file` | richer file-type detection in the inspect card |

Fonts (AdwaitaMono, Lucide) are bundled in `assets/fonts/`. The Nix flake pulls in every row above automatically.

## Usage

```
gimbal start            run the daemon (compositor autostart)
gimbal launch           the launcher
gimbal clipboard        the launcher in one mode (also emoji, files, calc, run)
gimbal toggle           summon / dismiss the deck
gimbal deck <page>      the deck on a page: home | spaces | network | notifications | captures | session
gimbal walls            summon / dismiss the wallpaper carousel
gimbal rest             show the rest screen
gimbal wallpaper …      next | prev | random | rescan | list | <name>
gimbal screenshot …     region | full
gimbal record …         full | region | toggle | stop
gimbal spaces …         restore | load <name> | save <name> | remove <name> | rename <from> <to> | list
gimbal kbd …            up | down | cycle | set <n>   (keyboard backlight)
gimbal bar …            show | hide | toggle   (when `bar` is on in config)
```

`gimbal clipboard` and `gimbal deck <page>` toggle: bound to a key, it closes what it opened and switches mode or page from anywhere else.

**In the carousel:** `←`/`→` cycle · `enter` apply · `esc` close

**In the launcher:** type a prefix, `↑`/`↓` to move, `tab` to inspect, `enter` to run.

### Compositor integration

<details><summary>mango</summary>

```
exec-once=gimbal start
bind=SUPER+SHIFT,a,spawn_shell,gimbal launch
bind=SUPER,Tab,spawn_shell,gimbal toggle
bind=SUPER,v,spawn_shell,gimbal clipboard
```
</details>

<details><summary>Hyprland</summary>

```
exec-once = gimbal start
bind = SUPER SHIFT, A, exec, gimbal launch
bind = SUPER, Tab, exec, gimbal toggle
bind = SUPER, V, exec, gimbal clipboard
```
</details>

<details><summary>niri</summary>

```
spawn-at-startup "gimbal" "start"
binds {
    "Mod+Shift+A" { spawn "gimbal" "launch"; }
    "Mod+Tab"     { spawn "gimbal" "toggle"; }
    "Mod+V"       { spawn "gimbal" "clipboard"; }
}
```
</details>

<details><summary>sway / river</summary>

```
exec gimbal start
bindsym $mod+Shift+a exec gimbal launch
bindsym $mod+Tab exec gimbal toggle
bindsym $mod+v exec gimbal clipboard
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
  "emojiAction": "type",
  "scale": 1.0,
  "scales": { "bar": 1.0, "deck": 1.0, "launcher": 1.0 },
  "kbdBacklight": "auto",
  "bar": false,
  "fileRoots": ["~/Projects", "~/Documents", "~/Downloads"]
}
```

`dirOpen` — what plain `enter` does on a directory before it's learned a pick: `smart` | `editor` | `files` | `terminal`.

`emojiAction` — what `enter` does on a `:` emoji or symbol: `type` it into the window you were in (needs `wtype`; falls back to copying) | `copy` it to the clipboard.

`scale` — size of everything Gimbal draws: a number, or `"auto"` to follow the screen's pixel density (a 243 PPI panel is 1.0). Use this instead of `QT_SCALE_FACTOR`, which blurs images and leaks into apps launched from Gimbal.

`scales` — per-surface multipliers on top of `scale`: `bar`, `deck`, `launcher`, `wallpapers` (carousel), `rest`, `notifications`, `osd`, `recording`, `launch` (app-launch indicator), `screenshot` (region picker), `polkit`. Anything left out is 1.

`kbdBacklight` — keyboard backlight backend: `auto` | `asusctl` | `upower` | `brightnessctl` | `none`. `auto` takes `asusctl` only with an ASUS Aura keyboard (which is also lit in the wallpaper's accent), then UPower, then `brightnessctl`.

`bar` — an optional bar: `false` (default) | `true` or `"top"` | `"bottom"`. Three floating islands in the deck's style: workspaces and the focused window; the clock (click for the deck); the tray, now playing, recording, Focus, network, volume (scroll to change, click to mute) and battery. Toasts and the recording pill move below it.

Env vars override the file: `GIMBAL_EDITOR`, `GIMBAL_FILE_MANAGER`, `GIMBAL_TERMINAL`, `GIMBAL_DIR_OPEN`, `GIMBAL_SCALE`, `GIMBAL_KBD_BACKLIGHT`, `GIMBAL_BAR`, `GIMBAL_FILE_ROOTS` (`:`-separated), `GIMBAL_WALLPAPER_DIR`.

State (frecency, current wallpaper, video posters) lives under `~/.local/state/gimbal` and `~/.cache/gimbal`.

## Credits

Gimbal is a rebuild of ideas from **[pibble](https://github.com/kianblakley/pibble)** by [kian blakley](https://github.com/kianblakley) — the summoned-shell approach, the wallpaper carousel's spatial model (parallax windows, scale falloff, continuous rank), the clipboard inspect card, live-wallpaper handling, and wallpaper-derived theming all trace back to it. If you want the full-featured version with in-app settings, custom pages, and flyouts, use pibble.

Built with [Quickshell](https://github.com/quickshell-mirror/quickshell). Icons from [Lucide](https://lucide.dev).
