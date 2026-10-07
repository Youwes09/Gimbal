#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gimbal"
wall_dir="${GIMBAL_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

c_head=$'\033[1;36m'; c_ok=$'\033[1;32m'; c_warn=$'\033[1;33m'; c_off=$'\033[0m'
say()  { printf '%s::%s %s\n' "$c_head" "$c_off" "$*"; }
good() { printf '  %sok%s  %s\n' "$c_ok" "$c_off" "$*"; }
miss() { printf '  %s--%s  %s\n' "$c_warn" "$c_off" "$*"; }

# ── dependencies ────────────────────────────────────────────────────────────
# label | probe | arch-pkg | pacman|aur | what it enables
required=(
  "quickshell|command -v qs|quickshell|aur|the shell runtime"
  "wl-clipboard|command -v wl-copy|wl-clipboard|pacman|clipboard history"
  "cliphist|command -v cliphist|cliphist|pacman|clipboard history store"
  "imagemagick|command -v magick|imagemagick|pacman|wallpaper colour palette"
  "grim|command -v grim|grim|pacman|screenshots"
  "brightnessctl|command -v brightnessctl|brightnessctl|pacman|screen brightness"
  "libnotify|command -v notify-send|libnotify|pacman|screenshot toasts"
  "xdg-utils|command -v xdg-open|xdg-utils|pacman|fallback file/dir opener"
)
optional=(
  "qt6-multimedia|qml_has QtMultimedia|qt6-multimedia|pacman|video wallpapers"
  "ffmpeg|command -v ffmpeg|ffmpeg|pacman|video wallpaper poster frames"
  "wl-screenrec|command -v wl-screenrec|wl-screenrec|aur|screen recording"
  "upower|command -v upower|upower|pacman|low-battery warnings"
  "file|command -v file|file|pacman|richer metadata in the inspect card"
)

qml_has() {
  local p
  for p in /usr/lib/qt6/qml /usr/lib/qt/qml "${QML2_IMPORT_PATH//:/ }"; do
    [ -d "$p/${1//.//}" ] && return 0
  done
  return 1
}

missing_pacman=(); missing_aur=()
check_group() {
  local -n arr=$1
  local line label probe pkg src why
  for line in "${arr[@]}"; do
    IFS='|' read -r label probe pkg src why <<<"$line"
    if eval "$probe" >/dev/null 2>&1; then
      good "$label — $why"
    else
      miss "$label — $why"
      [ "$src" = aur ] && missing_aur+=("$pkg") || missing_pacman+=("$pkg")
    fi
  done
}

say "checking dependencies"
check_group required
check_group optional

# ── install what's missing (Arch only) ─────────────────────────────────────
if [ "${#missing_pacman[@]}" -gt 0 ] || [ "${#missing_aur[@]}" -gt 0 ]; then
  if command -v pacman >/dev/null 2>&1; then
    aur=""
    for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { aur="$h"; break; }; done

    if [ "${#missing_pacman[@]}" -gt 0 ]; then
      say "installing: ${missing_pacman[*]}"
      sudo pacman -S --needed "${missing_pacman[@]}"
    fi
    if [ "${#missing_aur[@]}" -gt 0 ]; then
      if [ -n "$aur" ]; then
        say "installing from the AUR ($aur): ${missing_aur[*]}"
        "$aur" -S --needed "${missing_aur[@]}"
      else
        say "these need the AUR — install them with an AUR helper, then re-run:"
        printf '     %s\n' "${missing_aur[@]}"
      fi
    fi
  else
    say "not an Arch system — install the equivalents of:"
    printf '     %s\n' "${missing_pacman[@]}" "${missing_aur[@]}"
  fi
else
  say "all dependencies present"
fi

# ── link the command ──────────────────────────────────────────────────────
chmod +x "$repo/gimbal"
mkdir -p "$bin_dir"
ln -sfn "$repo/gimbal" "$bin_dir/gimbal"
say "linked $bin_dir/gimbal -> $repo/gimbal"
case ":$PATH:" in
  *":$bin_dir:"*) : ;;
  *) say "add $bin_dir to your PATH" ;;
esac

# ── seed config + wallpapers dir ──────────────────────────────────────────
mkdir -p "$cfg_dir" "$wall_dir"
if [ ! -e "$cfg_dir/config.json" ]; then
  cat > "$cfg_dir/config.json" <<EOF
{
  "editor": "code",
  "fileManager": "nautilus",
  "terminal": "foot",
  "dirOpen": "smart",
  "fileRoots": ["~/Projects", "~/Documents", "~/Downloads", "~/Pictures", "~/.config"]
}
EOF
  say "wrote $cfg_dir/config.json — set editor / fileManager / terminal to taste"
else
  say "kept existing $cfg_dir/config.json"
fi
[ -n "$(find "$wall_dir" -maxdepth 1 -type f 2>/dev/null | head -1)" ] \
  || say "drop some images in $wall_dir"

# ── done ─────────────────────────────────────────────────────────────────
cat <<EOF

${c_ok}Gimbal is installed.${c_off}

  gimbal start            run the daemon (put this in your compositor autostart)
  gimbal launch           the Spotlight launcher
  gimbal toggle           summon / dismiss the overlay
  gimbal wallpaper next   cycle wallpaper

Bind the two toggles in your compositor, e.g.

  Hyprland   bind = SUPER SHIFT, A, exec, gimbal launch
             bind = SUPER, Tab,   exec, gimbal toggle
             exec-once = gimbal start

  niri       binds { "Mod+Shift+A" { spawn "gimbal" "launch"; }
                      "Mod+Tab"   { spawn "gimbal" "toggle"; } }
             spawn-at-startup "gimbal" "start"

  sway       bindsym $mod+Shift+a exec gimbal launch
             bindsym \$mod+Tab exec gimbal toggle
             exec gimbal start

Inside the overlay: w = wallpaper picker, b = Wi-Fi/Bluetooth, arrows = arm power / cycle, esc = close.
EOF
