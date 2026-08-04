#!/bin/bash
set -euo pipefail

app="/Applications/KakaoTalk.app"
if [[ ! -d "$app" ]]; then
  printf 'Official KakaoTalk is not installed at %s\n' "$app" >&2
  exit 66
fi

codesign --verify --deep --strict --verbose=2 "$app"
swift run dual-kakaotalk-tool inspect

if swift run dual-kakaotalk-tool catalog-capability; then
  printf 'Unexpected: public catalog writer reported available.\n' >&2
  exit 1
else
  status=$?
  if [[ "$status" -ne 69 ]]; then
    exit "$status"
  fi
fi

printf 'Feasibility remains blocked at the public Assets.car writer gate.\n'
