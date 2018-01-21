public enum TrackingValue {

	case constant(String)
	case customVariable(name: String)
	case defaultVariable(DefaultVariable)

	public enum DefaultVariable {
		case advertisingId
		case advertisingTrackingEnabled
		case appVersion
		case connectionType
		case interfaceOrientation
		case isFirstEventAfterAppUpdate
		case requestQueueSize
        case adClearId
	}
}

extension TrackingValue: ExpressibleByStringLiteral {

	public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
		self = .constant(value)
	}

	public init(stringLiteral value: StringLiteralType) {
		self = .constant(value)
	}

	public init(unicodeScalarLiteral value: StringLiteralType) {
		self = .constant(value)
	}
}
