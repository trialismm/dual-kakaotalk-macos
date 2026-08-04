# Dual KakaoTalk for macOS

An independent feasibility project for creating a separate local `KakaoTalkWork.app` from an officially installed `/Applications/KakaoTalk.app`, with visually distinct muted-green Dock and menu-bar icons.

> [!WARNING]
> The approved feasibility gate is currently **blocked**. No installer or release binary is published because macOS exposes no public writer API for the required compiled `Assets.car` menu-bar renditions. See [Docs/FEASIBILITY.md](Docs/FEASIBILITY.md).

## Current status

- Official KakaoTalk source inspection: implemented
- Local image recoloring (`#628C73` Dock, `#5B8A72` menu bar): implemented and tested
- Dock icon derivation: feasible locally
- Menu-bar `Assets.car` rewrite without private API: blocked
- Installer, privileged transaction, and beta Release: intentionally not shipped
- Apple Silicon: unverified; no support claim

## Build and test

Requires macOS 13 or later and Xcode/Swift only for contributors:

```sh
swift test
swift run dual-kakaotalk-tool inspect
swift run dual-kakaotalk-tool catalog-capability
```

End users were intended not to require Xcode. That distribution work remains behind the feasibility gate.

## Non-affiliation and rights

This project is not affiliated with, endorsed by, or sponsored by Kakao Corp. KakaoTalk and related names, marks, icons, and application assets belong to their respective owner. The MIT license applies only to original source code in this repository. This repository does not contain or redistribute Kakao executables, application bundles, icons, catalog data, screenshots, or derived asset pixels.

Use of modified application bundles may break after updates and may be affected by Kakao's terms or platform security behavior. Back up important conversations using official features.
