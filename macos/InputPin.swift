import Foundation

protocol InputSourceBackend {
    func currentID() -> String
    func select(_ id: String) -> Bool
}

final class InputPin {
    static let abc = "com.apple.keylayout.ABC"
    private let backend: InputSourceBackend
    private(set) var enabled = false
    private(set) var originalID: String?
    private(set) var correctionCount = 0
    private(set) var error: String?

    init(backend: InputSourceBackend) { self.backend = backend }

    @discardableResult
    func enable(restoring originalOverride: String? = nil) -> Bool {
        if enabled { return true }
        originalID = originalOverride ?? backend.currentID()
        error = nil
        enabled = true
        tick()
        return enabled
    }

    func tick() {
        guard enabled, backend.currentID() != Self.abc else { return }
        guard backend.select(Self.abc), backend.currentID() == Self.abc else {
            error = "ABC 입력기로 전환하지 못했습니다."
            enabled = false
            return
        }
        correctionCount += 1
    }

    @discardableResult
    func disable() -> Bool {
        guard enabled else { return true }
        enabled = false
        guard let originalID, originalID != Self.abc else { return true }
        guard backend.select(originalID), backend.currentID() == originalID else {
            error = "원래 입력기로 돌아가지 못했습니다. 메뉴에서 직접 선택해주세요."
            return false
        }
        error = nil
        return true
    }

    var currentID: String { backend.currentID() }
}
