(() => {
  if (globalThis.__jumpHangulWhale) return;
  const state = globalThis.__jumpHangulWhale = { enabled: true, inserted: 0, failed: 0 };
  const hangul = /^[\u1100-\u11ff\u3130-\u318f\ua960-\ua97f\uac00-\ud7a3\ud7b0-\ud7ff]+$/u;

  function editableTarget(target) {
    if (!(target instanceof HTMLElement)) return null;
    if (target instanceof HTMLTextAreaElement) {
      return !target.disabled && !target.readOnly && document.activeElement === target ? target : null;
    }
    if (target instanceof HTMLInputElement) {
      return ['text', 'search'].includes(target.type) && !target.disabled && !target.readOnly &&
        document.activeElement === target ? target : null;
    }
    const root = target.closest('[contenteditable="true"], [contenteditable="plaintext-only"]');
    return root?.isContentEditable && root.getAttribute('aria-disabled') !== 'true' &&
      (document.activeElement === root || root.contains(document.activeElement)) ? root : null;
  }

  window.addEventListener('keydown', event => {
    if (!state.enabled || !event.isTrusted || event.isComposing ||
        event.ctrlKey || event.metaKey || event.altKey || event.defaultPrevented ||
        event.code !== '' || event.keyCode !== 0 || !hangul.test(event.key) ||
        !editableTarget(event.target)) return;
    // The observed native Unicode key reaches keydown but does not create an
    // insertion event. Make one browser edit and suppress that key's default
    // action. Backspace, selection, undo, and ordinary IME keys remain native.
    if (document.execCommand('insertText', false, event.key)) {
      event.preventDefault();
      state.inserted += 1;
    } else {
      state.failed += 1;
    }
  }, true);

  chrome.runtime.onMessage.addListener((message, _sender, reply) => {
    if (!['jump-hangul-toggle', 'jump-hangul-status'].includes(message?.type)) return;
    if (message.type === 'jump-hangul-toggle') state.enabled = !state.enabled;
    reply({ enabled: state.enabled, inserted: state.inserted, failed: state.failed });
  });
})();
