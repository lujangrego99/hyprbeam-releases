#!/usr/bin/env bash
# hyprbeam installer for Omarchy / Hyprland.
#
#   curl -fsSL https://raw.githubusercontent.com/lujangrego99/hyprbeam-releases/main/install.sh | bash
#   (or, from a clone: ./install.sh)
#
# Installs the hyprbeam package (the service, the CLI and the app in the launcher), starts it
# with every session and opens Omarchy's firewall for it. Run it on every machine.
set -euo pipefail

REPO="lujangrego99/hyprbeam"            # the code (private)
RELEASES="lujangrego99/hyprbeam-releases"  # the builds (public)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have_gh() { command -v gh >/dev/null && gh auth status >/dev/null 2>&1; }

fetch() { # pattern → file in $tmp, from the latest public release
  local url
  url="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$RELEASES/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
    | while read -r u; do [[ "${u##*/}" == $1 ]] && echo "$u" && break; done)"
  if [[ -n "$url" ]] && curl -fsSL -o "$tmp/${url##*/}" "$url"; then
    echo "$tmp/${url##*/}"; return 0
  fi
  if have_gh; then
    gh release download -R "$RELEASES" -p "$1" -D "$tmp" --clobber >/dev/null 2>&1 && ls "$tmp"/$1 2>/dev/null | head -1 && return 0
  fi
  return 1
}

say "Getting hyprbeam"
pkg="$(fetch 'hyprbeam-*-x86_64.pkg.tar.zst' || true)"
if [[ -z "$pkg" ]]; then
  say "No package in the latest release: building one from source"
  src="$tmp/src"
  if [[ -f "$(dirname "${BASH_SOURCE[0]:-.}")/pkg/PKGBUILD" ]]; then
    src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  elif have_gh; then
    gh repo clone "$REPO" "$src" -- --depth 1 -q
  else
    git clone -q --depth 1 "https://github.com/$REPO" "$src"
  fi
  command -v cargo >/dev/null || { command -v mise >/dev/null && { mise use -g rust >/dev/null; eval "$(mise env -s bash)"; }; }
  command -v cargo >/dev/null || { warn "Building needs Rust: mise use -g rust (or pacman -S rust), then run again."; exit 1; }
  (cd "$src/pkg" && makepkg -f --nodeps >/dev/null)
  pkg="$(ls "$src"/pkg/hyprbeam-*-x86_64.pkg.tar.zst | head -1)"
fi

say "Installing the package (asks for your password)"
sudo pacman -U --noconfirm --needed "$pkg" >/dev/null

# An earlier hyprbeam installed itself per user; that unit would hide the packaged one.
if [[ -f "$HOME/.config/systemd/user/hyprbeam.service" ]]; then
  systemctl --user disable --now hyprbeam.service >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/hyprbeam.service" "$HOME/.local/bin/hyprbeam"
fi
systemctl --user daemon-reload
systemctl --user enable --now hyprbeam.service >/dev/null 2>&1
systemctl --user restart hyprbeam.service

# Super+Alt+N brings screen N of the map (the number the app shows); added once, kept if edited.
hypr="$HOME/.config/hypr"
if [[ -f "$hypr/bindings.lua" ]] && ! grep -q 'hyprbeam screen' "$hypr/bindings.lua"; then
  say "Adding Super+Alt+1…9 (bring screen N) to your Hyprland bindings"
  cat >> "$hypr/bindings.lua" <<'LUA'

-- hyprbeam: Super+Alt+N brings screen N of the map (the number the app shows); one of this
-- machine's own numbers comes home.
for i = 1, 9 do
  o.bind("SUPER + ALT + " .. i, "hyprbeam: screen " .. i, "hyprbeam screen " .. i)
end
LUA
elif [[ -f "$hypr/bindings.conf" ]] && ! grep -q 'hyprbeam screen' "$hypr/bindings.conf"; then
  say "Adding Super+Alt+1…9 (bring screen N) to your Hyprland bindings"
  { echo; echo "# hyprbeam: Super+Alt+N brings screen N of the map (the number the app shows)"
    for i in 1 2 3 4 5 6 7 8 9; do echo "bindd = SUPER ALT, $i, hyprbeam: screen $i, exec, hyprbeam screen $i"; done
  } >> "$hypr/bindings.conf"
fi

if systemctl is-active --quiet ufw 2>/dev/null; then
  say "Opening the firewall for other machines (ports 24820 and 24821)"
  sudo ufw allow 24820/tcp comment hyprbeam-link >/dev/null && sudo ufw allow 24821 comment hyprbeam-pairing >/dev/null \
    || warn "Could not change the firewall. Run: sudo ufw allow 24820/tcp && sudo ufw allow 24821"
fi

cat <<MSG

hyprbeam is running. Open it from the launcher (Super + Space → hyprbeam) to pair your
machines and arrange their screens.
MSG
