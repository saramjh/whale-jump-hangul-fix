import Foundation
import Darwin

final class SessionBackend: InputSourceBackend {
    var current = "korean"
    var fail = false
    func currentID() -> String { current }
    func select(_ id: String) -> Bool { if fail { return false }; current = id; return true }
}

@main struct SessionTests {
    static func main() {
        let path = "/Applications/Jump Desktop Connect.app/Contents/MacOS/JumpConnect"
        let idle = SessionProcess(uid: 501, path: path, arguments: [path])
        let service = SessionProcess(uid: 0, path: path, arguments: [path, "--service"])
        let session = SessionProcess(uid: 501, path: path, arguments: [path, "--desktopproxy", "socket"])
        precondition(SessionDetector.classify([idle, service], uid: 501).count == 0)
        precondition(SessionDetector.classify([idle, service, session, session], uid: 501).count == 2)
        precondition(SessionDetector.classify([session], uid: 502).count == 0)
        precondition(SessionDetector.classify([.init(uid:501,path:"/tmp/JumpConnect",arguments:["--desktopproxy"])],uid:501).count == 0)
        precondition(SessionDetector.classify([.init(uid:501,path:path,arguments:nil)],uid:501).count == nil)
        let backend = SessionBackend(); let control = RemoteInputController(backend: backend)
        control.observe(.active(0), at: 0); precondition(!control.pin.enabled && backend.current == "korean")
        control.observe(.active(1), at: 1); precondition(control.pin.enabled && backend.current == InputPin.abc)
        control.observe(.active(2), at: 2); precondition(control.pin.originalID == "korean")
        control.observe(.active(1), at: 3); precondition(control.pin.enabled)
        control.observe(.active(0), at: 4); precondition(!control.pin.enabled && backend.current == "korean")
        backend.current = "japanese"; control.observe(.active(1), at: 5)
        precondition(control.pin.originalID == "japanese")
        control.select(.off, at: 6); precondition(backend.current == "japanese")
        control.observe(.active(3), at: 7); precondition(!control.pin.enabled)
        control.select(.automatic, at: 8); precondition(control.pin.enabled)
        control.observe(.unavailable, at: 9); precondition(control.pin.enabled)
        control.observe(.unavailable, at: 12); precondition(!control.pin.enabled && backend.current == "japanese")
        control.select(.on, at: 13); precondition(control.pin.enabled)
        control.observe(.active(0), at: 14); precondition(control.pin.enabled)
        control.stop(); precondition(backend.current == "japanese")
        let migration = SessionBackend(); migration.current = InputPin.abc
        let migrated = RemoteInputController(backend:migration,initialRestoreID:"saved-korean")
        migrated.observe(.active(1),at:0); migrated.observe(.active(0),at:1)
        precondition(migration.current == "saved-korean")
        let interrupted = SessionBackend(); interrupted.current = InputPin.abc
        let recovered = RemoteInputController(backend:interrupted,initialRestoreID:"saved-korean")
        recovered.observe(.active(0),at:0);precondition(interrupted.current == "saved-korean")
        let failed = SessionBackend(); failed.fail = true
        let failedControl = RemoteInputController(backend:failed)
        failedControl.observe(.active(1),at:0);precondition(!failedControl.pin.enabled && failedControl.pin.error != nil)
        print("PASS: idle service exclusion, multiple sessions, UID/path boundaries, unknown detection, automatic connect/disconnect/reconnect, manual modes, failed detection release, migration restore, selection failure")
    }
}
