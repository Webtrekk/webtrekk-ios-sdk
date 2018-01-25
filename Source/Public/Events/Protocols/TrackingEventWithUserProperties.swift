public protocol TrackingEventWithUserProperties: TrackingEvent {
	var userProperties: UserProperties { get mutating set }
}
