# Apple Silicon Friend Validation
[한국어](APPLE-SILICON-VALIDATION.md) | [English](APPLE-SILICON-VALIDATION.en.md)

## Status

**VERIFIED ON M3/macOS 26.5.2.** On a MacBook Air `Mac15,13` running native arm64, beta.16 passed installation, removal, simultaneous personal-app operation, and green menu-bar icon checks. Other Apple Silicon chip and macOS combinations remain experimental and use the procedure below for further qualification.

This procedure tests the public beta on a personally owned Apple Silicon Mac running macOS 13 or later. It does not require Xcode, developer tools, a Kakao account belonging to anyone else, or any modification of account data, Keychain data, or Dock preferences.

## Before testing

1. Record the Mac model, macOS version/build, and whether it is arm64 (`uname -m`). Confirm macOS is 13 or later.
2. Install the official KakaoTalk at exactly `/Applications/KakaoTalk.app`; do not move it or rename it.
3. Download the release ZIP and its `.manifest.json`. Compute `shasum -a 256 <zip>` and compare it with the manifest `sha256`. This verifies the downloaded bytes against the accompanying manifest; the manifest is CI-generated metadata, not immutable or protected provenance.
4. Confirm no Xcode is installed or used for this validation. The release must work with only macOS command-line facilities already present on the test Mac.
5. Preserve the download quarantine attribute for the first Gatekeeper check. Record the result of `xattr -l <zip>` and do not remove quarantine before attempting to open the ZIP and `Install.command`.

## Gatekeeper and quarantine

1. Extract the ZIP in Finder, then attempt to open `Install.command` normally. Capture the exact Gatekeeper/Finder warning, if any.
2. If macOS blocks the first launch, use the normal Finder/System Settings user-approved Open flow. Do not disable Gatekeeper globally, run `spctl --master-disable`, or strip quarantine before recording the failure.
3. Record whether the user-approved retry proceeds. If it does not, stop and collect logs as described below.
4. Only after the quarantine result is recorded, optionally retry from Terminal with `xattr -d com.apple.quarantine <extracted-folder>` to distinguish quarantine handling from installer behavior. Report both outcomes.

## Installation scenarios

Run every scenario using the shipped `Install.command`; no Xcode build, source checkout, or modified helper is allowed.

### 1. Fresh install

1. Ensure `/Applications/KakaoTalkWork.app` is absent. Keep `/Applications/KakaoTalk.app` untouched.
2. Run `Install.command` and accept only normal macOS authorization prompts.
3. Confirm both fixed paths exist afterward: `/Applications/KakaoTalk.app` and `/Applications/KakaoTalkWork.app`.
4. Confirm Dual KakaoTalk reports bundle identifier `com.kakao.KakaoTalkWorkMac` and launches without replacing or modifying the personal app.

### 2. Update

1. With a working `/Applications/KakaoTalkWork.app` from the fresh-install scenario, run the same `Install.command` again.
2. Confirm it replaces/updates Dual KakaoTalk successfully while the personal app remains at `/Applications/KakaoTalk.app`.
3. Confirm both apps launch independently after the update.

### 3. No-op / unsupported fingerprint

1. Do not alter either app manually. Use an official KakaoTalk build whose `Assets.car` fingerprint is not allowlisted, if available; otherwise record this scenario as not exercised rather than fabricating a result.
2. Run `Install.command`.
3. Confirm it fails closed before replacing `/Applications/KakaoTalkWork.app`, identifies the unsupported fingerprint, and opens or offers the compatibility issue URL.
4. Confirm the existing Dual KakaoTalk app still launches after the failed attempt.

## Visual checks

With both apps running, capture screenshots showing:

- separate Dock entries, with the dual instance labeled `Dual KakaoTalk`;
- the personal app labeled `KakaoTalk`;
- menu-bar normal, selected, and unread/badged states where those states can be produced naturally;
- no missing, blank, or incorrectly colored menu-bar icons.

Do not force unread state with private tools or edit compiled catalogs. State explicitly which menu states could not be observed.

## Evidence and issue flow

On success or failure, attach the following to the compatibility issue template linked by the installer:

- Mac model, macOS version/build, arm64 confirmation, official KakaoTalk version/build, and asset fingerprint;
- release ZIP filename, computed SHA-256, and manifest contents;
- Gatekeeper/quarantine observations and whether Xcode was absent;
- fresh-install, update, and unsupported/no-op results;
- redacted screenshots of the Dock and observable menu states;
- relevant installer log from `~/Library/Logs/DualKakaoTalk/install-*.log`.

Review logs and screenshots for account names, chat content, phone numbers, and paths before attaching them. For a failure, include the exact terminal/Finder error and preserve the failed Dual KakaoTalk app for investigation. File the issue through the installer-provided compatibility URL; do not attach Kakao binaries, `Assets.car`, icons, screenshots containing Kakao assets beyond the minimum UI evidence, or other Kakao application files.

Maintainers should mark Apple Silicon qualified only after reproducible evidence covers Gatekeeper/quarantine, a no-Xcode run, fresh install, update, no-op failure behavior, and Dock/menu observations.
