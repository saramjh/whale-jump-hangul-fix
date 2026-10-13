import Foundation
final class FakeBackend: InputSourceBackend {
    var value = "korean"
    var fail = false
    var calls: [String] = []
    func currentID() -> String { value }
    func select(_ id: String) -> Bool {
        calls.append(id)
        if fail { return false }
        value = id
        return true
    }
}
@main struct PinTests {
    static func main() {
        let b = FakeBackend(); let p = InputPin(backend: b)
        precondition(p.enable() && b.value == InputPin.abc)
        precondition(p.originalID == "korean")
        p.tick(); precondition(b.calls.count == 1)
        b.value = "japanese"; p.tick()
        precondition(b.value == InputPin.abc && p.correctionCount == 2)
        precondition(p.enable() && p.originalID == "korean")
        precondition(p.disable() && b.value == "korean")
        precondition(!p.enabled)
        b.fail = true
        precondition(!p.enable() && !p.enabled && p.error != nil)
        let overrideBackend = FakeBackend(); overrideBackend.value = InputPin.abc
        let overridePin = InputPin(backend: overrideBackend)
        precondition(overridePin.enable(restoring: "original-korean"))
        precondition(overridePin.disable() && overrideBackend.value == "original-korean")
        print("PASS: enable, unchanged source, correction, repeated enable, restore, selection failure, saved original restore")
    }
}
