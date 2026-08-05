# Apple Silicon 지인 검증 절차

[한국어](APPLE-SILICON-VALIDATION.md) | [English](APPLE-SILICON-VALIDATION.en.md)

## 상태

**M3/macOS 26.5.2 검증 완료.** MacBook Air `Mac15,13`의 native arm64 환경에서 beta.16 설치·제거, 개인용 앱과 동시 실행, 초록색 Dock 및 메뉴 막대 아이콘을 확인했습니다. 다른 Apple Silicon 칩과 macOS 조합은 여전히 실험적이며 아래 절차로 추가 검증합니다.

이 절차는 macOS 13 이상을 실행하는 개인 소유 Apple Silicon Mac에서 공개 베타를 테스트합니다. Xcode, 개발자 도구, 다른 사람의 카카오 계정, 계정 데이터·키체인 데이터·Dock 환경설정 변경이 필요하지 않습니다.

## 테스트 전 준비

1. Mac 모델, macOS 버전/빌드와 arm64 여부(`uname -m`)를 기록합니다. macOS 13 이상인지 확인합니다.
2. 공식 카카오톡을 정확히 `/Applications/KakaoTalk.app`에 설치합니다. 이동하거나 이름을 바꾸지 않습니다.
3. 릴리스 ZIP과 `.manifest.json`을 다운로드합니다. `shasum -a 256 <zip>`을 실행하고 manifest의 `sha256`과 비교합니다. 이는 다운로드한 파일을 함께 제공된 manifest와 대조하는 절차이며, manifest는 CI가 생성한 메타데이터일 뿐 변경 불가능하거나 보호된 출처 증명은 아닙니다.
4. 이 검증에 Xcode를 설치하거나 사용하지 않았는지 확인합니다. 릴리스는 테스트 Mac에 기본 포함된 macOS 명령줄 기능만으로 작동해야 합니다.
5. 첫 Gatekeeper 확인 전에는 다운로드 격리 속성을 유지합니다. `xattr -l <zip>` 결과를 기록하고 ZIP과 `Install.command`를 열기 전에 격리를 제거하지 않습니다.

## Gatekeeper 및 격리 속성

1. Finder에서 ZIP을 풀고 `Install.command`를 일반적인 방법으로 엽니다. Gatekeeper/Finder 경고가 나타나면 정확한 문구를 기록합니다.
2. macOS가 첫 실행을 차단하면 Finder 또는 시스템 설정의 정상적인 사용자 승인 열기 절차를 사용합니다. Gatekeeper를 전역 비활성화하거나 `spctl --master-disable`을 실행하거나, 실패를 기록하기 전에 격리를 제거하지 않습니다.
3. 사용자 승인 후 재시도가 진행되는지 기록합니다. 진행되지 않으면 중단하고 아래 설명대로 로그를 수집합니다.
4. 격리 결과를 기록한 뒤에만 필요하면 터미널에서 `xattr -d com.apple.quarantine <압축을-푼-폴더>`로 재시도해 격리 문제와 설치 프로그램 문제를 구분합니다. 두 결과를 모두 보고합니다.

## 설치 시나리오

모든 시나리오는 배포된 `Install.command`로 실행합니다. Xcode 빌드, 소스 체크아웃 또는 수정된 helper를 사용하지 않습니다.

### 1. 새 설치

1. `/Applications/KakaoTalkWork.app`이 없는지 확인합니다. `/Applications/KakaoTalk.app`은 그대로 둡니다.
2. `Install.command`를 실행하고 정상적인 macOS 관리자 권한 요청만 승인합니다.
3. 완료 후 `/Applications/KakaoTalk.app`과 `/Applications/KakaoTalkWork.app`이 모두 존재하는지 확인합니다.
4. 듀얼 카카오톡의 bundle identifier가 `com.kakao.KakaoTalkWorkMac`이며 개인용 앱을 교체하거나 수정하지 않고 실행되는지 확인합니다.

### 2. 업데이트

1. 새 설치 시나리오에서 만든 정상적인 `/Applications/KakaoTalkWork.app`이 있는 상태로 같은 `Install.command`를 다시 실행합니다.
2. 개인용 앱은 `/Applications/KakaoTalk.app`에 유지되고 듀얼 카카오톡만 정상 교체/업데이트되는지 확인합니다.
3. 업데이트 후 두 앱이 독립적으로 실행되는지 확인합니다.

### 3. 변경 없음 / 지원하지 않는 fingerprint

1. 앱을 수동으로 변경하지 않습니다. 가능하면 `Assets.car` fingerprint가 허용 목록에 없는 공식 카카오톡 빌드를 사용합니다. 불가능하면 결과를 꾸미지 말고 이 시나리오를 실행하지 못했다고 기록합니다.
2. `Install.command`를 실행합니다.
3. `/Applications/KakaoTalkWork.app`을 교체하기 전에 안전하게 실패하고, 지원하지 않는 fingerprint를 알리며 호환성 이슈 URL을 열거나 안내하는지 확인합니다.
4. 실패 후에도 기존 듀얼 카카오톡이 실행되는지 확인합니다.

## 화면 확인

두 앱을 실행한 상태에서 다음을 보여주는 스크린샷을 촬영합니다.

- 별도의 Dock 항목과 듀얼 카카오톡의 차분한 초록색 Dock 아이콘
- 개인용 및 듀얼 카카오톡 앱 이름과 KakaoTalkWork로 표시된 듀얼 카카오톡
- 자연스럽게 재현할 수 있는 메뉴 막대의 기본, 선택 및 읽지 않음/배지 상태
- 누락되거나 비어 있거나 잘못된 색상의 메뉴 막대 아이콘이 없음

비공개 도구로 읽지 않음 상태를 강제로 만들거나 컴파일된 catalog를 편집하지 않습니다. 확인하지 못한 메뉴 상태를 명시합니다.

## 증거 및 이슈 등록

성공 또는 실패 시 설치 프로그램이 연결하는 호환성 이슈 양식에 다음을 첨부합니다.

- Mac 모델, macOS 버전/빌드, arm64 확인, 공식 카카오톡 버전/빌드 및 asset fingerprint
- 릴리스 ZIP 파일명, 계산한 SHA-256 및 manifest 내용
- Gatekeeper/격리 관찰 결과와 Xcode 미사용 여부
- 새 설치, 업데이트 및 지원하지 않는 fingerprint/변경 없음 결과
- Dock 및 확인 가능한 메뉴 상태의 개인정보 제거 스크린샷
- `~/Library/Logs/DualKakaoTalk/install-*.log`의 관련 설치 로그

첨부 전 로그와 스크린샷에서 계정명, 대화 내용, 전화번호 및 경로를 확인하고 가립니다. 실패했다면 터미널/Finder의 정확한 오류를 포함하고 조사할 수 있도록 실패한 듀얼 카카오톡을 보존합니다. 설치 프로그램이 제공하는 호환성 URL로 이슈를 등록합니다. 카카오 바이너리, `Assets.car`, 아이콘, 최소한의 UI 증거를 넘어 카카오 자산이 포함된 스크린샷 또는 다른 카카오 애플리케이션 파일은 첨부하지 않습니다.

관리자는 Gatekeeper/격리, Xcode 없는 실행, 새 설치, 업데이트, 변경 없음 실패 동작 및 Dock/메뉴 관찰을 재현 가능한 증거가 모두 다룬 뒤에만 Apple Silicon을 검증 완료로 표시해야 합니다.
