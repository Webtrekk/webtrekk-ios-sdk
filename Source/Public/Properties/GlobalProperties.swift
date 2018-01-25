public class GlobalProperties: BaseProperties {

    public var crossDeviceProperties: CrossDeviceProperties
    public var variables: [String: String]

    public init(
        actionProperties: ActionProperties = ActionProperties(name: nil),
        advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
        crossDeviceProperties: CrossDeviceProperties = CrossDeviceProperties(),
        ecommerceProperties: EcommerceProperties = EcommerceProperties(),
        ipAddress: String? = nil,
        mediaProperties: MediaProperties = MediaProperties(name: nil),
        pageProperties: PageProperties = PageProperties(name: nil),
        sessionDetails: [Int: TrackingValue] = [:],
        userProperties: UserProperties = UserProperties(birthday: nil),
        variables: [String: String] = [:]
    ) {
        self.crossDeviceProperties = crossDeviceProperties
        self.variables = variables
        super.init(actionProperties: actionProperties, advertisementProperties: advertisementProperties,
                   ecommerceProperties: ecommerceProperties, ipAddress: ipAddress,
                   mediaProperties: mediaProperties, pageProperties: pageProperties,
                   sessionDetails: sessionDetails, userProperties: userProperties)
    }

    internal func merged(over other: GlobalProperties) -> GlobalProperties {
        let global = GlobalProperties(
            actionProperties: actionProperties.merged(over: other.actionProperties),
            advertisementProperties: advertisementProperties.merged(over: other.advertisementProperties),
            crossDeviceProperties: crossDeviceProperties.merged(over: other.crossDeviceProperties),
            ecommerceProperties: ecommerceProperties.merged(over: other.ecommerceProperties),
            ipAddress: ipAddress ?? other.ipAddress,
            mediaProperties: mediaProperties.merged(over: other.mediaProperties),
            pageProperties: pageProperties.merged(over: other.pageProperties),
            sessionDetails: sessionDetails.merged(over: other.sessionDetails),
            userProperties: userProperties.merged(over: other.userProperties),
            variables: variables.merged(over: other.variables)
        )

        global.trackingParameters = self.trackingParameters ?? other.trackingParameters
        return global
    }
}
