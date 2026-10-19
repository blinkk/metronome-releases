#!/bin/bash
# Installs or updates Metronome:
#
#   curl -fsSL https://raw.githubusercontent.com/blinkk/metronome-releases/main/install.sh | bash
#
# Downloads the latest release, checks its SHA-256 and signature, puts it in /Applications
# (or ~/Applications) and opens it.
set -euo pipefail

repo="blinkk/metronome-releases"
feed="https://github.com/$repo/releases/latest/download/latest.json"
# The Apple developer team that signs every release. A download signed any other way is refused.
team="6A8MYDJL6R"

fail() { echo "Metronome's installer: $*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "Metronome is a Mac app."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "Metronome needs macOS 14 or later."

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

echo "==> Finding the latest release…"
curl -fsSL "$feed" -o "$scratch/latest.json" || fail "couldn't reach GitHub."
url="$(plutil -extract url raw -o - "$scratch/latest.json")"
digest="$(plutil -extract sha256 raw -o - "$scratch/latest.json")"
version="$(plutil -extract version raw -o - "$scratch/latest.json")"
[[ "$url" == https://* ]] || fail "the release isn't on HTTPS."

echo "==> Downloading Metronome ${version}…"
curl -fsSL "$url" -o "$scratch/Metronome.zip" || fail "the download didn't finish."
echo "$digest  $scratch/Metronome.zip" | shasum -a 256 -c - >/dev/null 2>&1 \
  || fail "the download didn't match the release, so it wasn't installed."
ditto -x -k "$scratch/Metronome.zip" "$scratch"
app="$scratch/Metronome.app"
codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$team\"" "$app" 2>/dev/null \
  || fail "the download isn't signed by Metronome's developer, so it wasn't installed."

if [[ -w /Applications ]]; then
  dest="/Applications/Metronome.app"
else
  dest="$HOME/Applications/Metronome.app"
  mkdir -p "$HOME/Applications"
fi

running="$(pgrep -f "$dest/Contents/MacOS/Metronome" || true)"
if [[ -n "$running" ]]; then
  echo "==> Quitting the copy that's running…"
  kill $running
  for _ in $(seq 1 50); do pgrep -f "$dest/Contents/MacOS/Metronome" >/dev/null || break; sleep 0.2; done
fi

rm -rf "$dest"
ditto "$app" "$dest"
echo "==> Installed Metronome $version in $(dirname "$dest"). Opening it…"
open "$dest"
