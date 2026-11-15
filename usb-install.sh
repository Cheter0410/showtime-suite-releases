#!/bin/sh
# Installs Showtime Suite and the show apps from a USB stick, without internet.
#
# Put this file on the stick next to the downloaded Linux files
# (*-linux-x86_64.tar.gz and/or showmaster-*.pkg.tar.zst), then run:
#
#   sh /run/media/$USER/<stick>/usb-install.sh
#
# Everything lands where Showtime Suite itself installs apps
# (~/.local/share/showtime-suite/apps), so Showtime Suite sees them as installed and
# can update or remove them later.
set -eu

if [ "$(id -u)" = 0 ]; then
  echo "Bitte ohne sudo starten (sonst landet alles beim Benutzer root)."
  echo "Das Skript fragt selbst nach dem Passwort, wenn es eins braucht."
  exit 1
fi

HERE=$(cd "$(dirname "$0")" && pwd)
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/showtime-suite/apps"
BIN="$HOME/.local/bin"
MENU="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
# Until Stagehand 0.1 (before the rename to Showtime Suite) the folder was
# called stagehand: move it over once, with the menu entries and commands.
OLD_APPS="${XDG_DATA_HOME:-$HOME/.local/share}/stagehand/apps"
if [ -d "$OLD_APPS" ] && [ ! -e "$APPS" ]; then
  mkdir -p "$(dirname "$APPS")"
  mv "$OLD_APPS" "$APPS"
  rmdir "$(dirname "$OLD_APPS")" 2>/dev/null || true
  for f in "$MENU"/*.desktop; do
    grep -qs '^X-Stagehand=1' "$f" || continue
    sed -e "s|$OLD_APPS/|$APPS/|g" -e 's|^X-Stagehand=1|X-Showtime-Suite=1|' "$f" >"$f.new" && mv "$f.new" "$f"
  done
  for f in "$BIN"/*; do
    [ -L "$f" ] || continue
    t=$(readlink "$f")
    case "$t" in "$OLD_APPS"/*) ln -sfn "$APPS/${t#"$OLD_APPS"/}" "$f" ;; esac
  done
fi
mkdir -p "$APPS" "$BIN" "$MENU"
found=0
failed=""

# Show Master as an Arch package, if there is one (newest when there are several).
pkg=$(ls "$HERE"/showmaster-*.pkg.tar.zst 2>/dev/null | sort -V | tail -n 1 || true)
if [ -n "$pkg" ]; then
  if command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    echo "==> Show Master (Arch-Paket) – sudo fragt nach deinem Passwort"
    if sudo pacman -U --noconfirm "$pkg"; then
      found=1
      # One copy only: an older one in the Showtime Suite folder would be the one the menu starts.
      if [ -d "$APPS/showmaster" ]; then
        rm -rf "$APPS/showmaster"
        if grep -qsE '^X-(Showtime-Suite|Stagehand)=1' "$MENU/showmaster.desktop"; then rm -f "$MENU/showmaster.desktop"; fi
        case "$(readlink "$BIN/showmaster" 2>/dev/null || true)" in "$APPS"/*) rm -f "$BIN/showmaster" ;; esac
      fi
    else
      echo "    Das Arch-Paket ließ sich nicht installieren (ohne Internet fehlt oft ein"
      echo "    abhängiges Paket). Ich nehme das Archiv, wenn eins auf dem Stick liegt."
      failed="Show Master (Arch-Paket)"
    fi
  else
    echo "==> Show Master (Arch-Paket) übersprungen: das ist kein Arch Linux"
  fi
fi

for tar in "$HERE"/*-linux-x86_64.tar.gz; do
  [ -f "$tar" ] || continue
  base=$(basename "$tar" -linux-x86_64.tar.gz)   # e.g. showtime-suite-0.2.0
  id=${base%-*}                                    # showtime-suite
  version=${base##*-}                              # 0.2.0
  # The Arch package already installed Show Master.
  if [ "$id" = showmaster ] && command -v pacman >/dev/null 2>&1 && pacman -Q showmaster >/dev/null 2>&1; then
    echo "==> showmaster: per pacman installiert, Archiv übersprungen"
    continue
  fi
  echo "==> $id $version"
  tmp="$APPS/.$id.new"
  rm -rf "$tmp" && mkdir -p "$tmp"
  if ! tar -xzf "$tar" -C "$tmp"; then
    echo "    Das Archiv ist beschädigt (nochmal auf den Stick kopieren), übersprungen"
    rm -rf "$tmp"; failed="$failed $id"; continue
  fi
  inner=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [ -z "$inner" ] || [ ! -f "$inner/$id" ]; then
    echo "    $id fehlt im Archiv, übersprungen"
    rm -rf "$tmp"; failed="$failed $id"; continue
  fi
  chmod +x "$inner/$id"
  echo "$version" > "$inner/VERSION"
  rm -rf "${APPS:?}/$id"
  mv "$inner" "$APPS/$id"
  rm -rf "$tmp"
  found=1
  [ "$id" = showmaster ] && failed=""
  # The command; a real file someone put there is left alone.
  if [ -L "$BIN/$id" ] || [ ! -e "$BIN/$id" ]; then ln -sfn "$APPS/$id/$id" "$BIN/$id"; fi
  # Menu entry: the packaged one (file types, categories) with full paths.
  icon=""
  for i in "$APPS/$id/icon.png" "$APPS/$id/$id.png"; do
    if [ -f "$i" ]; then icon="Icon=$i"; break; fi
  done
  src="$APPS/$id/$id.desktop"
  if [ -f "$src" ]; then
    args=$(sed -n 's/^Exec=[^ ]*//p' "$src" | head -n 1)
    {
      grep -vE '^(Exec|Icon|X-Showtime-Suite|X-Stagehand)=' "$src"
      printf 'Exec="%s"%s\n' "$APPS/$id/$id" "$args"
      [ -n "$icon" ] && echo "$icon"
      echo "X-Showtime-Suite=1"
    } > "$MENU/$id.desktop"
  else
    {
      printf '[Desktop Entry]\nType=Application\nName=%s\nExec="%s" %%F\n' "$id" "$APPS/$id/$id"
      [ -n "$icon" ] && echo "$icon"
      printf 'Terminal=false\nCategories=AudioVideo;\nX-Showtime-Suite=1\n'
    } > "$MENU/$id.desktop"
  fi
done
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$MENU" 2>/dev/null || true

if [ "$found" != 1 ]; then
  echo "Nichts installiert. Neben diesem Skript müssen die Linux-Dateien liegen"
  echo "(*-linux-x86_64.tar.gz oder showmaster-*.pkg.tar.zst) – hier: $HERE"
  exit 1
fi

# ~/.local/bin on the PATH, so "showtime-suite" works in the terminal.
case ":$PATH:" in
  *":$BIN:"*) ;;
  *)
    if command -v fish >/dev/null 2>&1; then fish -c "fish_add_path '$BIN'" >/dev/null 2>&1 || true; fi
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      [ -f "$rc" ] || continue
      grep -qs '\.local/bin' "$rc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    done
    ;;
esac

echo
if [ -n "$failed" ]; then
  echo "Nicht installiert: $failed"
  echo "Der Rest ist fertig. Showtime Suite findest du im Startmenü."
  exit 1
fi
echo "Fertig. Showtime Suite findest du jetzt im Startmenü."
