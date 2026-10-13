import AppKit
import Carbon
import Foundation
import Darwin
import ServiceManagement

final class NativeSources: InputSourceBackend {
    func currentID() -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "unknown" }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
    func select(_ id: String) -> Bool {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false).takeRetainedValue() as NSArray
        guard sources.count > 0 else { return false }
        return TISSelectInputSource((sources[0] as! TISInputSource)) == noErr
    }
}
func argument(_ name: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: name), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sources = NativeSources()
    private let defaults = UserDefaults.standard
    private lazy var control = RemoteInputController(backend: sources, initialRestoreID: argument("--restore-source") ?? defaults.string(forKey: "pendingRestoreSource"))
    private var status: NSStatusItem!
    private var menu = NSMenu()
    private var timer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var lastObservation: TimeInterval = 0
    private let detailItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var modeItems: [NSMenuItem] = []
    private var lastSerializedState: Data?
    private var settingsWindow: NSWindow?
    private var modeControl: NSSegmentedControl?
    private var windowStatus: NSTextField?
    private var loginButton: NSButton?
    private var appMessage: String?
    private var reopenObserver: NSObjectProtocol?
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reopenObserver = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("local.JumpInputGuard.reopen"), object: nil, queue: .main) { [weak self] _ in self?.showSettings() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self
        status.button?.action = #selector(statusClicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.addItem(NSMenuItem(title: "Jump 입력 보조", action: nil, keyEquivalent: ""))
        menu.addItem(detailItem)
        menu.addItem(.separator())
        for (index, title) in ["자동 · 연결할 때만 ABC", "켜기 · ABC 유지", "끄기 · 원래 입력기로"].enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectMode), keyEquivalent: "")
            item.tag = index; item.target = self; menu.addItem(item); modeItems.append(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "설정과 사용 방법…", action: #selector(showSettings), keyEquivalent: "")
        settings.target = self; menu.addItem(settings)
        let quit = NSMenuItem(title: "종료하고 원래 입력기로", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        let mode = CommandLine.arguments.contains("--start-disabled") ? InputMode.off : InputMode(rawValue: argument("--mode") ?? defaults.string(forKey: "inputMode") ?? "automatic") ?? .automatic
        defaults.set(mode.rawValue, forKey: "inputMode")
        control.select(mode, at: now)
        observeSessions()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.now - self.lastObservation >= 1 { self.observeSessions() }
            self.control.tick(); self.refresh()
        }
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume(); signalSources.append(source)
        }
        refresh()
        if !defaults.bool(forKey: "hasSeenAutomaticMode") || CommandLine.arguments.contains("--show-window") {
            defaults.set(true, forKey: "hasSeenAutomaticMode")
            showSettings()
        }
    }
    private func observeSessions() {
        lastObservation = now
        control.observe(SessionDetector.observe(), at: now)
    }
    private var statusDescription: String {
        if let error = control.pin.error { return error }
        if let appMessage { return appMessage }
        switch control.mode {
        case .on: return "수동 켜짐 · 맥 ABC 유지 중"
        case .off: return "수동 꺼짐 · 맥 입력기를 자유롭게 선택하세요"
        case .automatic:
            guard let count = control.observation.count else { return control.observation.error ?? "자동 감지 확인 중" }
            return count > 0 ? "자동 · Jump 연결 \(count)개 · ABC 유지 중" : "자동 · 연결 대기 · 맥 입력기를 바꾸지 않습니다"
        }
    }
    private func refresh() {
        status.button?.title = control.pin.enabled ? "Jump · ABC" : control.mode == .automatic ? "Jump · 대기" : "Jump · 꺼짐"
        status.button?.toolTip = statusDescription + "\n클릭: 켜기/끄기 · 우클릭: 자동/수동 메뉴"
        detailItem.title = statusDescription
        for (index, item) in modeItems.enumerated() { item.state = index == control.mode.index ? .on : .off }
        modeControl?.selectedSegment = control.mode.index
        windowStatus?.stringValue = statusDescription
        loginButton?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if control.pin.enabled, let original = control.pin.originalID { defaults.set(original, forKey: "pendingRestoreSource") }
        else if control.pin.error == nil { defaults.removeObject(forKey: "pendingRestoreSource") }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("JumpInputGuard")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let path = argument("--state-file") ?? directory.appendingPathComponent("status.json").path
        do {
            let state: [String: Any] = ["mode":control.mode.rawValue,"enabled":control.pin.enabled,"current":control.pin.currentID,"original":control.pin.originalID ?? "","corrections":control.pin.correctionCount,"sessions":control.observation.count ?? -1,"error":control.pin.error ?? control.observation.error ?? "","pid":ProcessInfo.processInfo.processIdentifier]
            if let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]), data != lastSerializedState {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
                lastSerializedState = data
            }
        }
    }
    private func changeMode(_ mode: InputMode) {
        appMessage = nil
        defaults.set(mode.rawValue, forKey: "inputMode")
        control.select(mode, at: now); refresh()
    }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { if let button = status.button { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button) } }
        else { changeMode(control.pin.enabled ? .off : .on) }
    }
    @objc private func selectMode(_ item: NSMenuItem) { changeMode(InputMode.all[item.tag]) }
    @objc private func segmentChanged(_ sender: NSSegmentedControl) { changeMode(InputMode.all[sender.selectedSegment]) }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval { appMessage = "시스템 설정의 로그인 항목에서 허용해주세요." }
            }
        } catch { appMessage = "자동 실행을 설정하지 못했습니다. 앱을 응용 프로그램 폴더에 넣고 다시 시도해주세요." }
        refresh()
    }
    @objc private func loginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); return }
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:510,height:385),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = "Jump 입력 보조"; window.isReleasedWhenClosed = false
        let heading = NSTextField(labelWithString:"원격 연결할 때만 ABC, 끝나면 원래 입력기로")
        heading.font = .boldSystemFont(ofSize:17); heading.frame = NSRect(x:24,y:332,width:462,height:28)
        let explanation = NSTextField(wrappingLabelWithString:"기본은 자동입니다. Jump Fluid 연결을 감지하면 ABC로 바꾸고, 마지막 연결이 끝나면 이전 입력기로 돌아갑니다.\n\n한영 전환은 아이패드에서 하세요. 메뉴 막대 아이콘을 클릭하면 바로 켜거나 끌 수 있고, 우클릭하면 자동 모드로 돌아갈 수 있습니다.")
        explanation.font = .systemFont(ofSize:13); explanation.frame = NSRect(x:24,y:225,width:462,height:99)
        let segment = NSSegmentedControl(labels:["자동","켜기","끄기"],trackingMode:.selectOne,target:self,action:#selector(segmentChanged))
        segment.frame = NSRect(x:24,y:181,width:260,height:30); modeControl = segment
        let message = NSTextField(wrappingLabelWithString:statusDescription)
        message.font = .systemFont(ofSize:12); message.frame = NSRect(x:24,y:139,width:462,height:32); windowStatus = message
        let login = NSButton(checkboxWithTitle:"로그인 시 자동 실행",target:self,action:#selector(toggleLogin))
        login.frame = NSRect(x:24,y:96,width:220,height:24); loginButton = login
        let systemSettings = NSButton(title:"로그인 항목 설정…",target:self,action:#selector(loginSettings))
        systemSettings.bezelStyle = .rounded; systemSettings.frame = NSRect(x:300,y:92,width:180,height:30)
        let quit = NSButton(title:"프로그램 종료",target:self,action:#selector(quitApp))
        quit.bezelStyle = .rounded; quit.frame = NSRect(x:24,y:25,width:145,height:32)
        let quitHint = NSTextField(wrappingLabelWithString:"이전 입력기로 복원하고 앱을 완전히 종료합니다.")
        quitHint.font = .systemFont(ofSize:11); quitHint.frame = NSRect(x:182,y:24,width:298,height:34)
        [heading,explanation,segment,message,login,systemSettings,quit,quitHint].forEach { window.contentView?.addSubview($0) }
        window.center(); window.makeKeyAndOrderFront(nil); settingsWindow = window
        refresh(); NSApp.activate(ignoringOtherApps:true)
    }
    @objc private func quitApp() {
        // Let macOS return focus to the working app before restoring its input
        // source. Restoring while this settings window has focus can be undone
        // by macOS when it subsequently activates the previous app.
        timer?.invalidate()
        settingsWindow?.orderOut(nil)
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.control.stop(); self?.refresh(); NSApp.terminate(nil)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate();control.stop();refresh()
        if let reopenObserver { DistributedNotificationCenter.default().removeObserver(reopenObserver) }
    }
}

@main struct JumpInputGuard {
    static func main() {
        if CommandLine.arguments.contains("--probe") { print(NativeSources().currentID());return }
        if CommandLine.arguments.contains("--probe-session") {
            let s=SessionDetector.observe();print("sessions=\(s.count ?? -1), error=\(s.error ?? "")");return
        }
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("JumpInputGuard")
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let descriptor=open(directory.appendingPathComponent("instance.lock").path,O_CREAT | O_RDWR,0o600)
        guard descriptor >= 0 else { return }
        guard flock(descriptor,LOCK_EX | LOCK_NB) == 0 else {
            DistributedNotificationCenter.default().post(name:Notification.Name("local.JumpInputGuard.reopen"),object:nil)
            close(descriptor);return
        }
        defer { flock(descriptor,LOCK_UN);close(descriptor) }
        let app=NSApplication.shared
        let delegate=AppDelegate();app.delegate=delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
