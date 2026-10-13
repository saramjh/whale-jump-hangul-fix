## Summary

Korean text does not get inserted into editable web fields in Whale on macOS when typing from an iPad Magic Keyboard through Jump Desktop Fluid. The trusted Korean keydown reaches the page, but the corresponding text insertion is missing. Backspace edits still run, so replacement-based Korean typing can delete existing text.

### Environment

- iPad Pro 12.9-inch (3rd generation), Magic Keyboard
- iPad Jump Desktop 10.15.42; iPadOS version not collected
- Fluid connection to Mac Jump Desktop Connect 10.15.42.0
- macOS 26.6.2 (25G83)
- Whale 5.39.412.57, Chromium 150
- Mac input source held at ABC; Korean composed on the iPad

### Steps to reproduce

1. Connect from the iPad to the Mac using Jump Desktop Fluid.
2. Keep the Mac input source at ABC and select Korean on the iPad.
3. In Whale, focus the ChatGPT web composer and type `안녕하세요 테스트 때 때가 됐다 `.
4. Compare with the address bar. Repeat in a plain HTML contenteditable field.

### Expected

Korean syllables, double consonants and committed text remain in the web editor.

### Actual and observed events

- The address bar accepts Korean, but the web editor fails to insert Korean or loses text during replacement.
- The failure also reproduces in a clean Whale profile without existing extensions and in plain contenteditable, so it is not confined to ChatGPT application code.
- The tested logged-out ChatGPT composer was `textarea#mobile-composer-prompt`.
- Korean keydown arrives with `isTrusted=true`, `code=""`, `keyCode=0`, `isComposing=false`.
- No corresponding Hangul `beforeinput` / `input` insertion was observed, while Backspace produces `deleteContentBackward`.
- Native events contain Unicode-bearing keycode 108 and replacement Backspace events. Native keycode 108 and DOM keyCode 0 are different values at different layers.

The reporter says the workflow works outside Whale and previously worked with Parsec. We have not collected a controlled side-by-side Chrome/Safari trace; this is not a claim that all Korean input in Whale is broken.

### Workaround and investigation boundary

For trusted, non-composing Hangul keydown with empty code and keyCode 0, inserting `event.key` through `document.execCommand('insertText', false, event.key)` and preventing that key's default action restores typing in the tested fields. Backspace is left unchanged. The local test recorded 56 successful insert commands and no failed commands; the reporter confirmed normal typing in ChatGPT and Wrtn afterward. This is a bounded workaround result, not a general success-rate claim.

The inspected Jump receiver queries the host input source and may post CGEvent Unicode keyboard events when reverse mapping has no suitable key. Apple documents that frameworks can ignore the Unicode string and translate from virtual keycode themselves. We have not identified the exact internal Whale code path dropping insertion.

Could you investigate how Whale's macOS text-input path handles Unicode-bearing synthetic keys with no DOM code/keyCode mapping in textarea and contenteditable?

Public workaround source and redacted evidence: https://github.com/saramjh/whale-jump-hangul-fix

### 한국어 요약

아이패드 Jump Fluid → 맥 웨일 환경에서 주소창 한글은 입력되지만 웹 입력칸의 한글 문자 삽입이 누락됩니다. 실제 keydown은 도착하고 Backspace 삭제만 처리됩니다. ABC 고정만으로 해결되지 않으며, 해당 이벤트에 브라우저 insertText 편집 명령을 적용하면 ChatGPT·뤼튼에서 정상 입력을 확인했습니다. 정확한 웨일 내부 원인은 아직 확정하지 않았습니다.
