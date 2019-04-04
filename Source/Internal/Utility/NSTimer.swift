import Foundation

internal extension Timer {

	@nonobjc
    static func scheduledTimerWithTimeInterval(
                    _ timeInterval: TimeInterval,
                    repeats: Bool = false,
                    closure: @escaping Closure) -> Timer {

		return scheduledTimer(timeInterval: timeInterval,
                              target: timerHandler,
                              selector: #selector(TimerHandler.handle(_:)),
                              userInfo: StrongReference(closure),
                              repeats: repeats)
	}
}

private let timerHandler = TimerHandler()

private class TimerHandler: NSObject {

	@objc
	fileprivate func handle(_ timer: Timer) {
        guard let closureReference = timer.userInfo as? StrongReference<Closure> else {
            return
        }
		closureReference.target()
	}
}
