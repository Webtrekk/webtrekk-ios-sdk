public struct AdvertisementProperties {

    public var action: String?
    public var details: [Int: TrackingValue]?
    public var id: String?

    public init(
        id: String? = nil,
        action: String? = nil,
        details: [Int: TrackingValue]? = nil
    ) {
        self.action = action
        self.details = details
        self.id = id
    }

    internal func merged(over other: AdvertisementProperties) -> AdvertisementProperties {
        return AdvertisementProperties(
            id: id ?? other.id,
            action: action ?? other.action,
            details: details.merged(over: other.details)
        )
    }
}
