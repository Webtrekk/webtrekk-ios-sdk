internal extension Dictionary {

	internal func merged(over other: [Key: Value]) -> [Key: Value] {
		var merged = other
		for (key, value) in self {
			merged[key] = value
		}
		return merged
	}

	internal func merged(over other: [Key: Value]?) -> [Key: Value] {
		guard let other = other else {
			return self
		}

		return merged(over: other)
	}
}

internal extension _Optional where Wrapped == [Int: TrackingValue] {

	internal func merged(over other: Wrapped?) -> Wrapped? {
		guard let value = value else {
			return other
		}

		return value.merged(over: other)
	}
}

internal extension _Optional where Wrapped == [Int: String] {

    internal func merged(over other: Wrapped?) -> Wrapped? {
        guard let value = value else {
            return other
        }

        return value.merged(over: other)
    }
}
