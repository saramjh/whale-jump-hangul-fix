# 재현 환경과 확인한 사실

검증일: 2026-10-13. 재현자의 실제 원격 입력과 로컬 관측을 함께 사용했습니다. 원문 키 로그, 원격 접속 정보, 개인 대화는 공개하지 않습니다.

## 환경

| 항목 | 확인한 값 |
|---|---|
| 클라이언트 | iPad Pro 12.9형 3세대 + Magic Keyboard |
| iPad Jump Desktop | 10.15.42 |
| 연결 | Fluid |
| Mac Jump Desktop Connect | 10.15.42.0 |
| macOS | 26.6.2 (25G83) |
| Whale | 5.39.412.57 / Chromium 150 |
| 호스트 입력기 | ABC로 유지한 상태에서도 웹 입력 누락 재현 |

iPadOS 버전은 확보하지 않았습니다. 주소창 한글 입력은 가능했지만 ChatGPT·뤼튼의 웹 입력칸에서 문제가 있었습니다. 사용자는 다른 브라우저와 Parsec에서는 괜찮았다고 보고했습니다. 동일 조건의 Chrome·Safari 이벤트 기록은 수집하지 않았으므로 모든 브라우저를 비교 검증했다고 주장하지 않습니다.

## 관측

1. 기존 확장이 없는 별도 Whale 프로필에서도 재현됐습니다.
2. 당시 로그인하지 않은 ChatGPT 입력칸은 `textarea#mobile-composer-prompt`였습니다. 일반 `contenteditable` 입력칸도 실패했습니다.
3. 한글 `keydown`은 `isTrusted=true`, `code=""`, `keyCode=0`, `isComposing=false`로 도착했습니다.
4. 해당 한글의 `beforeinput`·`input` 문자 삽입은 관측되지 않았습니다. Backspace의 `deleteContentBackward`는 처리됐습니다.
5. 네이티브 이벤트 표본은 202개, 그중 keydown 100개였습니다. Unicode 키 59개(네이티브 keycode 108), Backspace 38개, Space 2개, Return 1개였습니다. 호스트는 표본 동안 ABC였습니다.
6. 한글 키에 브라우저 편집 명령 `insertText`를 수행한 테스트는 56회 성공, 0회 실패였습니다. 이는 해당 테스트의 명령 실행 수이며 일반 사용자 성공률이 아닙니다.
7. 재현자는 ChatGPT와 뤼튼에서 `안녕하세요 테스트 때 때가 됐다 `의 한글·쌍자음·공백이 유지된다고 확인했습니다.

네이티브 keycode **108**과 DOM의 keyCode **0**은 서로 다른 층의 값입니다. 두 값을 같은 값으로 설명하면 안 됩니다.

## 네이티브 구현 분석의 범위

검사한 Mac Jump Connect 수신 경로는 TIS로 현재 입력기를 조회하고 UCKeyTranslate로 문자→키 후보를 찾습니다. 해당 경로에서 매핑하지 못한 문자는 CGEventKeyboardSetUnicodeString을 사용한 Unicode 키 이벤트로 전송됩니다. 따라서 “Jump가 macOS 입력기를 전혀 참조하지 않는다”는 설명은 맞지 않습니다. 키보드 배열의 문자 변환과 IME 조합 상태 처리는 별개의 문제입니다.

Apple은 [Unicode 키 이벤트 API 문서](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:))에서 앱 프레임워크가 이벤트의 Unicode 문자열 대신 가상 키코드로 자체 변환할 수 있다고 설명합니다. 이번 현상과 부합하는 가능성이지만, **Whale 내부의 어느 코드 분기에서 삽입이 누락됐는지는 확정하지 못했습니다.** iPad 송신기의 전체 구현도 분석하지 않았습니다.

## 자동 연결 수명주기 검증

실제 Fluid 연결·종료·재접속·종료를 수행한 결과입니다. 상대 시간은 관측 시작 기준입니다.

| 시간 | 활성 세션 | 고정 | 실제 입력기 |
|---|---:|---|---|
| 0.16초 | 0 | 해제 | 한글 두벌식 |
| 26.38초 | 1 | 켜짐 | ABC |
| 54.05초 | 0 | 해제 | 한글 두벌식 |
| 55.87초 | 1 | 켜짐 | ABC |
| 89.68초 | 0 | 해제 | 한글 두벌식 |

프로그램 종료 버튼도 별도 검증했습니다. 이전 한글 입력기로 복원됐고 실행 중인 보조 앱 프로세스는 0개였습니다. 중복 실행 시 1개 인스턴스만 유지되는 것도 확인했습니다.

## 한계

- 보정은 Whale/Jump의 공식 수정이 아닌 개인 우회 도구입니다.
- `execCommand`는 폐기 예정 API이며 브라우저의 지원 변화나 사이트 편집기 구현에 영향을 받습니다.
- ABC 유지 앱의 세션 신호 `--desktopproxy`는 Connect 10.15.42에서 확인한 내부 구현입니다.
- 실제 실행 검증은 Apple Silicon에서 했습니다. Intel 코드는 빌드·서명 검사까지 확인했습니다.
- 입력 모니터링 진단 도구는 배포하지 않습니다. 배포 앱은 키를 수집하지 않으며 확장도 입력 텍스트를 기록·전송하지 않습니다.
