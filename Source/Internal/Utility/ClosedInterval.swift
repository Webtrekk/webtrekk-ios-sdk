internal extension ClosedRange {

    func clamp(_ value: Bound) -> Bound {
		if value < lowerBound {
			return lowerBound
		}
		if value > upperBound {
			return upperBound
		}

		return value
	}
}

internal extension ClosedRange where Bound: MinimumMaximumAware {

    var conditionText: String {
		if lowerBound.isMinimum && upperBound.isMaximum {
			return "any value"
		}
		if upperBound.isMaximum {
			return ">= \(lowerBound)"
		}
		if lowerBound.isMinimum {
			return "<= \(upperBound)"
		}

		return ">= \(lowerBound) and <= \(upperBound)"
	}
}

internal protocol MinimumMaximumAware {

	var isMaximum: Bool { get }
	var isMinimum: Bool { get }
}

extension Float: MinimumMaximumAware {

	internal var isMaximum: Bool {
		return sign == .plus && isInfinite
	}

	internal var isMinimum: Bool {
		return sign == .minus && isInfinite
	}
}

extension Double: MinimumMaximumAware {

	internal var isMaximum: Bool {
		return sign == .plus && isInfinite
	}

	internal var isMinimum: Bool {
		return sign == .minus && isInfinite
	}
}

extension Int: MinimumMaximumAware {

	internal var isMaximum: Bool {
		return self == .max
	}

	internal var isMinimum: Bool {
		return self == .min
	}
}
