#!/bin/bash
set -euo pipefail

app="/Applications/KakaoTalk.app"
if [[ ! -d "$app" ]]; then
  printf 'Official KakaoTalk is not installed at %s\n' "$app" >&2
  exit 66
fi

codesign --verify --deep --strict --verbose=2 "$app"
swift run dual-kakaotalk-tool inspect

swift run dual-kakaotalk-tool catalog-capability
printf 'The fingerprinted catalog is supported by the private CoreUI writer.\n'
