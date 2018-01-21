public protocol TrackingEventWithAdvertisementProperties: TrackingEvent {
	var advertisementProperties: AdvertisementProperties { get mutating set }
}
