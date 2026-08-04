# Independent `Assets.car` Writer Research

## Objective

Replace private CoreUI mutation with an independently implemented writer for only the catalog structures needed by the 16 KakaoTalk menu-icon renditions. The writer must not redistribute Kakao assets and must remain fingerprint-gated until its invariants are proven across versions.

## Current format boundary

A compiled asset catalog is a BOM (`BOMStore`) container with rendition keys, CSI payloads, name tables, and link/atlas records. Public `assetutil` can inspect but not write it. Open-source readers such as `showxu/cartools` document enough CoreUI-facing types to validate selector contracts, but do not supply a standalone writer. The current private bridge demonstrates that the target logical records are eight names at 1x/2x and that KakaoTalk 26.6.1 stores them as links into shared bitmap renditions.

## Proposed implementation sequence

1. Build a read-only BOM parser that emits deterministic tables, block indexes, rendition keys, CSI headers, link targets, and payload hashes.
2. Add golden structural fixtures generated from synthetic catalogs only; never commit Kakao catalog bytes or derived pixels.
3. Implement a copy-on-write BOM block allocator and checksum/index rebuilder.
4. Implement CSI bitmap replacement for one synthetic non-atlas rendition, then atlas sub-rectangle replacement while preserving all other bytes.
5. Round-trip synthetic catalogs through `assetutil` and CoreUI readers on Ventura, Sonoma, and Sequoia.
6. Compare independent-writer output against the current bridge semantically: target RGBA changes, notification-red preservation, unchanged non-target payload hashes, valid app signature after ad-hoc re-signing, and successful app launch.
7. Remove the private bridge only after Intel and Apple Silicon parity testing.

## Fail-closed invariants

- Exact source fingerprint and schema/version allowlist.
- Exactly the expected name/scale/dimension tuples.
- Every link resolves within the catalog and every atlas rectangle is in bounds.
- Source remains byte-identical.
- Non-target BOM blocks and decoded rendition pixels remain identical.
- Reopened output produces all expected records and no new records.
- Corrupt, duplicate, overlapping, unknown-compression, or out-of-range structures are rejected before writing.
- Writes occur only in a staged copy followed by atomic replacement and rollback.

## Test matrix

- Unit: BOM integer/endian parsing, bounds, indexes, checksums, key encoding, CSI header parsing, compression rejection.
- Property: malformed lengths, cyclic links, duplicate keys, overlapping atlas rectangles, truncated blocks.
- Golden: synthetic one-rendition and shared-atlas catalogs with byte-diff assertions.
- Integration: `assetutil` inspection where Xcode exists and CoreUI readback on macOS 13+.
- End-to-end: staged KakaoTalkWork launch, visual menu states, unread badge preservation, Dock distinction, update rollback.

## Decision

This is a separate high-risk subsystem, not a beta hotfix. The private bridge remains the experimental implementation until the independent writer passes the matrix above. No copied third-party implementation or proprietary Kakao asset fixture may enter the repository.
