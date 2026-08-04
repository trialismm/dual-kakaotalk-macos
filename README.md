# Dual KakaoTalk for macOS

Creates a separate local `/Applications/KakaoTalkWork.app` from the official `/Applications/KakaoTalk.app`, with muted-green Dock (`#628C73`) and menu-bar (`#5B8A72`) icons.

> [!WARNING]
> This beta uses undocumented private macOS CoreUI APIs to rewrite a narrowly allowlisted set of menu-bar renditions. Apple may change these APIs without notice. The Intel build is verified on macOS 13; Apple Silicon remains experimental and unverified until reported otherwise.

## Install or update

1. Install or update the official KakaoTalk in `/Applications/KakaoTalk.app`.
2. Quit both KakaoTalk apps.
3. Download and unzip the latest release.
4. Double-click `Install.command` and approve the macOS administrator prompt.

The same command handles fresh installs and updates. It validates the official app, stages a complete copy, changes the fixed identity to `KakaoTalkWork` / `com.kakao.KakaoTalkWorkMac`, recolors icons locally, signs the copy ad hoc, verifies it, and rolls back an existing work app if installation fails. It then opens both apps. The installer does not copy, inspect, or modify account data, chat data, Keychain entries, or Dock preferences.

If a new official KakaoTalk build is not allowlisted, the installer stops without changing the work app and opens a prefilled compatibility issue. Review logs before attaching them; the five newest installer logs are kept in `~/Library/Logs/DualKakaoTalk`.

## Build and test

Contributors need macOS 13+, Xcode/Swift, and both Intel and Apple Silicon SDK support:

```sh
swift test
./Scripts/verify-no-kakao-assets.sh
./Scripts/build-release.sh
```

The release archive contains a Universal helper, so end users do not need Xcode. `Assets.car` writer behavior is intentionally fingerprint-gated. See [Docs/FEASIBILITY.md](Docs/FEASIBILITY.md) for the private-API risk and the planned independent writer.

## Limitations

- Updating the official app does not update `KakaoTalkWork`; run `Install.command` again.
- Ad-hoc signing can trigger macOS security prompts and can break when Kakao or Apple changes app internals.
- No background monitor or Dock pinning is installed.
- Apple Silicon beta status is explicitly unverified.

## Non-affiliation and rights

This project is not affiliated with, endorsed by, or sponsored by Kakao Corp. KakaoTalk and related names, marks, icons, and application assets belong to their respective owner. The MIT license applies only to original source code. This repository and its releases do not contain or redistribute Kakao executables, app bundles, icons, catalog data, screenshots, or derived asset pixels; all derived icons are produced locally from the user's installed official app.
