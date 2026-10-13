# 웨일 + Jump Desktop 한글 입력 보정

아이패드의 Jump Desktop Fluid로 맥에 접속했을 때, **웨일의 ChatGPT·뤼튼 입력창에서 한글이 입력되지 않거나 조합 중 사라지는 문제**를 재현하고 만든 개인 보정 도구입니다. NAVER Whale이나 Jump Desktop의 공식 패치가 아닙니다.

한글 키의 `keydown`은 웹페이지에 도착하지만 문자 삽입 이벤트는 발생하지 않고, Backspace 삭제는 정상 처리되는 패턴을 관측했습니다. 이 패턴을 보완한 뒤 ChatGPT와 뤼튼에서 한글·쌍자음·공백 입력이 정상이라고 사용자가 확인했습니다. 모든 브라우저·운영체제·AI 사이트를 검증한 것은 아닙니다.

## 다운로드

[GitHub Releases](https://github.com/saramjh/whale-jump-hangul-fix/releases)에서 받습니다.

| 파일 | 용도 |
|---|---|
| `JumpHangulWhale-0.1.1.zip` | 웨일 웹 입력칸에 누락된 한글 문자 삽입을 보완하는 확장 |
| `JumpInputGuard-2.0.3-macos-universal.zip` | Jump 연결 중에만 맥을 ABC로 유지하고 종료 시 이전 입력기로 복원하는 메뉴 막대 앱 |
| `SHA256SUMS.txt` | 다운로드 파일의 SHA-256 확인 |

맥 앱은 macOS 13 이상을 대상으로 Apple Silicon·Intel 두 아키텍처를 빌드합니다. 실제 실행 확인은 Apple Silicon, macOS 26.6.2에서 했습니다. 개인 배포 앱이라 Apple Developer ID 서명·공증은 되어 있지 않습니다. 실행이 차단되면 먼저 소스와 출처를 확인하고 [Apple의 앱 열기 안내](https://support.apple.com/ko-kr/102445)를 참고하세요. 아래 소스로 직접 빌드할 수도 있습니다.

## 초보자: 웨일 확장 설치

1. `JumpHangulWhale-0.1.1.zip`을 압축 해제합니다. 폴더는 설치 뒤에도 유지하세요.
2. 웨일 주소창에 `whale://extensions`를 입력합니다.
3. **개발자 모드 → 압축해제 된 확장앱 설치**를 누릅니다.
4. `manifest.json`이 들어 있는 `JumpHangulWhale` 폴더를 선택합니다.
5. ChatGPT 페이지를 새로고침합니다. 확장 버튼을 도구 막대에 고정하면 편리합니다.

**ChatGPT에는 자동으로 적용됩니다. 다른 AI 사이트는 그 페이지에서 확장 버튼을 클릭해서 켭니다.** 다시 누르면 꺼집니다. 다른 사이트를 새로고침하거나 새 탭에서 열었으면 다시 클릭하세요.

브라우저 확장은 실제 조합 중인 키, 영어, 단축키, 비밀번호 입력칸을 보정하지 않습니다. ChatGPT 자동 적용 도메인과 클릭한 탭에 대한 `activeTab`·`scripting` 권한만 사용합니다. 입력 내용을 기록하거나 외부로 전송하는 코드가 없습니다.

## 초보자: 맥 ABC 자동 전환 앱

1. 앱 ZIP을 압축 해제하고 `JumpInputGuard.app`을 **응용 프로그램** 폴더로 옮깁니다.
2. 앱을 열고 **자동**을 선택합니다. 한영 전환은 아이패드에서 합니다.
3. 필요하면 **로그인 시 자동 실행**을 선택합니다. macOS 승인이 필요하면 **로그인 항목 설정…**을 엽니다.

| 선택 | 동작 |
|---|---|
| 자동 | Jump Fluid 연결 중 ABC 유지, 마지막 연결이 끝나면 이전 입력기로 복원 |
| 켜기 | 연결 여부에 관계없이 ABC를 유지하는 수동 모드 |
| 끄기 | ABC 고정을 풀고 이전 입력기로 복원. 앱은 계속 실행 |
| 프로그램 종료 | 이전 입력기로 복원하고 앱 프로세스도 종료 |

메뉴 막대 아이콘을 **한 번 클릭**하면 바로 수동 켜기/끄기를 전환합니다. **우클릭**하면 자동 모드와 설정 메뉴를 엽니다. 앱을 다시 열면 기존 설정 창을 보여주며, 중복 인스턴스를 만들지 않습니다.

자동 모드에서 연결이 끝나도 앱 자체는 메뉴 막대에서 대기합니다. 재접속을 감지하려면 실행 중이어야 하기 때문입니다. 완전히 끄려면 설정 창의 **프로그램 종료**를 누르세요. 로그인 자동 실행이 켜져 있으면 다음 로그인 때 다시 실행됩니다.

## 전문가: 근거와 구현

![실제 별도 Whale 프로필에서 구성한 웹 입력 진단 화면](docs/images/whale-web-diagnostic.png)

*개인 대화가 없는 진단 화면입니다. 이벤트 관측 결과는 아래 문서에 별도로 정리했습니다.*

- [재현 조건과 관측 결과](docs/evidence.md)
- [웨일 upstream 이슈 원고](docs/upstream-issue.md)
- 맥 앱: [`macos/`](macos/)
- 확장: [`extension/`](extension/)

맥 앱은 키 이벤트를 수집하지 않습니다. 현재 사용자 소유의 Jump Connect `--desktopproxy` 프로세스로 실제 Fluid 세션을 감지하고, TIS API로 입력기를 전환합니다. 이 감지 신호는 Jump Connect 10.15.42에서 확인한 내부 구현에 의존하며 공식 API가 아닙니다. 향후 버전에서 바뀌면 수동 모드를 사용할 수 있습니다.

마지막 연결 종료 시 복원, 여러 연결, 재접속, 수동 모드, 감지 실패 뒤 복원, 이전 실행 복구를 상태 테스트로 확인합니다. 연결 상태를 읽지 못하면 자동 모드의 고정을 3초 뒤 해제합니다. 앱은 모드·복원할 입력기와 현재 상태 같은 메타데이터만 로컬에 저장합니다.

확장은 신뢰된 한글 `keydown` 중 `code=""`, `keyCode=0`, `isComposing=false`인 경우만 처리합니다. `document.execCommand('insertText', false, event.key)`로 브라우저의 편집 동작을 수행하고 원래 키의 기본 동작을 막습니다. Backspace와 일반 IME 동작은 그대로 둡니다. 일반 HTML 입력칸을 대상으로 하며 캔버스·특수 에디터나 다른 사이트의 입력 처리에는 추가 검증이 필요합니다.

공식 웨일 버그 보고: [naver/whale-browser-developers #24](https://github.com/naver/whale-browser-developers/issues/24)

## 직접 빌드·검사

Xcode Command Line Tools, Swift, Node.js, Python 3이 필요합니다.

```bash
bash scripts/test.sh
bash scripts/build-macos.sh
```

결과는 `dist/JumpInputGuard.app`과 ZIP입니다. GitHub 이슈에는 재현 환경과 보정 전후 결과를 남겨주세요. 개인정보, 실제 대화 내용, 전체 Jump 로그는 올리지 마세요.

## 라이선스

이 저장소에서 작성한 보정 코드에는 [MIT 라이선스](LICENSE)를 적용합니다. NAVER Whale·Jump Desktop 등 외부 제품에는 각 제품의 라이선스가 적용됩니다. 외부 제품의 바이너리는 이 저장소에 포함하지 않습니다.
