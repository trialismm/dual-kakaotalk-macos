#!/bin/bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")" && pwd)"
HELPER="$ROOT/bin/dual-kakaotalk-tool"
PROGRESS_APP="$ROOT/bin/DualKakaoProgress.app"
PROGRESS_FILE="${TMPDIR:-/tmp}/DualKakaoTalk-uninstall-progress-$$.state"
PROGRESS_STARTED=0
UNINSTALLER_VERSION="0.1.0-beta.20"
PHASE="bootstrap"
ERROR_LINE="unknown"
LOG_DIR="$HOME/Library/Logs/DualKakaoTalk"
mkdir -p -m 700 "$LOG_DIR"
LOG="$LOG_DIR/uninstall-$(date +%Y%m%d-%H%M%S)-$$.log"
set -o noclobber
: > "$LOG"
chmod 600 "$LOG"
set +o noclobber
exec > >(/usr/bin/sed -E "s|$HOME|~|g; s|/var/folders/[^ /]+|<TEMP>|g" | /usr/bin/tee -a "$LOG") 2>&1

DESTINATION="/Applications/KakaoTalkWork.app"
EXPECTED_BUNDLE_ID="com.kakao.KakaoTalkWorkMac"

LANG_CODE="${LANG:-en}"
if [[ "$LANG_CODE" == ko* ]]; then
  START="듀얼 카카오톡 제거를 시작합니다. 원본 KakaoTalk과 계정·대화 데이터는 삭제하지 않습니다."
  NOT_INSTALLED="듀얼 카카오톡이 설치되어 있지 않습니다. 제거할 항목이 없습니다."
  INVALID="안전을 위해 제거를 중단했습니다. /Applications/KakaoTalkWork.app이 예상한 듀얼 카카오톡과 일치하지 않습니다."
  BUSY="듀얼 카카오톡을 종료하지 못했습니다. 앱을 직접 종료한 뒤 다시 실행하세요."
  AUTH="듀얼 카카오톡을 제거하려면 관리자 승인이 필요합니다."
  DONE="듀얼 카카오톡을 제거했습니다. 계정·대화 데이터와 설치 로그는 보존했습니다."
  FAILURE="듀얼 카카오톡을 제거하지 못했습니다."
  REPORT_FAILURE="제거에 실패했습니다. 개인정보를 확인한 뒤 로그와 함께 GitHub 이슈를 등록하시겠습니까?"
  REPORT_BUTTON="이슈 등록"
  CANCEL_BUTTON="취소"
  PROGRESS_TITLE="Dual KakaoTalk 제거"
  STEP_1="설치된 듀얼 카카오톡을 확인하고 있습니다."
  STEP_2="듀얼 카카오톡을 종료하고 있습니다."
  STEP_3="관리자 승인 후 듀얼 카카오톡을 제거하고 있습니다."
else
  START="Starting Dual KakaoTalk removal. Official KakaoTalk and account/chat data will not be deleted."
  NOT_INSTALLED="Dual KakaoTalk is not installed. There is nothing to remove."
  INVALID="Removal stopped for safety. /Applications/KakaoTalkWork.app does not match the expected Dual KakaoTalk app."
  BUSY="Dual KakaoTalk could not be closed. Quit it manually, then run this command again."
  AUTH="Administrator approval is required to remove Dual KakaoTalk."
  DONE="Dual KakaoTalk was removed. Account/chat data and installer logs were preserved."
  FAILURE="Dual KakaoTalk could not be removed."
  REPORT_FAILURE="Removal failed. Review the log for personal information, then open a GitHub issue?"
  REPORT_BUTTON="Open Issue"
  CANCEL_BUTTON="Cancel"
  PROGRESS_TITLE="Dual KakaoTalk Uninstall"
  STEP_1="Checking the installed Dual KakaoTalk app."
  STEP_2="Closing Dual KakaoTalk."
  STEP_3="Removing Dual KakaoTalk after administrator approval."
fi

diagnostic() {
  printf 'diagnostic.%s=%s\n' "$1" "$2"
}

progress() {
  local current="$1" total="$2" message="$3" temporary="$PROGRESS_FILE.tmp"
  printf '\n[%s/%s] %s\n' "$current" "$total" "$message"
  printf '%s\n%s\nrunning\n' "$((current * 100 / total))" "$message" > "$temporary"
  /bin/mv -f "$temporary" "$PROGRESS_FILE"
  if (( PROGRESS_STARTED == 0 )); then
    /usr/bin/open -n "$PROGRESS_APP" --args progress-window "$PROGRESS_FILE" "$PROGRESS_TITLE"
    PROGRESS_STARTED=1
  fi
}


on_exit() {
  local status=$? state message temporary="$PROGRESS_FILE.tmp" choice
  trap - ERR
  if (( PROGRESS_STARTED == 1 )); then
    if (( status == 0 )); then state="done"; message="$DONE"; else state="failed"; message="$FAILURE"; fi
    printf '100\n%s\n%s\n' "$message" "$state" > "$temporary"
    /bin/mv -f "$temporary" "$PROGRESS_FILE"
  fi
  if (( status != 0 )); then
    diagnostic result failed
    diagnostic failure_phase "$PHASE"
    diagnostic exit_code "$status"
    diagnostic failure_line "$ERROR_LINE"
    diagnostic log_file "$(basename "$LOG")"
    choice="$(/usr/bin/osascript - "$REPORT_FAILURE" "$CANCEL_BUTTON" "$REPORT_BUTTON" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  return button returned of (display dialog (item 1 of argv) buttons {item 2 of argv, item 3 of argv} default button (item 3 of argv) cancel button (item 2 of argv))
end run
APPLESCRIPT
)"
    if [[ "$choice" == "$REPORT_BUTTON" ]]; then
      /usr/bin/open -R "$LOG" || true
      /usr/bin/open 'https://github.com/hubeen/dual-kakaotalk-macos/issues/new?template=uninstall.yml' || true
    fi
  fi
  /usr/bin/find "$LOG_DIR" -type f -name 'uninstall-*.log' -print0 | /usr/bin/xargs -0 ls -1t 2>/dev/null | /usr/bin/awk 'NR>5' | while IFS= read -r old; do rm -f "$old"; done || true
}
trap 'ERROR_LINE=$LINENO' ERR
trap on_exit EXIT

diagnostic schema_version 1
diagnostic uninstaller_version "$UNINSTALLER_VERSION"
diagnostic timestamp_utc "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
diagnostic macos_version "$(/usr/bin/sw_vers -productVersion)"
diagnostic macos_build "$(/usr/bin/sw_vers -buildVersion)"
diagnostic architecture "$(/usr/bin/uname -m)"
diagnostic locale "${LANG:-unknown}"

printf '%s\n' "$START"
PHASE="helper_validation"
[[ -x "$HELPER" ]] || { printf 'Uninstaller helper is missing or not executable.\n' >&2; exit 1; }
[[ -d "$PROGRESS_APP" && ! -L "$PROGRESS_APP" ]] || { printf 'Uninstaller progress application is missing.\n' >&2; exit 1; }
if /usr/bin/xattr -p com.apple.quarantine "$PROGRESS_APP" >/dev/null 2>&1; then
  /usr/bin/xattr -dr com.apple.quarantine "$PROGRESS_APP"
fi
/usr/bin/codesign --verify --deep --strict "$PROGRESS_APP"
progress 1 3 "$STEP_1"
PHASE="destination_validation"

if [[ ! -e "$DESTINATION" && ! -L "$DESTINATION" ]]; then
  printf '%s\n' "$NOT_INSTALLED"
  diagnostic result success
  diagnostic outcome already_absent
  exit 0
fi

# Never follow or remove a symlink at the privileged fixed path.
if [[ -L "$DESTINATION" || ! -d "$DESTINATION" ]]; then
  printf '%s\n' "$INVALID" >&2
  exit 1
fi

PLIST="$DESTINATION/Contents/Info.plist"
if [[ ! -f "$PLIST" || -L "$PLIST" ]]; then
  printf '%s\n' "$INVALID" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null || true)"
if [[ "$bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  printf '%s\n' "$INVALID" >&2
  exit 1
fi
diagnostic target_bundle_id "$bundle_id"

progress 2 3 "$STEP_2"
PHASE="application_shutdown"
/usr/bin/osascript -e 'tell application id "com.kakao.KakaoTalkWorkMac" to quit' 2>/dev/null || true
for _ in {1..20}; do
  if ! /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then break; fi
  /bin/sleep 0.25
done
if /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then
  printf '%s\n' "$BUSY" >&2
  exit 1
fi

progress 3 3 "$STEP_3"
PHASE="administrator_authorization"
printf '%s\n' "$AUTH"
/usr/bin/osascript - "$DESTINATION" "$EXPECTED_BUNDLE_ID" <<'APPLESCRIPT'
on run argv
  set destinationPath to item 1 of argv
  set expectedBundleID to item 2 of argv
  set commandText to "/bin/test ! -L " & quoted form of destinationPath & " && " & ¬
    "/bin/test -d " & quoted form of destinationPath & " && " & ¬
    "/usr/libexec/PlistBuddy -c " & quoted form of "Print :CFBundleIdentifier" & " " & quoted form of (destinationPath & "/Contents/Info.plist") & " | /usr/bin/grep -Fxq " & quoted form of expectedBundleID & " && " & ¬
    "/bin/rm -rf -- " & quoted form of destinationPath
  do shell script commandText with administrator privileges
end run
APPLESCRIPT

PHASE="removal_verification"
if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
  printf '%s\n' "$INVALID" >&2
  exit 1
fi

# Refresh cached app metadata without changing the user's Dock preferences.
/usr/bin/killall sharedfilelistd 2>/dev/null || true
printf '%s\n' "$DONE"
diagnostic result success
diagnostic outcome removed
diagnostic preserved_data true
