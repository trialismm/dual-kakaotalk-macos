#!/bin/bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "$0")" && pwd)"
HELPER="$ROOT/bin/dual-kakaotalk-tool"
SOURCE="/Applications/KakaoTalk.app"
DESTINATION="/Applications/KakaoTalkWork.app"
HASHES="$ROOT/Compatibility/asset-sha256.txt"
LOG_DIR="$HOME/Library/Logs/DualKakaoTalk"
mkdir -p -m 700 "$LOG_DIR"
LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S)-$$.log"
# Refuse a pre-existing/symlink log, then keep all installer output private to this user.
set -o noclobber
: > "$LOG"
chmod 600 "$LOG"
set +o noclobber
exec > >(tee -a "$LOG") 2>&1

LANG_CODE="${LANG:-en}"
if [[ "$LANG_CODE" == ko* ]]; then
  START="Dual KakaoTalk 설치를 시작합니다."
  MISSING="공식 KakaoTalk을 /Applications/KakaoTalk.app에 설치한 뒤 다시 실행하세요."
  UNSUPPORTED="현재 KakaoTalk 버전 또는 빌드는 아직 지원되지 않습니다. GitHub에서 최신 버전을 확인하세요."
  ARM_WARNING="Apple Silicon에서는 이 실험적 빌드를 확인하지 못했습니다. 계속 진행하지만 주의하세요."
  BUSY="카카오톡 두 앱을 모두 종료한 뒤 설치 프로그램을 다시 실행하세요."
  DONE="완료되었습니다. 개인용과 업무용 카카오톡을 실행합니다."
  FAILURE="설치에 실패했습니다. 개인정보를 확인한 뒤 로그와 함께 GitHub 이슈를 등록하시겠습니까?"
  REPORT_BUTTON="이슈 등록"
  CANCEL_BUTTON="취소"
else
  START="Starting Dual KakaoTalk installation."
  MISSING="Install the official KakaoTalk app at /Applications/KakaoTalk.app, then run this installer again."
  UNSUPPORTED="This KakaoTalk version or build is not supported yet. Check GitHub for the latest release."
  ARM_WARNING="This experimental build is unverified on Apple Silicon. Continuing with caution."
  BUSY="Quit both KakaoTalk applications and run the installer again."
  DONE="Installation complete. Opening personal and work KakaoTalk."
  FAILURE="Installation failed. Review the log for personal information, then open a GitHub issue?"
  REPORT_BUTTON="Open Issue"
  CANCEL_BUTTON="Cancel"
fi

on_error() {
  local status="${1:-1}" line="${2:-unknown}" choice
  trap - ERR
  printf 'Installation failed at line %s (exit %s). Log: %s\n' "$line" "$status" "$LOG"
  choice="$(/usr/bin/osascript -e "button returned of (display dialog \"$FAILURE\" buttons {\"$CANCEL_BUTTON\", \"$REPORT_BUTTON\"} default button \"$REPORT_BUTTON\" cancel button \"$CANCEL_BUTTON\")" 2>/dev/null || true)"
  if [[ "$choice" == "$REPORT_BUTTON" ]]; then
    /usr/bin/open -R "$LOG" || true
    /usr/bin/open 'https://github.com/hubeen/dual-kakaotalk-macos/issues/new?template=compatibility.yml' || true
  fi
  exit "$status"
}
trap 'on_error $? $LINENO' ERR
printf '%s\n' "$START"

major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major < 13 )); then printf 'macOS Ventura 13 or newer is required.\n'; exit 1; fi
[[ -x "$HELPER" ]] || { printf 'Installer helper is missing or not executable.\n'; exit 1; }
# The user has explicitly opened this installer; clear inherited archive quarantine only from the bundled helper.
if /usr/bin/xattr -p com.apple.quarantine "$HELPER" >/dev/null 2>&1; then
  /usr/bin/xattr -d com.apple.quarantine "$HELPER"
fi
/usr/bin/codesign --verify --strict "$HELPER"
[[ -d "$SOURCE" && ! -L "$SOURCE" ]] || { printf '%s\n' "$MISSING"; exit 1; }
assets="$SOURCE/Contents/Resources/Assets.car"
[[ -f "$assets" && ! -L "$assets" ]] || { printf '%s\n' "$MISSING"; exit 1; }
hash="$(shasum -a 256 "$assets" | cut -d' ' -f1)"
if ! /usr/bin/grep -Fxq "$hash" "$HASHES"; then
  printf '%s\nAsset fingerprint: %s\n' "$UNSUPPORTED" "$hash"
  choice="$(/usr/bin/osascript -e 'button returned of (display dialog "This KakaoTalk build is not supported. Open a prefilled GitHub compatibility issue?" buttons {"Cancel", "Open Issue"} default button "Open Issue" cancel button "Cancel")' 2>/dev/null || true)"
  if [[ "$choice" == "Open Issue" ]]; then
    open 'https://github.com/hubeen/dual-kakaotalk-macos/issues/new?template=compatibility.yml' || true
  fi
  exit 1
fi
if [[ "$(uname -m)" == arm64 ]]; then printf '%s\n' "$ARM_WARNING"; fi
/usr/bin/osascript -e 'tell application id "com.kakao.KakaoTalkMac" to quit' 2>/dev/null || true
/usr/bin/osascript -e 'tell application id "com.kakao.KakaoTalkWorkMac" to quit' 2>/dev/null || true
for _ in {1..20}; do
  if ! /usr/bin/pgrep -x KakaoTalk >/dev/null && ! /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then break; fi
  sleep 0.25
done
if /usr/bin/pgrep -x KakaoTalk >/dev/null || /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then
  printf '%s\n' "$BUSY"
  exit 1
fi

ICON="$TMPDIR/DualKakaoTalkWork-$$.icns"
trap 'rm -f "$ICON"' EXIT
"$HELPER" write-dock-icon "$SOURCE" "$ICON"
# Preparation, catalog mutation and ad-hoc signing happen before administrator authorization.
REQUEST="$("$HELPER" prepare-install "$hash" "$ICON" "1.0")"
[[ "$REQUEST" == /private/tmp/DualKakaoTalk-*/* || "$REQUEST" == /tmp/DualKakaoTalk-*/* ]] || { printf 'Invalid staging receipt.\n'; exit 1; }
quoted_helper="$(printf '%q' "$HELPER")"
quoted_request="$(printf '%q' "$REQUEST")"
/usr/bin/osascript -e "do shell script \"$quoted_helper install $quoted_request\" with administrator privileges"
/usr/bin/codesign --verify --deep --strict "$DESTINATION"
printf '%s\n' "$DONE"
open "$SOURCE"
open -n "$DESTINATION"
# Keep only five 0600, privacy-sanitized logs.
/usr/bin/find "$LOG_DIR" -type f -name 'install-*.log' -print0 | /usr/bin/xargs -0 ls -1t 2>/dev/null | /usr/bin/awk 'NR>5' | while IFS= read -r old; do rm -f "$old"; done
