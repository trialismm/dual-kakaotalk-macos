#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"

forbidden=0
while IFS= read -r -d '' path; do
  case "$path" in
    ./.git/*|./.build/*|./.build-release/*|./dist/*|./Artifacts/.gitkeep) continue ;;
  esac
  printf 'forbidden Kakao asset file: %s\n' "$path" >&2
  forbidden=1
done < <(find . -type f \( -name '*.app' -o -name '*.car' -o -name '*.icns' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.zip' \) -print0)

if [[ "$forbidden" -ne 0 ]]; then
  exit 1
fi

printf 'No Kakao binary, image, catalog, or archive assets found in tracked source inputs.\n'
