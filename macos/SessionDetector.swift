import Foundation
import Darwin

struct SessionObservation {
    let count: Int?
    let error: String?
    static func active(_ count: Int) -> Self { .init(count: count, error: nil) }
    static var unavailable: Self { .init(count: nil, error: "Jump 연결 상태를 확인하지 못했습니다.") }
}

struct SessionProcess {
    let uid: uid_t
    let path: String
    let arguments: [String]?
}

enum SessionDetector {
    static func classify(_ processes: [SessionProcess], uid: uid_t) -> SessionObservation {
        var count = 0
        for process in processes where process.uid == uid &&
            process.path.hasSuffix("/Jump Desktop Connect.app/Contents/MacOS/JumpConnect") {
            guard let arguments = process.arguments else { return .unavailable }
            if arguments.contains("--desktopproxy") { count += 1 }
        }
        return .active(count)
    }

    private static func arguments(_ pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 4 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &bytes, &size, nil, 0) == 0, size > 4 else { return nil }
        let argc = bytes.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        guard argc > 0, argc < 4096 else { return nil }
        var index = 4
        while index < size && bytes[index] != 0 { index += 1 }
        while index < size && bytes[index] == 0 { index += 1 }
        var result: [String] = []
        for _ in 0..<argc {
            guard index < size else { return nil }
            let start = index
            while index < size && bytes[index] != 0 { index += 1 }
            result.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        return result
    }

    static func observe() -> SessionObservation {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return .unavailable }
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 128)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0, count <= pids.count else { return .unavailable }
        var processes: [SessionProcess] = []
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var info = proc_bsdinfo()
            let size = MemoryLayout<proc_bsdinfo>.size
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size,
                  info.pbi_uid == geteuid() else { continue }
            var pathBytes = [CChar](repeating: 0, count: 4096)
            guard proc_pidpath(pid, &pathBytes, UInt32(pathBytes.count)) > 0 else { continue }
            let path = String(cString: pathBytes)
            guard path.hasSuffix("/Jump Desktop Connect.app/Contents/MacOS/JumpConnect") else { continue }
            processes.append(.init(uid: info.pbi_uid, path: path, arguments: arguments(pid)))
        }
        return classify(processes, uid: geteuid())
    }
}
