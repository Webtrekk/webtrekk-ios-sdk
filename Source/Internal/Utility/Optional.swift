internal protocol _Optional: ExpressibleByNilLiteral {

	associatedtype Wrapped

	init(_ some: Wrapped)

	func map<U>(_ transform: (Wrapped) throws -> U) rethrows -> U?
	func flatMap<U>(_ transform: (Wrapped) throws -> U?) rethrows -> U?
}

extension Optional: _Optional {}

internal extension _Optional {

    var simpleDescription: String {
		return map { String(describing: $0) } ?? "<nil>"
	}

    var value: Wrapped? {
		return map { $0 }
	}
}
