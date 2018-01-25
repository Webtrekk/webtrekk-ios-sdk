public protocol TrackingEventWithEcommerceProperties: TrackingEvent {
	var ecommerceProperties: EcommerceProperties { get mutating set }
}
