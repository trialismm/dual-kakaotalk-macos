# Feasibility Gate

Status: **BLOCKED — no release artifact**

## Evidence collected

The current test machine is an Intel Mac running macOS 13.7.8 (22H730). The installed official app is KakaoTalk 26.6.1 (1190), bundle identifier `com.kakao.KakaoTalkMac`, Team ID `L75WVXX68A`. Its strict deep code-signature verification succeeds. The exact compatibility facts are recorded in `compatibility.json`; no Kakao binary or asset bytes are stored in this repository.

The public AppKit/ImageIO prototype can recolor a locally supplied image without uploading or bundling it. Dock recoloring is technically feasible by creating a local `.icns` and applying local Finder icon metadata.

The menu-bar states are compiled renditions in the app's `Contents/Resources/Assets.car`. The required logical assets include normal, dark, logged-out, pressed, and unread-message variants at 1× and 2× scales.

## Stop-ship result

macOS provides no public API for modifying a compiled `Assets.car`. The successful local experiment performed before this repository existed used undocumented CoreUI classes through a third-party wrapper. That path violates the approved constraint prohibiting private CoreUI APIs. `assetutil` can inspect the catalog when Xcode is installed but cannot write it, and requiring Xcode on end-user machines violates the distribution contract.

No independently implemented, reviewed writer for the necessary catalog subset has been proven on this catalog. Rebuilding the entire catalog from extracted Kakao assets would also create unnecessary derivative copies and requires unavailable runtime build tooling.

Therefore the menu-bar requirement cannot currently be implemented under the approved constraints. The project must not ship an installer, Universal helper, or GitHub Release until one of these decisions is approved in a new plan:

1. allow a documented, narrowly scoped private-CoreUI implementation with explicit macOS/Kakao allowlists and residual-risk disclosure;
2. remove the menu-bar recoloring requirement; or
3. provide a reviewed independent `Assets.car` writer and validator.

The current repository intentionally fails closed rather than silently shipping Dock-only behavior.
