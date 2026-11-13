#!/usr/bin/env bash
# hyprbeam installer for macOS (unsigned beta .app from the public releases).
#
#   curl -fsSL https://hyprbeam.toyfyw.easypanel.host/install-mac.sh | bash
#
# Downloads the latest hyprbeam-*-macos.zip, clears Gatekeeper quarantine, installs
# into /Applications and opens it. Accessibility + Screen Recording still need a click
# the first time (System Settings → Privacy & Security).
set -euo pipefail

RELEASES="lujangrego99/hyprbeam-releases"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

[[ "$(uname -s)" == Darwin ]] || { warn "This installer is for macOS."; exit 1; }

say "Getting hyprbeam for Mac"
api="https://api.github.com/repos/$RELEASES/releases/latest"
url="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api" \
  | grep -oE '"browser_download_url": *"[^"]+-macos\.zip"' \
  | head -1 | cut -d'"' -f4 || true)"
[[ -n "$url" ]] || { warn "No macOS zip in the latest release."; exit 1; }
curl -fsSL -o "$tmp/hyprbeam-macos.zip" "$url"
unzip -q "$tmp/hyprbeam-macos.zip" -d "$tmp/out"
app="$(find "$tmp/out" -name 'hyprbeam.app' -type d | head -1 || true)"
[[ -n "$app" ]] || { warn "hyprbeam.app missing from the zip."; exit 1; }

say "Clearing Gatekeeper quarantine"
xattr -dr com.apple.quarantine "$app" 2>/dev/null || true

dest="/Applications/hyprbeam.app"
say "Installing to $dest"
rm -rf "$dest"
cp -R "$app" "$dest"

say "Opening hyprbeam"
open "$dest"

cat <<'EOF'

Listo. La primera vez macOS pide Accesibilidad y Grabación de pantalla
(Ajustes del Sistema → Privacidad y seguridad): dale Permitir.

Emparejá con otra máquina con el código de 6 dígitos y empujá por un borde.
EOF
