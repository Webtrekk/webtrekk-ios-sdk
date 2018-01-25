public struct ActionProperties {

    public var details: [Int: TrackingValue]?
    public var name: String?

    public init(
        name: String?,
        details: [Int: TrackingValue]? = nil) {
        self.details = details
        self.name = name
    }

    internal func merged(over other: ActionProperties) -> ActionProperties {
        return ActionProperties(
            name: name ?? other.name,
            details: details.merged(over: other.details)
        )
    }
}
