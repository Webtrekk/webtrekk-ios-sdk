public class ActionEvent:
	TrackingEventWithActionProperties,
	TrackingEventWithAdvertisementProperties,
	TrackingEventWithEcommerceProperties,
	TrackingEventWithPageProperties,
	TrackingEventWithSessionDetails,
	TrackingEventWithUserProperties {

	public var actionProperties: ActionProperties
	public var advertisementProperties: AdvertisementProperties
	public var ecommerceProperties: EcommerceProperties
	public var ipAddress: String?
	public var pageProperties: PageProperties
	public var sessionDetails: [Int: TrackingValue]
	public var userProperties: UserProperties
	public var variables: [String : String]

	public init(
		actionProperties: ActionProperties,
		pageProperties: PageProperties,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		self.actionProperties = actionProperties
		self.advertisementProperties = advertisementProperties
		self.ecommerceProperties = ecommerceProperties
		self.pageProperties = pageProperties
		self.sessionDetails = sessionDetails
		self.userProperties = userProperties
		self.variables = variables
	}
}
