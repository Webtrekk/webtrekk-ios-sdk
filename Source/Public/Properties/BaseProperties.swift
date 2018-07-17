import Foundation

public class BaseProperties {

    public var actionProperties: ActionProperties
    public var advertisementProperties: AdvertisementProperties
    public var ecommerceProperties: EcommerceProperties
    public var ipAddress: String?
    public var mediaProperties: MediaProperties
    public var pageProperties: PageProperties
    public var sessionDetails: [Int: TrackingValue]
    public var userProperties: UserProperties
    var trackingParameters: TrackingParameter?

    public init(
        actionProperties: ActionProperties = ActionProperties(),
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        ipAddress: String? = nil,
        mediaProperties: MediaProperties = MediaProperties(),
        pageProperties: PageProperties = PageProperties(),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties()
        ) {
        self.actionProperties = actionProperties
        self.advertisementProperties = advertisementProperties
        self.ecommerceProperties = ecommerceProperties
        self.ipAddress = ipAddress
        self.mediaProperties = mediaProperties
        self.pageProperties = pageProperties
        self.sessionDetails = sessionDetails
        self.userProperties = userProperties
    }
}
