# 독립 `Assets.car` writer 연구

[한국어](INDEPENDENT-WRITER.md) | [English](INDEPENDENT-WRITER.en.md)

## 목표

16개 카카오톡 메뉴 아이콘 rendition에 필요한 catalog 구조만 독립적으로 구현한 writer로 비공개 CoreUI 변경 방식을 대체합니다. writer는 카카오 자산을 재배포하지 않아야 하며, 여러 버전에서 불변 조건이 입증될 때까지 fingerprint 제한을 유지해야 합니다.

## 현재 포맷 경계

컴파일된 asset catalog는 rendition key, CSI payload, 이름 table 및 link/atlas record를 담은 BOM(`BOMStore`) 컨테이너입니다. 공개 `assetutil`은 검사할 수 있지만 쓸 수는 없습니다. `showxu/cartools` 같은 오픈소스 reader는 selector 계약을 검증할 만큼 CoreUI 관련 타입을 문서화하지만 독립 writer는 제공하지 않습니다. 현재 비공개 bridge로 대상 논리 record가 1x/2x의 이름 8개이며, 카카오톡 26.6.1에서는 공유 bitmap rendition을 가리키는 link로 저장된 것을 확인했습니다.

## 제안 구현 순서

1. table, block index, rendition key, CSI header, link 대상 및 payload hash를 결정론적으로 출력하는 읽기 전용 BOM parser를 만듭니다.
2. 합성 catalog만으로 생성한 golden 구조 fixture를 추가합니다. 카카오 catalog byte나 파생 pixel은 커밋하지 않습니다.
3. copy-on-write BOM block allocator와 checksum/index rebuilder를 구현합니다.
4. 합성된 비-atlas rendition 하나의 CSI bitmap 교체를 구현한 뒤, 다른 모든 byte를 보존하면서 atlas 부분 영역 교체를 구현합니다.
5. Ventura, Sonoma 및 Sequoia에서 합성 catalog를 `assetutil`과 CoreUI reader로 round-trip 검증합니다.
6. 독립 writer 결과를 현재 bridge와 의미상 비교합니다. 대상 RGBA 변경, 알림 빨간색 보존, 대상 외 payload hash 불변, ad-hoc 재서명 후 유효한 앱 서명 및 정상 앱 실행을 확인합니다.
7. Intel 및 Apple Silicon 동등성 테스트를 통과한 뒤에만 비공개 bridge를 제거합니다.

## 안전 실패 불변 조건

- 정확한 원본 fingerprint와 schema/version 허용 목록
- 예상한 이름/scale/dimension tuple만 존재
- 모든 link가 catalog 내부에서 해석되고 모든 atlas rectangle이 범위 안에 존재
- 원본은 byte 단위로 동일하게 유지
- 대상 외 BOM block과 decode된 rendition pixel이 동일하게 유지
- 다시 연 결과에 예상 record가 모두 있고 새 record는 없음
- 손상, 중복, 겹치는 구조, 알 수 없는 압축 또는 범위 밖 구조는 쓰기 전에 거부
- staged copy에만 기록한 뒤 원자적으로 교체하고 실패 시 rollback

## 테스트 matrix

- Unit: BOM 정수/endian parsing, 경계, index, checksum, key encoding, CSI header parsing 및 압축 거부
- Property: 잘못된 길이, 순환 link, 중복 key, 겹치는 atlas rectangle 및 잘린 block
- Golden: 합성된 단일 rendition 및 공유 atlas catalog의 byte diff 검증
- Integration: Xcode가 있는 환경의 `assetutil` 검사와 macOS 13+ CoreUI readback
- End-to-end: staged KakaoTalkWork 실행, 메뉴 상태 화면 확인, 읽지 않음 배지 보존, Dock 구분 및 업데이트 rollback

## 결정

이는 베타 hotfix가 아니라 별도의 고위험 subsystem입니다. 독립 writer가 위 matrix를 통과할 때까지 비공개 bridge를 실험적 구현으로 유지합니다. 복사한 제3자 구현이나 독점 카카오 asset fixture를 저장소에 포함하지 않습니다.
