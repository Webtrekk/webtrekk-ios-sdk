public class PageViewEvent:
	TrackingEventWithAdvertisementProperties,
	TrackingEventWithEcommerceProperties,
	TrackingEventWithPageProperties,
	TrackingEventWithSessionDetails,
	TrackingEventWithUserProperties
{

	public var advertisementProperties: AdvertisementProperties
	public var ecommerceProperties: EcommerceProperties
	public var ipAddress: String?
	public var pageProperties: PageProperties
	public var sessionDetails: [Int: TrackingValue]
	public var userProperties: UserProperties
	public var variables: [String : String]

	public init(
		pageProperties: PageProperties,
		advertisementProperties: AdvertisementProperties = AdvertisementProperties(id: nil),
		ecommerceProperties: EcommerceProperties = EcommerceProperties(),
		ipAddress: String? = nil,
		sessionDetails: [Int: TrackingValue] = [:],
		userProperties: UserProperties = UserProperties(birthday: nil),
		variables: [String : String] = [:]
	) {
		self.advertisementProperties = advertisementProperties
		self.ecommerceProperties = ecommerceProperties
		self.ipAddress = ipAddress
		self.pageProperties = pageProperties
		self.sessionDetails = sessionDetails
		self.userProperties = userProperties
		self.variables = variables
	}
}
