internal extension Dictionary {

	func merged(over other: [Key: Value]) -> [Key: Value] {
		var merged = other
		for (key, value) in self {
			merged[key] = value
		}
		return merged
	}

	func merged(over other: [Key: Value]?) -> [Key: Value] {
		guard let other = other else {
			return self
		}

		return merged(over: other)
	}
}

internal extension _Optional where Wrapped == [Int: TrackingValue] {

	func merged(over other: Wrapped?) -> Wrapped? {
		guard let value = value else {
			return other
		}

		return value.merged(over: other)
	}
}

internal extension _Optional where Wrapped == [Int: String] {

    func merged(over other: Wrapped?) -> Wrapped? {
        guard let value = value else {
            return other
        }

        return value.merged(over: other)
    }
}
