import Foundation

enum InputMode: String {
    case automatic, on, off
    var index: Int { Self.all.firstIndex(of: self)! }
    static let all: [InputMode] = [.automatic, .on, .off]
}

final class RemoteInputController {
    let pin: InputPin
    private(set) var mode: InputMode = .automatic
    private(set) var observation: SessionObservation = .active(0)
    private var unavailableSince: TimeInterval?
    private var initialRestoreID: String?

    init(backend: InputSourceBackend, initialRestoreID: String? = nil) {
        pin = InputPin(backend: backend)
        self.initialRestoreID = backend.currentID() == InputPin.abc ? initialRestoreID : nil
    }
    func select(_ mode: InputMode, at time: TimeInterval) {
        self.mode = mode
        reconcile(at: time)
    }
    func observe(_ observation: SessionObservation, at time: TimeInterval) {
        self.observation = observation
        if observation.count != nil { unavailableSince = nil }
        else if unavailableSince == nil { unavailableSince = time }
        reconcile(at: time)
    }
    private func reconcile(at time: TimeInterval) {
        let shouldEnable: Bool
        switch mode {
        case .on: shouldEnable = true
        case .off: shouldEnable = false
        case .automatic:
            if let count = observation.count { shouldEnable = count > 0 }
            else { shouldEnable = pin.enabled && time - (unavailableSince ?? time) < 3 }
        }
        if shouldEnable {
            if !pin.enabled {
                if pin.enable(restoring: initialRestoreID) { initialRestoreID = nil }
            }
        } else if pin.enabled {
            _ = pin.disable()
        } else if let restore = initialRestoreID {
            // Recover an interrupted run that left ABC selected after its
            // session ended. A successful restore is consumed only once.
            if pin.enable(restoring: restore), pin.disable() { initialRestoreID = nil }
        }
    }
    func tick() { pin.tick() }
    func stop() { _ = pin.disable() }
}
