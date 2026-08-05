#!/bin/bash
set -euo pipefail
umask 077

DESTINATION="/Applications/KakaoTalkWork.app"
EXPECTED_BUNDLE_ID="com.kakao.KakaoTalkWorkMac"

LANG_CODE="${LANG:-en}"
if [[ "$LANG_CODE" == ko* ]]; then
  START="KakaoTalkWork 제거를 시작합니다. 원본 KakaoTalk과 계정·대화 데이터는 삭제하지 않습니다."
  NOT_INSTALLED="KakaoTalkWork가 설치되어 있지 않습니다. 제거할 항목이 없습니다."
  INVALID="안전을 위해 제거를 중단했습니다. /Applications/KakaoTalkWork.app이 예상한 앱과 일치하지 않습니다."
  BUSY="KakaoTalkWork를 종료하지 못했습니다. 앱을 직접 종료한 뒤 다시 실행하세요."
  AUTH="KakaoTalkWork 앱을 제거하려면 관리자 승인이 필요합니다."
  DONE="KakaoTalkWork 앱을 제거했습니다. 계정·대화 데이터와 설치 로그는 보존했습니다."
else
  START="Starting KakaoTalkWork removal. Official KakaoTalk and account/chat data will not be deleted."
  NOT_INSTALLED="KakaoTalkWork is not installed. There is nothing to remove."
  INVALID="Removal stopped for safety. /Applications/KakaoTalkWork.app does not match the expected application."
  BUSY="KakaoTalkWork could not be closed. Quit it manually, then run this command again."
  AUTH="Administrator approval is required to remove the KakaoTalkWork application."
  DONE="KakaoTalkWork was removed. Account/chat data and installer logs were preserved."
fi

printf '%s\n' "$START"

if [[ ! -e "$DESTINATION" && ! -L "$DESTINATION" ]]; then
  printf '%s\n' "$NOT_INSTALLED"
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

/usr/bin/osascript -e 'tell application id "com.kakao.KakaoTalkWorkMac" to quit' 2>/dev/null || true
for _ in {1..20}; do
  if ! /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then break; fi
  /bin/sleep 0.25
done
if /usr/bin/pgrep -x KakaoTalkWork >/dev/null; then
  printf '%s\n' "$BUSY" >&2
  exit 1
fi

printf '%s\n' "$AUTH"
/usr/bin/osascript - "$DESTINATION" "$EXPECTED_BUNDLE_ID" <<'APPLESCRIPT'
on run argv
  set destinationPath to item 1 of argv
  set expectedBundleID to item 2 of argv
  set commandText to "/usr/bin/test ! -L " & quoted form of destinationPath & " && " & ¬
    "/usr/bin/test -d " & quoted form of destinationPath & " && " & ¬
    "/usr/libexec/PlistBuddy -c " & quoted form of "Print :CFBundleIdentifier" & " " & quoted form of (destinationPath & "/Contents/Info.plist") & " | /usr/bin/grep -Fxq " & quoted form of expectedBundleID & " && " & ¬
    "/bin/rm -rf -- " & quoted form of destinationPath
  do shell script commandText with administrator privileges
end run
APPLESCRIPT

if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
  printf '%s\n' "$INVALID" >&2
  exit 1
fi

# Refresh cached app metadata without changing the user's Dock preferences.
/usr/bin/killall sharedfilelistd 2>/dev/null || true
printf '%s\n' "$DONE"
