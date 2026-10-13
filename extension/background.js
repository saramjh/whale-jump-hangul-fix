chrome.action.onClicked.addListener(async tab => {
  if (tab.id == null) return;
  try {
    let state;
    try {
      state = await chrome.tabs.sendMessage(tab.id, { type: 'jump-hangul-toggle' });
    } catch {
      await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['fix.js'] });
      state = await chrome.tabs.sendMessage(tab.id, { type: 'jump-hangul-status' });
    }
    await chrome.action.setBadgeText({ tabId: tab.id, text: state.enabled ? 'ON' : 'OFF' });
    await chrome.action.setBadgeBackgroundColor({ tabId: tab.id, color: state.enabled ? '#2464d5' : '#777777' });
    await chrome.action.setTitle({ tabId: tab.id, title: state.enabled ? 'Jump 한글 보정 켜짐 — 클릭해서 끄기' : 'Jump 한글 보정 꺼짐 — 클릭해서 켜기' });
  } catch {
    await chrome.action.setBadgeText({ tabId: tab.id, text: '' });
    await chrome.action.setTitle({ tabId: tab.id, title: '이 페이지에는 보정을 적용하지 못했습니다. 일반 웹페이지에서 사용해주세요.' });
  }
});

chrome.tabs.onUpdated.addListener((tabId, change) => {
  if (change.status === 'loading') {
    chrome.action.setBadgeText({ tabId, text: '' });
    chrome.action.setTitle({ tabId, title: '이 페이지의 Jump 한글 보정 켜기 / 끄기' });
  }
});
