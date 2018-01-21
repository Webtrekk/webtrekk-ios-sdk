public protocol TrackingEventWithSessionDetails: TrackingEvent {
	var sessionDetails: [Int: TrackingValue] { get mutating set }
}
