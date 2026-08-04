# Dual KakaoTalk for macOS

[한국어](README.md) | [English](README.en.md)

Creates a separate `/Applications/KakaoTalkWork.app` from the official `/Applications/KakaoTalk.app`, allowing personal and work KakaoTalk accounts to run side by side. To distinguish the work app, it locally changes the Dock icon to muted green (`#628C73`) and the menu-bar icons to green (`#5B8A72`).

> [!WARNING]
> This limited beta is intended only for the repository owner and acquaintances who trust the downloaded folder. It uses ad-hoc signing, an administrator prompt, and undocumented private macOS CoreUI APIs. It is not a notarized general-public installer. Verify the ZIP SHA-256 shown on the GitHub Release before running it. Apple or KakaoTalk updates may break it. Intel macOS 13 is verified; Apple Silicon remains **UNVERIFIED**.

## Requirements

- macOS Ventura 13 or newer
- Official KakaoTalk at `/Applications/KakaoTalk.app`
- Currently supported KakaoTalk: 26.6.1 (build 1190)
- End users do not need Xcode.

## Install or update

1. Install or update official KakaoTalk at `/Applications/KakaoTalk.app`.
2. Download and extract the ZIP from the [latest Release](https://github.com/hubeen/dual-kakaotalk-macos/releases/latest).
3. Quit both personal and work KakaoTalk applications.
4. Right-click `Install.command`, then select **Open → Open**.
5. Approve the macOS administrator prompt using your password or Touch ID.
6. After installation, both applications open:
   - Personal: `/Applications/KakaoTalk.app`
   - Work: `/Applications/KakaoTalkWork.app`

After updating official KakaoTalk, quit both applications and run `Install.command` from the latest release again. The same command handles fresh installs and updates. The existing work app is backed up before replacement and restored if installation fails.

## What the installer does

- Validates the official app's fixed path, bundle ID, version, build, Kakao Team ID, signature, and `Assets.car` SHA-256.
- Copies, recolors, ad-hoc signs, and verifies the staged app without administrator privileges.
- Uses administrator privileges only to import a fixed-format, digest-bound request.
- Uses an exclusive lock and write-ahead recovery journal for concurrent or interrupted installations.
- Assigns the fixed work-app identity:
  - Name and executable: `KakaoTalkWork`
  - Bundle ID: `com.kakao.KakaoTalkWorkMac`
- Opens both personal and work applications after installation.

The installer does not access or modify:

- KakaoTalk account or chat data
- Keychain
- Dock pins or Dock preferences
- Background monitoring services

## Error logs and issue reporting

The five newest installer logs are retained under:

```text
~/Library/Logs/DualKakaoTalk/
```

The directory uses mode `0700`, and log files use mode `0600`. Each log records `diagnostic.*` fields for installer version, UTC timestamp, macOS version/build, CPU architecture, helper SHA-256/architectures, KakaoTalk version/build/bundle ID, `Assets.car` SHA-256, result, failure phase, and exit code. User-home and temporary staging paths are automatically replaced. For unsupported builds or installation failures, the installer reveals the log and asks before opening a GitHub issue. Logs are never uploaded automatically. Review the log, then paste it into the issue form's **Structured installer log** field.

## Build and test from source

Contributors need macOS 13+, Xcode/Swift, and Intel and Apple Silicon SDK support.

```sh
swift test
./Scripts/verify-no-kakao-assets.sh
./Scripts/build-release.sh
```

The release contains a Universal x86_64 and arm64 helper. `Assets.car` mutation is restricted to an exact allowlisted fingerprint and 16 menu-icon renditions. See [Docs/FEASIBILITY.md](Docs/FEASIBILITY.md) and [Docs/INDEPENDENT-WRITER.md](Docs/INDEPENDENT-WRITER.md) for private-API risks and the independent-writer migration plan.

## Limitations

- Official app updates are not copied automatically; run `Install.command` again.
- Ad-hoc signing may trigger macOS security warnings.
- Installation fails closed if Apple or KakaoTalk changes an internal format.
- The Universal build includes arm64, but Apple Silicon remains **UNVERIFIED** until physical-device validation.
- This trusted-circle beta is not a notarized installer for general redistribution.

## Non-affiliation and rights

This project is not affiliated with, endorsed by, or sponsored by Kakao Corp. KakaoTalk names, trademarks, icons, and application assets belong to their respective owners. The MIT license applies only to independently written project source code.

The repository and releases do not contain or redistribute Kakao executables, app bundles, icons, `Assets.car`, screenshots, or derived Kakao image pixels. Every icon transformation is performed locally from the official app installed on the user's Mac.
