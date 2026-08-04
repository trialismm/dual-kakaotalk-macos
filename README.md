# Dual KakaoTalk for macOS

Creates a separate local `/Applications/KakaoTalkWork.app` from the official `/Applications/KakaoTalk.app`, with muted-green Dock (`#628C73`) and menu-bar (`#5B8A72`) icons.

> [!WARNING]
> This trusted-circle beta is intended only for the repository owner and acquaintances who trust the downloaded folder. It uses ad-hoc signing, an administrator prompt, and undocumented private macOS CoreUI APIs; it is not a notarized public installer. Verify the ZIP digest shown on the GitHub Release before running it. Apple may change CoreUI without notice. Intel macOS 13 is verified; Apple Silicon remains experimental and unverified.

## Install or update

1. Install or update the official KakaoTalk in `/Applications/KakaoTalk.app`.
2. Quit both KakaoTalk apps.
3. Download and unzip the latest release.
4. Double-click `Install.command` and approve the macOS administrator prompt.

The same command handles fresh installs and updates. It validates the official app, stages a complete copy, changes the fixed identity to `KakaoTalkWork` / `com.kakao.KakaoTalkWorkMac`, recolors icons locally, signs the copy ad hoc, verifies it, and rolls back an existing work app if installation fails. It then opens both apps. The installer does not copy, inspect, or modify account data, chat data, Keychain entries, or Dock preferences.

If a build is unsupported or installation fails, the installer asks before opening a GitHub issue and reveals the relevant log for review. Logs are never attached automatically: remove personal information before pasting. The five newest private (`0600`) logs are kept in `~/Library/Logs/DualKakaoTalk`.

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
