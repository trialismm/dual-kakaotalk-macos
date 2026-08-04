#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HELPER="$ROOT/bin/dual-kakaotalk-tool"
SOURCE="/Applications/KakaoTalk.app"
DESTINATION="/Applications/KakaoTalkWork.app"
HASHES="$ROOT/Compatibility/asset-sha256.txt"
LOG_DIR="$HOME/Library/Logs/DualKakaoTalk"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

LANG_CODE="${LANG:-en}"
if [[ "$LANG_CODE" == ko* ]]; then
  START="Dual KakaoTalk 설치를 시작합니다."
  MISSING="공식 KakaoTalk을 /Applications/KakaoTalk.app에 설치한 뒤 다시 실행하세요."
  UNSUPPORTED="현재 KakaoTalk 버전은 아직 지원되지 않습니다. GitHub에서 최신 버전을 확인하세요."
  DONE="완료되었습니다. 개인용과 업무용 카카오톡을 실행합니다."
else
  START="Starting Dual KakaoTalk installation."
  MISSING="Install the official KakaoTalk app at /Applications/KakaoTalk.app, then run this installer again."
  UNSUPPORTED="This KakaoTalk build is not supported yet. Check GitHub for the latest release."
  DONE="Installation complete. Opening personal and work KakaoTalk."
fi
printf '%s\n' "$START"

major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major < 13 )); then
  printf 'macOS Ventura 13 or newer is required.\n'
  exit 1
fi
if [[ ! -x "$HELPER" ]]; then
  printf 'Installer helper is missing or not executable: %s\n' "$HELPER"
  exit 1
fi
if [[ ! -d "$SOURCE" ]]; then
  printf '%s\n' "$MISSING"
  open 'macappstore://itunes.apple.com/app/id869223134' || true
  exit 1
fi
assets="$SOURCE/Contents/Resources/Assets.car"
if [[ ! -f "$assets" ]]; then
  printf '%s\n' "$MISSING"
  exit 1
fi
hash="$(shasum -a 256 "$assets" | cut -d' ' -f1)"
if ! /usr/bin/grep -Fxq "$hash" "$HASHES"; then
  printf '%s\nAsset fingerprint: %s\n' "$UNSUPPORTED" "$hash"
  open 'https://github.com/hubeen/dual-kakaotalk-macos/issues/new?template=compatibility.yml' || true
  exit 1
fi
ICON="$TMPDIR/DualKakaoTalkWork-$$.icns"
trap 'rm -f "$ICON"' EXIT
"$HELPER" write-dock-icon "$SOURCE" "$ICON"

quoted_helper="$(printf '%q' "$HELPER")"
quoted_hash="$(printf '%q' "$hash")"
quoted_icon="$(printf '%q' "$ICON")"
command="$quoted_helper install $quoted_hash $quoted_icon"
/usr/bin/osascript -e "do shell script \"$command\" with administrator privileges"
/usr/bin/codesign --verify --deep --strict "$DESTINATION"

printf '%s\n' "$DONE"
open "$SOURCE"
open -n "$DESTINATION"

# Keep only the five newest privacy-sanitized installer logs.
/usr/bin/find "$LOG_DIR" -type f -name 'install-*.log' -print0 | /usr/bin/xargs -0 ls -1t 2>/dev/null | /usr/bin/awk 'NR>5' | while IFS= read -r old; do rm -f "$old"; done
