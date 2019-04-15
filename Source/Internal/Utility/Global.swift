import Foundation

internal typealias Closure = () -> Void

internal func checkIsOnMainThread(function: StaticString = #function, file: StaticString = #file, line: UInt = #line) {
	guard !Thread.isMainThread else {
		return
	}

	var file = String(describing: file)
	if let range = file.range(of: "/", options: .backwards, range: nil, locale: nil) {
        file = String(file[file.index(range.lowerBound, offsetBy: 1) ..< file.endIndex])
	}

	logError("[\(file):\(line)] \(function) must be called on the main thread!")
}

internal func logDebug(_ message: @autoclosure () -> String) {
	WebtrekkTracking.logger.logDebug(message())
}

internal func logError(_ message: @autoclosure () -> String) {
	WebtrekkTracking.logger.logError(message())
}

internal func logInfo(_ message: @autoclosure () -> String) {
	WebtrekkTracking.logger.logInfo(message())
}

internal func logWarning(_ message: @autoclosure () -> String) {
	WebtrekkTracking.logger.logWarning(message())
}

internal func onMainQueue(synchronousIfPossible: Bool = false, closure: @escaping Closure) {
	guard !synchronousIfPossible || !Thread.isMainThread else {
		closure()
		return
	}

	DispatchQueue.main.async(execute: closure)
}
